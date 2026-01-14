{
  description = "A flake for fnox, a secret manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    fnox-src = {
      url = "github:jdx/fnox/v1.7.0";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-utils,
      fnox-src,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        version = "1.7.0";

        # Function to create a wrapped command with fnox-decrypted secrets
        # Usage: mkWrappedCommand {
        #   name = "opencode";
        #   command = pkgs.opencode;
        #   secrets = [
        #     { envVar = "ANTHROPIC_API_KEY"; fnoxPath = "anthropic_api_key"; }
        #   ];
        # }
        mkWrappedCommand =
          {
            name,
            command,
            binaryName ? name,
            secrets ? [ ],
            extraWrapperScript ? "",
          }:
          pkgs.writeShellScriptBin name ''
            set -euo pipefail

            FNOX_BIN="${fnoxPackage}/bin/fnox"
            FNOX_CONFIG_PATH="''${FNOX_CONFIG:-$HOME/.config/fnox/config.toml}"
            export FNOX_AGE_KEY_FILE="''${FNOX_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

            ${pkgs.lib.concatMapStringsSep "\n" (secret: ''
              # Decrypt ${secret.envVar} from fnox
              value=""
              if ! value=$("$FNOX_BIN" -c "$FNOX_CONFIG_PATH" get "${secret.fnoxPath}" 2>&1); then
                echo "Error: Failed to decrypt secret '${secret.fnoxPath}' from fnox for ${secret.envVar}" >&2
                echo "$value" >&2
                echo "Make sure the secret exists: fnox -c $FNOX_CONFIG_PATH set ${secret.fnoxPath} <value>" >&2
                exit 1
              fi
              export ${secret.envVar}="$value"
            '') secrets}

            ${extraWrapperScript}

            # Execute the real command with all arguments
            exec ${command}/bin/${binaryName} "$@"
          '';

        # Build fnox from source using Rust
        fnoxFromSource = pkgs.rustPlatform.buildRustPackage {
          pname = "fnox";
          inherit version;

          src = fnox-src;

          cargoHash = "sha256-U3poZWMd1AMYv1v/rCoCuL24mxQOo++1WkLD/SxwNvU=";

          nativeBuildInputs = with pkgs; [
            perl
            pkg-config
          ];

          buildInputs = with pkgs; [
            openssl
          ];

          # Skip tests that require DBus and other runtime dependencies
          doCheck = false;

          meta = with pkgs.lib; {
            description = "A shell-agnostic secret manager";
            homepage = "https://github.com/jdx/fnox";
            license = licenses.mit;
            maintainers = [ ];
            platforms = platforms.unix;
          };
        };

        # Pre-built binary for Linux x86_64 (faster, no compilation needed)
        fnoxBinary = pkgs.stdenv.mkDerivation {
          pname = "fnox";
          inherit version;

          src = pkgs.fetchurl {
            url = "https://github.com/jdx/fnox/releases/download/v${version}/fnox-x86_64-unknown-linux-gnu.tar.gz";
            sha256 = "d593b853806212a75db74048d4cb27ac70f6811e591c1e29f496fb8af38475f3";
          };

          sourceRoot = ".";

          unpackPhase = ''
            runHook preUnpack
            tar -xzf "$src"
            runHook postUnpack
          '';

          dontConfigure = true;
          dontBuild = true;

          installPhase = ''
            runHook preInstall

            mkdir -p "$out/bin"
            install -m755 fnox "$out/bin/fnox"

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "A shell-agnostic secret manager";
            homepage = "https://github.com/jdx/fnox";
            license = licenses.mit;
            maintainers = [ ];
            platforms = [ "x86_64-linux" ];
          };
        };

        # Default: build from source for Nix compatibility.
        # The prebuilt upstream tarball is dynamically linked against `/lib64/ld-linux-*.so.*`,
        # which does not work on NixOS without extra compatibility layers (e.g. nix-ld).
        fnoxPackage = fnoxFromSource;

        wrappedCommands =
          (pkgs.lib.optionalAttrs (pkgs ? opencode) {
            opencode-claude = mkWrappedCommand {
              name = "opencode-claude";
              command = pkgs.opencode;
              binaryName = "opencode";
              secrets = [
                {
                  envVar = "ANTHROPIC_API_KEY";
                  fnoxPath = "anthropic_api_key";
                }
              ];
            };

            opencode-zai = mkWrappedCommand {
              name = "opencode-zai";
              command = pkgs.opencode;
              binaryName = "opencode";
              secrets = [
                {
                  envVar = "OPENAI_API_KEY";
                  fnoxPath = "Z_AI_API_KEY";
                }
              ];
              extraWrapperScript = ''
                export OPENCODE_PROVIDER="z.ai"
                export OPENCODE_MODEL="GLM 4.7"
              '';
            };
          })
          // (pkgs.lib.optionalAttrs (pkgs ? gh) {
            gh-fnox = mkWrappedCommand {
              name = "gh-fnox";
              command = pkgs.gh;
              binaryName = "gh";
              secrets = [
                {
                  envVar = "GITHUB_TOKEN";
                  fnoxPath = "GITHUB_TOKEN";
                }
                {
                  envVar = "GH_TOKEN";
                  fnoxPath = "GITHUB_TOKEN";
                }
              ];
            };
          })
          // (pkgs.lib.optionalAttrs (pkgs ? bitwarden-cli) {
            bw-fnox = mkWrappedCommand {
              name = "bw-fnox";
              command = pkgs.bitwarden-cli;
              binaryName = "bw";
              secrets = [
                {
                  envVar = "BW_SESSION";
                  fnoxPath = "BW_SESSION";
                }
              ];
            };
          });
      in
      {
        packages = {
          default = fnoxPackage;
          fnox = fnoxPackage;
          fnox-from-source = fnoxFromSource;
          fnox-binary = fnoxBinary;
        }
        // wrappedCommands;

        # Export the wrapper function for use in other flakes
        lib = {
          inherit mkWrappedCommand;
        };

        # Dev shell with atticd
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.atticd
            pkgs.attic-client
          ];
        };
      }
    )
    // {
      overlays.default = final: prev: {
        fnox = self.packages.${final.stdenv.hostPlatform.system}.default;
      };
    };
}
