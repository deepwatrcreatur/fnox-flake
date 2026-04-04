{
  description = "Fnox flake with packages, wrappers, apps, and Home Manager integration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-utils,
    }:
    let
      version = "1.19.0";
      fnoxSrc = builtins.fetchTarball {
        url = "https://github.com/jdx/fnox/archive/refs/tags/v${version}.tar.gz";
        sha256 = "sha256:0pzzjzhhxmhvgrfd38vfjva175mi5b7f1pd1v84i4j1dlb824x13";
      };
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        fnoxLib = import ./lib/default.nix {
          inherit (pkgs) lib;
          inherit pkgs;
        };

        fnoxFromSource = import ./pkgs/fnox-source.nix {
          inherit pkgs version fnoxSrc;
        };

        fnoxBinary =
          if
            system == "x86_64-linux"
            || system == "aarch64-linux"
            || system == "x86_64-darwin"
            || system == "aarch64-darwin"
          then
            import ./pkgs/fnox-binary.nix {
              inherit pkgs version;
            }
          else
            null;

        # Strategy: source-first for reproducibility.
        # packages.default and packages.fnox always use the source build so that
        # the result is identical across machines and does not depend on upstream
        # releasing a binary for the current platform.
        # Use packages.fnox-binary for a faster install when build time matters.
        fnoxPackage = fnoxFromSource;

        wrappedCommandSpecs = fnoxLib.defaultWrappedCommandSpecs { inherit pkgs; };
        wrappedCommands = pkgs.lib.mapAttrs (
          name: spec:
          fnoxLib.mkWrappedCommand (
            {
              inherit name fnoxPackage;
            }
            // spec
          )
        ) wrappedCommandSpecs;

        packages = {
          default = fnoxPackage;
          fnox = fnoxPackage;
          fnox-from-source = fnoxFromSource;
        }
        // pkgs.lib.optionalAttrs (fnoxBinary != null) {
          fnox-binary = fnoxBinary;
        }
        // wrappedCommands;

        apps = pkgs.lib.mapAttrs (_: drv: {
          type = "app";
          program = "${drv}/bin/${drv.meta.mainProgram or drv.pname or drv.name}";
        }) packages;

        checks = {
          fnox-config-render =
            let
              configToml = pkgs.writeText "fnox-config.toml" (
                fnoxLib.mkFnoxConfigToml {
                  recipients = [
                    "age1example000000000000000000000000000000000000000000000000000000"
                  ];
                }
              );
            in
            pkgs.runCommand "fnox-config-render-check" { } ''
              grep -q '\[providers.age\]' ${configToml}
              grep -q '\[secrets.GITHUB_TOKEN\]' ${configToml}
              grep -q 'Z_AI_API_KEY' ${configToml}
              touch $out
            '';
        }
        // pkgs.lib.optionalAttrs (wrappedCommands ? gh-fnox) {
          gh-wrapper-script = pkgs.runCommand "gh-fnox-wrapper-check" { } ''
            grep -q 'export GITHUB_TOKEN=' ${wrappedCommands.gh-fnox}/bin/gh-fnox
            grep -q 'export GH_TOKEN=' ${wrappedCommands.gh-fnox}/bin/gh-fnox
            touch $out
          '';
        }
        // pkgs.lib.optionalAttrs (wrappedCommands ? opencode-zai) {
          opencode-zai-wrapper-script = pkgs.runCommand "opencode-zai-wrapper-check" { } ''
            grep -q 'OPENCODE_PROVIDER="z.ai"' ${wrappedCommands.opencode-zai}/bin/opencode-zai
            grep -q 'OPENAI_API_KEY' ${wrappedCommands.opencode-zai}/bin/opencode-zai
            touch $out
          '';
        }
        // import ./checks/wrapper-tests.nix {
          inherit pkgs fnoxLib;
        };

        devShell = pkgs.mkShell {
          packages = with pkgs; [
            cargo
            cargo-nextest
            clippy
            openssl
            pkg-config
            rustc
            rustfmt
          ];
        };
      in
      {
        inherit apps checks packages;

        devShells.default = devShell;

        lib = fnoxLib // {
          inherit wrappedCommandSpecs;
        };
      }
    )
    // {
      overlays.default = final: prev: {
        fnox = self.packages.${nixpkgs.lib.currentSystem}.default;
      };

      homeManagerModules.default = ./modules/home-manager/fnox.nix;
    };
}
