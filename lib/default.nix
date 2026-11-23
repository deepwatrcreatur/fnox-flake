{ lib
, pkgs
,
}:
let
  normalizedSecret =
    name: value:
    {
      description = value.description or name;
      provider = value.provider or "age";
    };

  defaultSecretDefinitions = lib.mapAttrs normalizedSecret {
    ANTHROPIC_API_KEY.description = "Anthropic API key";
    ATTIC_CLIENT_JWT_TOKEN.description = "Attic client JWT token";
    BW_SESSION.description = "Bitwarden session key";
    GEMINI_API_KEY.description = "Google Gemini API key";
    GITHUB_TOKEN.description = "GitHub personal access token";
    GROK_API_KEY.description = "XAI Grok API key";
    OPENROUTER_API_KEY.description = "OpenRouter API key";
    OPENCODE_ZEN_API_KEY.description = "OpenCode Zen API key";
    PROXMOX_API_TOKEN.description = "Proxmox API token";
    Z_AI_API_KEY.description = "Z.AI API key";
  };
in
rec {
  inherit defaultSecretDefinitions;

  mkSecretSpec =
    { envVar
    , fnoxPath ? envVar
    ,
    }:
    {
      inherit envVar fnoxPath;
    };

  mkWrappedCommand =
    { name
    , command
    , fnoxPackage
    , binaryName ? name
    , secrets ? [ ]
    , extraWrapperScript ? ""
    ,
    }:
    pkgs.writeShellScriptBin name ''
      set -euo pipefail

      FNOX_BIN="${fnoxPackage}/bin/fnox"
      FNOX_CONFIG_PATH="''${FNOX_CONFIG:-$HOME/.config/fnox/config.toml}"
      export FNOX_AGE_KEY_FILE="''${FNOX_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

      # Guarantee temp-file cleanup on any exit (normal, error, or signal).
      # Namespaced to avoid colliding with extraWrapperScript variables.
      _fnox_err_file=""
      _fnox_cleanup() { rm -f "$_fnox_err_file"; }
      trap _fnox_cleanup EXIT

      ${lib.concatMapStringsSep "\n" (
        secret: ''
          value=""
          _fnox_err_file="$(mktemp)"
          # GOTCHA: without --if-missing error, fnox get exits 0 with an empty
          # value for a missing secret and the command would run without it.
          if ! value=$("$FNOX_BIN" -c "$FNOX_CONFIG_PATH" --if-missing error get "${secret.fnoxPath}" 2>"$_fnox_err_file"); then
            echo "Error: failed to decrypt '${secret.fnoxPath}' for ${secret.envVar}" >&2
            cat "$_fnox_err_file" >&2
            exit 1
          fi
          rm -f "$_fnox_err_file"; _fnox_err_file=""
          export ${secret.envVar}="$value"
        ''
      ) secrets}

      ${extraWrapperScript}

      exec ${command}/bin/${binaryName} "$@"
    '';

  mkFnoxConfigToml =
    { recipients ? [ ]
    , secrets ? defaultSecretDefinitions
    , extraProviders ? { }
    , extraConfig ? { }
    ,
    }:
    builtins.readFile (
      (pkgs.formats.toml { }).generate "fnox-config.toml" (
        {
          providers = {
            age = {
              type = "age";
              inherit recipients;
            };
          }
          // extraProviders;

          secrets = lib.mapAttrs
            (
              _: value:
                {
                  description = value.description;
                  # GOTCHA: not `default`: in fnox that is the fallback VALUE, so an
                  # unseeded secret resolved to the provider name ("age") and
                  # seeding skipped it as already present.
                  provider = value.provider;
                }
            )
            (lib.mapAttrs normalizedSecret secrets);
        }
        // extraConfig
      )
    );

  /**
    Script that merges a generated fnox config into the live, writable config.

    Providers and secret declarations come from `template`; stored secret
    values and extra user entries in the existing file are kept. A legacy
    `default = "<provider>"` (an old rendering bug: fnox reads `default` as
    the fallback value) is dropped. The target is written 0600 and replaces a
    store symlink, so `fnox set` can update it.

    # Arguments

    - `template`: path to the generated config (from `mkFnoxConfigToml`).
  */
  mkFnoxConfigMergeScript =
    { template }:
    pkgs.writers.writePython3 "fnox-config-merge"
      {
        libraries = [ pkgs.python3Packages.tomli-w ];
        flakeIgnore = [ "E501" ];
      }
      ''
        import os
        import sys
        import tempfile
        import tomllib

        import tomli_w

        target = sys.argv[1]
        with open("${template}", "rb") as f:
            tmpl = tomllib.load(f)
        existing = {}
        if os.path.exists(target):
            with open(target, "rb") as f:
                existing = tomllib.load(f)

        merged = dict(existing)
        providers = dict(existing.get("providers", {}))
        providers.update(tmpl.get("providers", {}))
        merged["providers"] = providers

        secrets = dict(existing.get("secrets", {}))
        for name, decl in tmpl.get("secrets", {}).items():
            entry = dict(secrets.get(name, {}))
            provider = entry.get("provider", decl.get("provider"))
            if entry.get("default") in (decl.get("provider"), provider):
                del entry["default"]
            entry["provider"] = provider
            if "description" in decl:
                entry["description"] = decl["description"]
            secrets[name] = entry
        merged["secrets"] = secrets

        directory = os.path.dirname(target) or "."
        os.makedirs(directory, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=directory)
        with os.fdopen(fd, "wb") as f:
            tomli_w.dump(merged, f)
        os.chmod(tmp, 0o600)
        os.replace(tmp, target)
      '';

  mkSeedSecretsScript =
    { fnoxPackage
    , secretSources
    ,
    }:
    let
      renderSources =
        name: sources:
        ''
          for source in ${lib.concatMapStringsSep " " (source: "\"${source}\"") sources}; do
            if [ -f "$source" ]; then
              if seed_secret ${lib.escapeShellArg name} "$source"; then
                break
              else
                status=$?
                if [ "$status" -eq 1 ]; then
                  exit 1
                fi
              fi
            fi
          done
        '';
    in
    ''
      FNOX_BIN="${fnoxPackage}/bin/fnox"
      export FNOX_AGE_KEY_FILE="''${FNOX_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
      export FNOX_CONFIG="''${FNOX_CONFIG:-$HOME/.config/fnox/config.toml}"

      if [ ! -x "$FNOX_BIN" ]; then
        echo "Warning: fnox binary not found at $FNOX_BIN; skipping fnox secret seeding" >&2
        exit 0
      fi

      seed_secret() {
        name="$1"
        file="$2"

        if [ -z "$file" ] || [ ! -f "$file" ]; then
          return 2
        fi

        if [ ! -r "$file" ]; then
          echo "Warning: fnox seed source '$file' for '$name' is not readable; trying next source" >&2
          return 2
        fi

        value="$(cat "$file" 2>/dev/null || true)"
        if [ -z "$value" ]; then
          return 2
        fi

        # Reject multiline content — real tokens are always single-line.
        # A file with multiple lines almost certainly contains an error message
        # (e.g. a failed SOPS decrypt) rather than a usable secret.
        # $(cat) strips trailing newlines, so a single-line file yields
        # exactly 1 line when passed through printf+wc.
        if [ "$(printf '%s\n' "$value" | wc -l)" -gt 1 ]; then
          echo "Warning: fnox seed source '$file' for '$name' contains multiple lines; skipping (may contain an error message rather than a secret)" >&2
          return 2
        fi

        # WHY: an existing stored value wins (docs/security.md). Look at the
        # store alone: unset the env var (fnox falls back to it) and fail on a
        # missing secret. A missing or undecryptable value, or the legacy
        # placeholder "age" left by configs that rendered `default = <provider>`,
        # counts as not seeded.
        stored=""
        if stored="$(env -u "$name" "$FNOX_BIN" -c "$FNOX_CONFIG" --if-missing error get "$name" 2>/dev/null)" \
          && [ -n "$stored" ] && [ "$stored" != "age" ]; then
          return 0
        fi

        set_output=""
        # SECURITY: pass the value on stdin, not argv, so it never appears in ps.
        if ! set_output=$(printf '%s' "$value" | "$FNOX_BIN" -c "$FNOX_CONFIG" set "$name" 2>&1); then
          echo "Error: failed to seed fnox secret '$name' from '$file'" >&2
          echo "$set_output" >&2
          return 1
        fi
      }

      ${lib.concatStringsSep "\n" (lib.mapAttrsToList renderSources secretSources)}
    '';

  defaultWrappedCommandSpecs =
    { pkgs
    ,
    }:
    (lib.optionalAttrs (pkgs ? opencode) {
      opencode-zai = {
        command = pkgs.opencode;
        binaryName = "opencode";
        secrets = [
          (mkSecretSpec {
            envVar = "OPENAI_API_KEY";
            fnoxPath = "Z_AI_API_KEY";
          })
        ];
        extraWrapperScript = ''
          export OPENCODE_PROVIDER="z.ai"
          export OPENCODE_MODEL="GLM 4.7"
        '';
      };
    })
    // (lib.optionalAttrs (pkgs ? gh) {
      gh-fnox = {
        command = pkgs.gh;
        binaryName = "gh";
        secrets = [
          (mkSecretSpec {
            envVar = "GITHUB_TOKEN";
          })
          (mkSecretSpec {
            envVar = "GH_TOKEN";
            fnoxPath = "GITHUB_TOKEN";
          })
        ];
      };
    })
    // (lib.optionalAttrs (pkgs ? bitwarden-cli) {
      bw-fnox = {
        command = pkgs.bitwarden-cli;
        binaryName = "bw";
        secrets = [
          (mkSecretSpec {
            envVar = "BW_SESSION";
          })
        ];
      };
    })
    // (lib.optionalAttrs ((pkgs ? claude-code) && (pkgs.config.allowUnfree or false)) {
      # Wraps the Anthropic Claude Code CLI with ANTHROPIC_API_KEY injected
      # from fnox when unfree packages are allowed. The binary name inside the
      # package is `claude`.
      claude-fnox = {
        command = pkgs.claude-code;
        binaryName = "claude";
        secrets = [
          (mkSecretSpec {
            envVar = "ANTHROPIC_API_KEY";
          })
        ];
      };
    })
    // (lib.optionalAttrs (pkgs ? gemini-cli) {
      # Wraps the Google Gemini CLI with GEMINI_API_KEY injected from fnox.
      gemini-fnox = {
        command = pkgs.gemini-cli;
        binaryName = "gemini";
        secrets = [
          (mkSecretSpec {
            envVar = "GEMINI_API_KEY";
          })
        ];
      };
    });
}
