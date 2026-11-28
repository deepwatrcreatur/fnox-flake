{ config
, lib
, options
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
  gitHelper = fnoxLib.mkGitCredentialHelper {
    fnoxPackage = cfg.package;
    inherit (cfg.gitCredentialHelper) secret username hosts;
    # WHY: baked in, because git may run without the session variables
    # (agent shells, GIT_CONFIG_GLOBAL=/dev/null, cron).
    inherit configPath;
    ageKeyFile = cfg.ageKeyFile;
  };
  gitCredentialSettings = {
    credential = lib.listToAttrs (map
      (host: {
        # WHY: normalised, so the key matches programs.gh's lowercase one and
        # the override replaces it instead of adding a second section.
        name = "https://${fnoxLib.normalizeGitHost host}";
        # WHY: the override drops other modules' definitions of this setting
        # (programs.gh adds [ "" "gh auth git-credential" ], whose "" would
        # clear fnox), and "" clears helpers git read earlier for this URL.
        # GOTCHA: helpers git reads later (an included file, a separate
        # `https://github.com:443` section) still run and receive `store`.
        value.helper = lib.mkOverride 60 [ "" "${gitHelper}/bin/git-credential-fnox" ];
      })
      cfg.gitCredentialHelper.hosts);
  };
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
      default =
        if cfg.sshIdentity.enable then
          cfg.sshIdentity.keyFile
        else
          "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      defaultText = lib.literalExpression ''
        if sshIdentity.enable then sshIdentity.keyFile else "~/.config/sops/age/keys.txt"
      '';
      description = "Age identity file used by fnox.";
    };

    sshIdentity = {
      enable = lib.mkEnableOption ''
        using this account's own SSH key as the fnox identity. Activation
        derives the age recipient from the private key (`ssh-keygen -y`), so
        recipient and identity always match and no shared age key has to be
        distributed. If the key is missing, fnox setup is skipped with a warning
      '';
      keyFile = lib.mkOption {
        type = lib.types.str;
        default = "${config.home.homeDirectory}/.ssh/id_ed25519";
        description = "Unencrypted SSH private key (ed25519 or RSA) used as the fnox identity.";
      };
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

    gitCredentialHelper = {
      enable = lib.mkEnableOption ''
        `git-credential-fnox`: git gets HTTPS credentials for `hosts` from the
        fnox secret `secret`, never from a token file. It replaces the other
        credential helpers configured for those hosts in Home Manager or earlier
        in the git config (such as `gh auth git-credential`),
        so enable it only where fnox can decrypt the token. Needs
        `programs.git.enable`, since Home Manager writes the git config only
        then. The helper is also installed, so `git -c credential.helper=fnox`
        works with the global config off
      '';
      hosts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "github.com" ];
        description = "Hosts the helper answers for (HTTPS only).";
      };
      secret = lib.mkOption {
        type = lib.types.str;
        default = "GITHUB_TOKEN";
        description = "fnox secret that holds the token.";
      };
      username = lib.mkOption {
        type = lib.types.str;
        default = "x-access-token";
        description = "User name sent with the token.";
      };
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
          assertion = cfg.recipients != [ ] || cfg.sshIdentity.enable;
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
      )
      ++ [
        {
          # WHY: Home Manager writes the git config only with programs.git on;
          # without it the helper would be installed but never asked.
          assertion = !cfg.gitCredentialHelper.enable || config.programs.git.enable;
          message = "programs.fnox.gitCredentialHelper needs programs.git.enable (Home Manager writes the git config only then). Without it, use `git -c credential.helper=fnox`.";
        }
        {
          assertion = !cfg.gitCredentialHelper.enable || lib.hasAttr cfg.gitCredentialHelper.secret cfg.secretDefinitions;
          message = "programs.fnox.gitCredentialHelper.secret '${cfg.gitCredentialHelper.secret}' is not declared in programs.fnox.secretDefinitions.";
        }
      ];

    home.sessionVariables = {
      FNOX_AGE_KEY_FILE = cfg.ageKeyFile;
      FNOX_CONFIG = configPath;
    };

    home.packages = [ cfg.package ] ++ wrappedPackages
      ++ lib.optional cfg.gitCredentialHelper.enable gitHelper
      ++ lib.optional (cfg.seedSecretSources != { }) (fnoxLib.mkFnoxCheck {
      fnoxPackage = cfg.package;
      secretSources = cfg.seedSecretSources;
    });

    # GOTCHA: Home Manager renamed programs.git.extraConfig to settings.
    programs.git = lib.mkIf cfg.gitCredentialHelper.enable (
      if options.programs.git ? settings
      then { settings = gitCredentialSettings; }
      else { extraConfig = gitCredentialSettings; }
    );

    # WHY: not xdg.configFile. A store symlink is read-only, so `fnox set`
    # (seeding, or the user) could not write to it, and replacing it with a
    # regular file made later activations collide with Home Manager's link.
    # The generated settings are merged into a writable file instead, keeping
    # stored values.
    home.activation.fnoxConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      # Home Manager runs all activation steps in one shell, so fnoxSkip is
      # seen by fnoxSeedSecrets below.
      fnoxSkip=""
      fnox_recipient=""
      ${lib.optionalString cfg.sshIdentity.enable ''
        if [ -r ${lib.escapeShellArg cfg.sshIdentity.keyFile} ] \
          && fnox_pub="$(${pkgs.openssh}/bin/ssh-keygen -y -P "" -f ${lib.escapeShellArg cfg.sshIdentity.keyFile} 2>/dev/null)"; then
          fnox_recipient="$(printf '%s' "$fnox_pub" | ${pkgs.coreutils}/bin/cut -d' ' -f1,2)"
        else
          echo "Warning: fnox SSH identity ${cfg.sshIdentity.keyFile} is missing, unreadable or passphrase-protected; skipping fnox config and seeding" >&2
          fnoxSkip=1
        fi
      ''}
      if [ -z "$fnoxSkip" ]; then
      if [ -L ${lib.escapeShellArg configPath} ]; then
        # A store link from an older version of this module.
        tmp="$(mktemp)"
        cat ${lib.escapeShellArg configPath} > "$tmp"
        rm -f ${lib.escapeShellArg configPath}
        install -m 600 "$tmp" ${lib.escapeShellArg configPath}
        rm -f "$tmp"
      fi
      $DRY_RUN_CMD ${fnoxLib.mkFnoxConfigMergeScript {
        template = pkgs.writeText "fnox-config-template.toml" (fnoxLib.mkFnoxConfigToml {
          recipients = cfg.recipients;
          secrets = cfg.secretDefinitions;
        });
      }} ${lib.escapeShellArg configPath} "$fnox_recipient"
      fi
    '';

    home.activation.fnoxSeedSecrets = lib.mkIf (cfg.seedSecretSources != { }) (
      lib.hm.dag.entryAfter [ "fnoxConfig" ] ''
        FNOX_CONFIG=${lib.escapeShellArg configPath}
        FNOX_AGE_KEY_FILE=${lib.escapeShellArg cfg.ageKeyFile}
        export FNOX_CONFIG FNOX_AGE_KEY_FILE
        # GOTCHA: the seed script uses `exit`; a subshell keeps that from ending
        # the rest of the Home Manager activation, and a real failure still
        # fails activation.
        if [ -z "''${fnoxSkip:-}" ]; then
        (
        ${fnoxLib.mkSeedSecretsScript {
          fnoxPackage = cfg.package;
          secretSources = cfg.seedSecretSources;
        }}
        ) || exit $?
        fi
      ''
    );
  };
}
