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
    DEEPSEEK_API_KEY.description = "DeepSeek API key";
    GEMINI_API_KEY.description = "Google Gemini API key";
    GITHUB_TOKEN.description = "GitHub personal access token";
    GROK_API_KEY.description = "XAI Grok API key";
    OPENAI_API_KEY.description = "OpenAI API key";
    OPENROUTER_API_KEY.description = "OpenRouter API key";
    OPENCODE_ZEN_API_KEY.description = "OpenCode Zen API key";
    PROXMOX_API_TOKEN.description = "Proxmox API token";
    Z_AI_API_KEY.description = "Z.AI API key";
  };

  # Lowercase, without an explicit default HTTPS port: how git matches hosts.
  normalizeGitHost = h: lib.removeSuffix ":443" (lib.toLower h);
in
rec {
  inherit defaultSecretDefinitions normalizeGitHost;

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

  /**
    A git credential helper (`git-credential-fnox`) that answers HTTPS
    `get` requests for the given hosts with a token from fnox.

    It never reads token files. When fnox cannot provide the secret it
    prints nothing, so git moves on to the next helper. `store` and
    `erase` are ignored: fnox stays the only place the token is kept.

    Use it with `git -c credential.helper= -c credential.helper=fnox push`
    (the empty value drops helpers such as `store` that would otherwise also
    receive the token), or set it in the git
    config (the Home Manager option `programs.fnox.gitCredentialHelper`).

    # Arguments

    - `fnoxPackage`: the fnox package.
    - `secret`: fnox secret holding the token (default `GITHUB_TOKEN`).
    - `username`: user name sent with the token (default `x-access-token`).
    - `hosts`: hosts it answers for (default `[ "github.com" ]`).
    - `configPath`, `ageKeyFile`: baked-in paths; when null, the helper uses
      `$FNOX_CONFIG` / `$FNOX_AGE_KEY_FILE` or the wrappers' defaults.
  */
  mkGitCredentialHelper =
    { fnoxPackage
    , secret ? "GITHUB_TOKEN"
    , username ? "x-access-token"
    , hosts ? [ "github.com" ]
    , configPath ? null
    , ageKeyFile ? null
    ,
    }:
    pkgs.writeShellApplication {
      name = "git-credential-fnox";
      runtimeInputs = [ pkgs.coreutils ];
      # WHY: baked-in paths are single-quoted on purpose (no expansion);
      # SC2016 would reject a path that happens to contain `$`.
      excludeShellChecks = [ "SC2016" ];
      text = ''
        action="''${1:-}"
        # Read the whole request, as git expects, whatever the action.
        protocol=""
        host=""
        while IFS= read -r line && [ -n "$line" ]; do
          case "$line" in
            protocol=*) protocol="''${line#protocol=}" ;;
            host=*) host="''${line#host=}" ;;
          esac
        done
        [ "$action" = get ] || exit 0
        [ "$protocol" = https ] || exit 0
        # WHY: git passes the host as written in the URL; match it the way
        # git matched the config (case-insensitive, default port optional).
        host="''${host,,}"
        host="''${host%:443}"
        hosts=${lib.escapeShellArg " ${lib.concatStringsSep " " (map normalizeGitHost hosts)} "}
        secret=${lib.escapeShellArg secret}
        case "$hosts" in
          *" $host "*) ;;
          *) exit 0 ;;
        esac

        # SECURITY: baked-in paths are single-quoted, so no shell expansion.
        config=${if configPath != null then lib.escapeShellArg configPath else "\"\${FNOX_CONFIG:-$HOME/.config/fnox/config.toml}\""}
        FNOX_AGE_KEY_FILE=${if ageKeyFile != null then lib.escapeShellArg ageKeyFile else "\"\${FNOX_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}\""}
        export FNOX_AGE_KEY_FILE
        err="$(mktemp)"
        trap 'rm -f "$err"' EXIT
        # WHY: unset the variable so fnox cannot hand back a token that is
        # only in the caller's environment; the credential must come from fnox.
        if ! token="$(env -u "$secret" ${fnoxPackage}/bin/fnox -c "$config" --if-missing error get "$secret" 2>"$err")" \
          || [ -z "$token" ]; then
          echo "git-credential-fnox: no $secret from fnox; trying the next helper" >&2
          cat "$err" >&2
          exit 0
        fi
        printf 'username=%s\npassword=%s\n' ${lib.escapeShellArg username} "$token"
      '';
    };

  /**
    Generate the config as a store path without realizing it during evaluation.

    Prefer this in NixOS and Home Manager modules so pure evaluation, including
    `nix flake check --no-build`, does not require an import-from-derivation.
  */
  mkFnoxConfigTomlFile =
    { recipients ? [ ]
    , secrets ? defaultSecretDefinitions
    , extraProviders ? { }
    , extraConfig ? { }
    ,
    }:
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
    );

  /**
    Return the generated fnox config as text.

    Prefer `mkFnoxConfigTomlFile` in module evaluation; this compatibility
    helper reads the generated file and therefore realizes its derivation.
  */
  mkFnoxConfigToml = args: builtins.readFile (mkFnoxConfigTomlFile args);

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
        # Optional recipient derived at activation from the SSH identity.
        recipient = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else None
        with open("${template}", "rb") as f:
            tmpl = tomllib.load(f)
        existing = {}
        if os.path.exists(target):
            with open(target, "rb") as f:
                existing = tomllib.load(f)

        merged = dict(existing)
        providers = dict(existing.get("providers", {}))
        providers.update(tmpl.get("providers", {}))
        if recipient:
            age = dict(providers.get("age", {"type": "age"}))
            age["recipients"] = [recipient]
            providers["age"] = age
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
