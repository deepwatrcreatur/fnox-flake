{
  lib,
  pkgs,
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
    {
      envVar,
      fnoxPath ? envVar,
    }:
    {
      inherit envVar fnoxPath;
    };

  mkWrappedCommand =
    {
      name,
      command,
      fnoxPackage,
      binaryName ? name,
      secrets ? [ ],
      extraWrapperScript ? "",
    }:
    pkgs.writeShellScriptBin name ''
      set -euo pipefail

      FNOX_BIN="${fnoxPackage}/bin/fnox"
      FNOX_CONFIG_PATH="''${FNOX_CONFIG:-$HOME/.config/fnox/config.toml}"
      export FNOX_AGE_KEY_FILE="''${FNOX_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

      ${lib.concatMapStringsSep "\n" (
        secret: ''
          value=""
          err_file="$(mktemp)"
          if ! value=$("$FNOX_BIN" -c "$FNOX_CONFIG_PATH" get "${secret.fnoxPath}" 2>"$err_file"); then
            echo "Error: failed to decrypt '${secret.fnoxPath}' for ${secret.envVar}" >&2
            cat "$err_file" >&2
            rm -f "$err_file"
            exit 1
          fi
          rm -f "$err_file"
          export ${secret.envVar}="$value"
        ''
      ) secrets}

      ${extraWrapperScript}

      exec ${command}/bin/${binaryName} "$@"
    '';

  mkFnoxConfigToml =
    {
      recipients ? [ ],
      secrets ? defaultSecretDefinitions,
      extraProviders ? { },
      extraConfig ? { },
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

          secrets = lib.mapAttrs (
            _: value:
            {
              description = value.description;
              default = value.provider;
            }
          ) (lib.mapAttrs normalizedSecret secrets);
        }
        // extraConfig
      )
    );

  mkSeedSecretsScript =
    {
      fnoxPackage,
      secretSources,
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

        if "$FNOX_BIN" -c "$FNOX_CONFIG" get "$name" >/dev/null 2>&1; then
          return 0
        fi

        if [ ! -r "$file" ]; then
          echo "Warning: fnox seed source '$file' for '$name' is not readable; trying next source" >&2
          return 2
        fi

        value="$(cat "$file" 2>/dev/null || true)"
        if [ -z "$value" ]; then
          return 2
        fi

        set_output=""
        if ! set_output=$("$FNOX_BIN" -c "$FNOX_CONFIG" set "$name" "$value" 2>&1); then
          echo "Error: failed to seed fnox secret '$name' from '$file'" >&2
          echo "$set_output" >&2
          return 1
        fi
      }

      ${lib.concatStringsSep "\n" (lib.mapAttrsToList renderSources secretSources)}
    '';

  defaultWrappedCommandSpecs =
    {
      pkgs,
    }:
    (lib.optionalAttrs (pkgs ? opencode) {
      opencode-claude = {
        command = pkgs.opencode;
        binaryName = "opencode";
        secrets = [
          (mkSecretSpec {
            envVar = "ANTHROPIC_API_KEY";
            fnoxPath = "anthropic_api_key";
          })
        ];
      };

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
    });
}
