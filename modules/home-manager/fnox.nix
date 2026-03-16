{
  config,
  lib,
  pkgs,
  ...
}:
let
  fnoxLib = import ../../lib/default.nix { inherit lib pkgs; };
  cfg = config.programs.fnox;
  configPath = "${config.xdg.configHome}/${cfg.configRelativePath}";
  wrappedPackages = lib.mapAttrsToList (
    name: spec:
    fnoxLib.mkWrappedCommand ({
      inherit name;
      fnoxPackage = cfg.package;
    } // spec)
  ) cfg.wrappedCommands;
in
{
  options.programs.fnox = {
    enable = lib.mkEnableOption "fnox secret manager integration";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = if pkgs ? fnox then pkgs.fnox else null;
      description = "Fnox package to install.";
    };

    configRelativePath = lib.mkOption {
      type = lib.types.str;
      default = "fnox/config.toml";
      description = "Path relative to XDG config home for fnox configuration.";
    };

    ageKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      description = "Age identity file used by fnox.";
    };

    recipients = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Age recipients written into the fnox config.";
    };

    secretDefinitions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          description = lib.mkOption {
            type = lib.types.str;
          };

          provider = lib.mkOption {
            type = lib.types.str;
            default = "age";
          };
        };
      });
      default = fnoxLib.defaultSecretDefinitions;
      description = "Secrets declared in the fnox configuration.";
    };

    seedSecretSources = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      description = "Fallback source files to seed into fnox during Home Manager activation.";
    };

    wrappedCommands = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          command = lib.mkOption {
            type = lib.types.package;
          };

          binaryName = lib.mkOption {
            type = lib.types.str;
          };

          secrets = lib.mkOption {
            type = lib.types.listOf (lib.types.submodule {
              options = {
                envVar = lib.mkOption {
                  type = lib.types.str;
                };

                fnoxPath = lib.mkOption {
                  type = lib.types.str;
                };
              };
            });
            default = [ ];
          };

          extraWrapperScript = lib.mkOption {
            type = lib.types.lines;
            default = "";
          };
        };
      });
      default = fnoxLib.defaultWrappedCommandSpecs { inherit pkgs; };
      description = "Wrapped commands that fetch selected fnox secrets before execution.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "programs.fnox.enable requires programs.fnox.package or pkgs.fnox to be available.";
      }
    ];

    home.sessionVariables = {
      FNOX_AGE_KEY_FILE = cfg.ageKeyFile;
      FNOX_CONFIG = configPath;
    };

    home.packages = [ cfg.package ] ++ wrappedPackages;

    xdg.configFile.${cfg.configRelativePath}.text = fnoxLib.mkFnoxConfigToml {
      recipients = cfg.recipients;
      secrets = cfg.secretDefinitions;
    };

    home.activation.fnoxSeedSecrets = lib.mkIf (cfg.seedSecretSources != { }) (
      lib.hm.dag.entryAfter [ "writeBoundary" ] (
        fnoxLib.mkSeedSecretsScript {
          secretSources = cfg.seedSecretSources;
        }
      )
    );
  };
}
