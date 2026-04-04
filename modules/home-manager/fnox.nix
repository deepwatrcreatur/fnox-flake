{ config
, lib
, pkgs
, ...
}:
let
  fnoxLib = import ../../lib/default.nix { inherit lib pkgs; };
  cfg = config.programs.fnox;
  configPath = "${config.xdg.configHome}/${cfg.configRelativePath}";
  wrappedPackages = lib.mapAttrsToList
    (
      name: spec:
        fnoxLib.mkWrappedCommand ({
          inherit name;
          fnoxPackage = cfg.package;
        } // spec)
    )
    cfg.wrappedCommands;
in
{
  options.programs.fnox = {
    enable = lib.mkEnableOption "fnox secret manager integration";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = if pkgs ? fnox then pkgs.fnox else null;
      description = "Fnox package to install. Defaults to pkgs.fnox when the fnox overlay is applied.";
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
    assertions =
      [
        {
          assertion = cfg.package != null;
          message = "programs.fnox.enable requires programs.fnox.package or pkgs.fnox to be available.";
        }
        {
          # An empty recipients list means fnox will generate a config with no
          # age recipients, making it impossible to encrypt any secrets.
          assertion = cfg.recipients != [ ];
          message = ''
            programs.fnox.recipients is empty. Provide at least one age public key so
            fnox can encrypt secrets (e.g. programs.fnox.recipients = [ "age1..." ];).
          '';
        }
      ]
      ++ lib.concatLists (
        lib.mapAttrsToList
          (
            name: spec:
              let
                envVars = map (s: s.envVar) spec.secrets;
                duplicateEnvVars = lib.unique (lib.filter (v: lib.count (x: x == v) envVars > 1) envVars);
              in
              [
                {
                  # Two secrets in the same wrapper exporting to the same env var
                  # means the first value is silently overwritten.
                  assertion = duplicateEnvVars == [ ];
                  message = "programs.fnox.wrappedCommands.${name}: duplicate envVar(s): ${lib.concatStringsSep ", " duplicateEnvVars}. Each secret must export to a unique environment variable.";
                }
              ]
              ++ map
                (secret: {
                  # A fnoxPath that isn't in secretDefinitions will cause fnox to fail
                  # at runtime with a confusing "secret not found" error.
                  assertion = lib.hasAttr secret.fnoxPath cfg.secretDefinitions;
                  message = "programs.fnox.wrappedCommands.${name}: fnoxPath '${secret.fnoxPath}' is not declared in programs.fnox.secretDefinitions. Add it to secretDefinitions or correct the fnoxPath.";
                })
                spec.secrets
          )
          cfg.wrappedCommands
      );

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
          fnoxPackage = cfg.package;
          secretSources = cfg.seedSecretSources;
        }
      )
    );
  };
}
