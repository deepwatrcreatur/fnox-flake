# Runtime behavior tests for mkWrappedCommand and mkSeedSecretsScript.
#
# Each test uses a fake fnox binary so no real secrets or key files are needed.
# Tests run as Nix sandbox derivations via pkgs.runCommand.
{ pkgs
, fnoxLib
,
}:
let
  # ---------------------------------------------------------------------------
  # Fake fnox binaries
  # ---------------------------------------------------------------------------

  # fnox where every 'get' call fails (secret not found / decryption error)
  fnoxGetFails = pkgs.writeShellScriptBin "fnox" ''
    while [ "$#" -gt 0 ]; do
      case "$1" in
        get) echo "mock: fnox get failed" >&2; exit 1 ;;
        -c) shift 2 ;;
        *) shift ;;
      esac
    done
    exit 0
  '';

  # fnox where 'get' succeeds and returns a known value; 'set' succeeds
  fnoxGetSucceeds = pkgs.writeShellScriptBin "fnox" ''
    while [ "$#" -gt 0 ]; do
      case "$1" in
        get) echo "mock-secret-value"; exit 0 ;;
        set) exit 0 ;;
        -c) shift 2 ;;
        *) shift ;;
      esac
    done
    exit 0
  '';

  # fnox where 'get' returns a stale placeholder ("age") and 'set' records the
  # value it receives on stdin into $FNOX_TEST_SET_LOG.
  fnoxGetStale = pkgs.writeShellScriptBin "fnox" ''
    while [ "$#" -gt 0 ]; do
      case "$1" in
        get) echo "age"; exit 0 ;;
        set)
          shift
          if [ "$#" -gt 1 ]; then echo "mock: value passed on argv" >&2; exit 1; fi
          cat > "$FNOX_TEST_SET_LOG"
          exit 0 ;;
        -c) shift 2 ;;
        *) shift ;;
      esac
    done
    exit 0
  '';

  # fnox where 'get' only sees the environment (nothing stored) and 'set'
  # records the value it receives on stdin into $FNOX_TEST_SET_LOG.
  fnoxEnvOnly = pkgs.writeShellScriptBin "fnox" ''
    while [ "$#" -gt 0 ]; do
      case "$1" in
        get)
          if [ -n "''${TEST_KEY:-}" ]; then echo "$TEST_KEY"; exit 0; fi
          exit 1 ;;
        set) cat > "$FNOX_TEST_SET_LOG"; exit 0 ;;
        -c) shift 2 ;;
        *) shift ;;
      esac
    done
    exit 0
  '';

  # fnox 1.19 behaviour for a missing secret: 'get' exits 0 with no output
  # unless --if-missing error is given.
  fnoxMissingLenient = pkgs.writeShellScriptBin "fnox" ''
    strict=0
    for a in "$@"; do [ "$a" = "error" ] && strict=1; done
    for a in "$@"; do
      if [ "$a" = "get" ]; then
        echo "warning: secret not found" >&2
        [ "$strict" = 1 ] && exit 1
        exit 0
      fi
    done
    exit 0
  '';

  # fnox where 'get' returns mock-secret-value and 'set' must never be called.
  fnoxGetSameSetForbidden = pkgs.writeShellScriptBin "fnox" ''
    while [ "$#" -gt 0 ]; do
      case "$1" in
        get) echo "mock-secret-value"; exit 0 ;;
        set) echo "mock: set must not be called when the value is unchanged" >&2; exit 1 ;;
        -c) shift 2 ;;
        *) shift ;;
      esac
    done
    exit 0
  '';

  # fnox where 'get' fails (not yet seeded) and 'set' also fails (e.g. bad config)
  fnoxSetFails = pkgs.writeShellScriptBin "fnox" ''
    while [ "$#" -gt 0 ]; do
      case "$1" in
        get) exit 1 ;;
        set) echo "mock: fnox set failed" >&2; exit 1 ;;
        -c) shift 2 ;;
        *) shift ;;
      esac
    done
    exit 0
  '';

  # ---------------------------------------------------------------------------
  # Shared helpers
  # ---------------------------------------------------------------------------

  testSecret = fnoxLib.mkSecretSpec { envVar = "TEST_SECRET"; };

  # Fake wrapped command that verifies TEST_SECRET is set to the expected value
  fakeCommandChecksEnv = pkgs.writeShellScriptBin "fake-cmd" ''
    if [ "$TEST_SECRET" = "mock-secret-value" ]; then
      exit 0
    fi
    echo "FAIL: expected TEST_SECRET=mock-secret-value, got: $TEST_SECRET" >&2
    exit 1
  '';

  fakeCommandOk = pkgs.writeShellScriptBin "fake-cmd" ''exit 0'';

  # Common env overrides so the scripts never touch $HOME
  sandboxEnv = {
    HOME = "/tmp";
    FNOX_CONFIG = "/dev/null";
    FNOX_AGE_KEY_FILE = "/dev/null";
  };

in
{
  # -------------------------------------------------------------------------
  # mkWrappedCommand tests
  # -------------------------------------------------------------------------

  # Wrapper must exit non-zero when fnox get fails for any secret
  wrapper-exits-on-fnox-get-failure =
    let
      wrapper = fnoxLib.mkWrappedCommand {
        name = "test-wrapper-fail";
        command = fakeCommandOk;
        binaryName = "fake-cmd";
        fnoxPackage = fnoxGetFails;
        secrets = [ testSecret ];
      };
    in
    pkgs.runCommand "wrapper-exits-on-fnox-get-failure" sandboxEnv ''
      if ${wrapper}/bin/test-wrapper-fail; then
        echo "FAIL: expected wrapper to exit non-zero when fnox get fails" >&2
        exit 1
      fi
      touch "$out"
    '';

  # Wrapper must export the secret as an env var and exec the wrapped command
  wrapper-exports-secret-on-success =
    let
      wrapper = fnoxLib.mkWrappedCommand {
        name = "test-wrapper-success";
        command = fakeCommandChecksEnv;
        binaryName = "fake-cmd";
        fnoxPackage = fnoxGetSucceeds;
        secrets = [ testSecret ];
      };
    in
    pkgs.runCommand "wrapper-exports-secret-on-success" sandboxEnv ''
      ${wrapper}/bin/test-wrapper-success
      touch "$out"
    '';

  # Wrapper with no secrets must exec the command directly without calling fnox
  wrapper-no-secrets-executes-command =
    let
      wrapper = fnoxLib.mkWrappedCommand {
        name = "test-wrapper-no-secrets";
        command = fakeCommandOk;
        binaryName = "fake-cmd";
        fnoxPackage = fnoxGetFails; # would fail if called
        secrets = [ ];
      };
    in
    pkgs.runCommand "wrapper-no-secrets-executes-command" sandboxEnv ''
      ${wrapper}/bin/test-wrapper-no-secrets
      touch "$out"
    '';

  # -------------------------------------------------------------------------
  # mkSeedSecretsScript tests
  # -------------------------------------------------------------------------

  # Missing source paths must be skipped silently (no exit 1)
  seed-skips-missing-sources =
    let
      seedScript = pkgs.writeShellScript "test-seed-missing" (
        fnoxLib.mkSeedSecretsScript {
          fnoxPackage = fnoxGetFails;
          secretSources = {
            TEST_KEY = [
              "/nonexistent/path1"
              "/nonexistent/path2"
            ];
          };
        }
      );
    in
    pkgs.runCommand "seed-skips-missing-sources" sandboxEnv ''
      ${seedScript}
      touch "$out"
    '';

  # An empty source file must be skipped and not treated as a fatal error
  seed-skips-empty-source =
    let
      seedScript = pkgs.writeShellScript "test-seed-empty" (
        fnoxLib.mkSeedSecretsScript {
          fnoxPackage = fnoxGetFails;
          secretSources = {
            # /dev/null is always readable and always empty
            TEST_KEY = [ "/dev/null" ];
          };
        }
      );
    in
    pkgs.runCommand "seed-skips-empty-source" sandboxEnv ''
      ${seedScript}
      touch "$out"
    '';

  # A valid source file must result in fnox set being called successfully
  seed-seeds-from-valid-source =
    let
      sourceFile = pkgs.writeText "mock-secret-source" "my-test-secret-value";
      seedScript = pkgs.writeShellScript "test-seed-valid" (
        fnoxLib.mkSeedSecretsScript {
          # get fails → not yet seeded; set succeeds
          fnoxPackage = fnoxGetFails;
          secretSources = {
            TEST_KEY = [ "${sourceFile}" ];
          };
        }
      );
    in
    pkgs.runCommand "seed-seeds-from-valid-source" sandboxEnv ''
      ${seedScript}
      touch "$out"
    '';

  # A failed fnox set must cause the seed script to exit non-zero
  seed-exits-on-set-failure =
    let
      sourceFile = pkgs.writeText "mock-secret-source" "my-test-secret-value";
      seedScript = pkgs.writeShellScript "test-seed-set-fail" (
        fnoxLib.mkSeedSecretsScript {
          fnoxPackage = fnoxSetFails;
          secretSources = {
            TEST_KEY = [ "${sourceFile}" ];
          };
        }
      );
    in
    pkgs.runCommand "seed-exits-on-set-failure" sandboxEnv ''
      if ${seedScript}; then
        echo "FAIL: expected seed script to exit non-zero when fnox set fails" >&2
        exit 1
      fi
      touch "$out"
    '';

  # Already-seeded secret (get succeeds) must be skipped without calling set
  seed-skips-already-seeded =
    let
      sourceFile = pkgs.writeText "mock-same-secret-source" "mock-secret-value";
      seedScript = pkgs.writeShellScript "test-seed-already-seeded" (
        fnoxLib.mkSeedSecretsScript {
          # get returns the same value as the source -> set must not run
          fnoxPackage = fnoxGetSameSetForbidden;
          secretSources = {
            TEST_KEY = [ "${sourceFile}" ];
          };
        }
      );
    in
    pkgs.runCommand "seed-skips-already-seeded" sandboxEnv ''
      ${seedScript}
      touch "$out"
    '';

  # The legacy placeholder "age" (left by configs that rendered
  # `default = <provider>`) is not a stored value: seed it, via stdin.
  seed-replaces-legacy-placeholder =
    let
      sourceFile = pkgs.writeText "mock-new-secret-source" "ghp_rotatedtoken";
      seedScript = pkgs.writeShellScript "test-seed-drift" (
        fnoxLib.mkSeedSecretsScript {
          fnoxPackage = fnoxGetStale;
          secretSources = {
            TEST_KEY = [ "${sourceFile}" ];
          };
        }
      );
    in
    pkgs.runCommand "seed-replaces-legacy-placeholder" sandboxEnv ''
      export FNOX_TEST_SET_LOG="$PWD/set.log"
      ${seedScript}
      test "$(cat "$FNOX_TEST_SET_LOG")" = "ghp_rotatedtoken"
      touch "$out"
    '';

  # A value only in the environment is not stored: seeding must still run.
  seed-ignores-env-fallback =
    let
      sourceFile = pkgs.writeText "mock-env-secret-source" "ghp_fromsource";
      seedScript = pkgs.writeShellScript "test-seed-env" (
        fnoxLib.mkSeedSecretsScript {
          fnoxPackage = fnoxEnvOnly;
          secretSources = {
            TEST_KEY = [ "${sourceFile}" ];
          };
        }
      );
    in
    pkgs.runCommand "seed-ignores-env-fallback" sandboxEnv ''
      export FNOX_TEST_SET_LOG="$PWD/set.log"
      export TEST_KEY=ghp_fromsource
      ${seedScript}
      test "$(cat "$FNOX_TEST_SET_LOG")" = "ghp_fromsource"
      touch "$out"
    '';

  # A wrapper must refuse to run when a secret is missing, even though plain
  # `fnox get` exits 0 for it.
  wrapper-fails-on-missing-secret =
    let
      wrapper = fnoxLib.mkWrappedCommand {
        name = "test-missing";
        command = pkgs.coreutils;
        binaryName = "true";
        secrets = [ testSecret ];
        fnoxPackage = fnoxMissingLenient;
      };
    in
    pkgs.runCommand "wrapper-fails-on-missing-secret" sandboxEnv ''
      if ${wrapper}/bin/test-missing; then
        echo "wrapper ran despite a missing secret" >&2
        exit 1
      fi
      touch "$out"
    '';

  # The merge keeps stored values and user entries, takes providers and
  # declarations from the template, and drops the legacy `default` placeholder.
  config-merge-keeps-values =
    let
      merge = fnoxLib.mkFnoxConfigMergeScript {
        template = fnoxLib.mkFnoxConfigTomlFile {
          recipients = [ "age1new" ];
          secrets = {
            KEPT = { description = "kept"; };
            LEGACY = { description = "legacy"; };
            FRESH = { description = "fresh"; };
          };
        };
      };
      existing = pkgs.writeText "existing.toml" ''
        [providers.age]
        type = "age"
        recipients = ["age1old"]

        [secrets.KEPT]
        provider = "age"
        value = "c2VjcmV0"

        [secrets.LEGACY]
        default = "age"
        description = "old"

        [secrets.USER_ONLY]
        provider = "age"
        value = "dXNlcg=="
      '';
      check = pkgs.writers.writePython3 "check-merge" { } ''
        import sys
        import tomllib

        with open(sys.argv[1], "rb") as f:
            c = tomllib.load(f)
        assert c["providers"]["age"]["recipients"] == ["age1new"], c
        assert c["secrets"]["KEPT"]["value"] == "c2VjcmV0", c
        assert "default" not in c["secrets"]["LEGACY"], c
        assert c["secrets"]["LEGACY"]["provider"] == "age", c
        assert "value" not in c["secrets"]["FRESH"], c
        assert c["secrets"]["USER_ONLY"]["value"] == "dXNlcg==", c
      '';
    in
    pkgs.runCommand "config-merge-keeps-values" sandboxEnv ''
      cp ${existing} cfg.toml
      chmod 644 cfg.toml
      ${merge} cfg.toml
      ${check} cfg.toml
      test "$(stat -c %a cfg.toml)" = 600
      touch "$out"
    '';

  # Declared secrets render with `provider`, never `default` (which fnox treats
  # as the fallback value).
  config-renders-provider-not-default =
    let
      toml = fnoxLib.mkFnoxConfigTomlFile {
        recipients = [ "age1example" ];
        secrets = {
          TEST_KEY = { description = "test"; };
        };
      };
    in
    pkgs.runCommand "config-renders-provider-not-default" sandboxEnv ''
      grep -q '^provider = "age"' ${toml}
      ! grep -q '^default' ${toml}
      touch "$out"
    '';

  # A source file with multiline content must be skipped (not seeded).
  # Multiline content is treated as invalid — real tokens are single-line,
  # and error messages from failed decryption tools (e.g. SOPS) are multiline.
  seed-skips-multiline-source =
    let
      # Simulates a token file that contains a SOPS/decrypt failure message.
      badSourceFile = pkgs.writeText "mock-bad-secret-source" ''
        Error: SOPS decryption failed
        could not find a valid key
      '';
      seedScript = pkgs.writeShellScript "test-seed-multiline" (
        fnoxLib.mkSeedSecretsScript {
          # fnoxSetFails would catch if set is ever attempted — but the
          # multiline guard should prevent set from being called at all.
          fnoxPackage = fnoxSetFails;
          secretSources = {
            TEST_KEY = [ "${badSourceFile}" ];
          };
        }
      );
    in
    pkgs.runCommand "seed-skips-multiline-source" sandboxEnv ''
      # Must exit 0 (skip, not fatal) even though set would fail if called.
      ${seedScript}
      touch "$out"
    '';

  # Multiline source must be skipped in favour of a later valid single-line source.
  seed-falls-through-to-next-source-after-multiline =
    let
      badSourceFile = pkgs.writeText "mock-bad-secret-source" ''
        Error: something went wrong
        check your config
      '';
      goodSourceFile = pkgs.writeText "mock-good-secret-source" "ghp_validtoken";
      seedScript = pkgs.writeShellScript "test-seed-fallthrough" (
        fnoxLib.mkSeedSecretsScript {
          # get fails (not seeded), set succeeds
          fnoxPackage = fnoxGetFails;
          secretSources = {
            TEST_KEY = [
              "${badSourceFile}"
              "${goodSourceFile}"
            ];
          };
        }
      );
    in
    pkgs.runCommand "seed-falls-through-to-next-source-after-multiline" sandboxEnv ''
      # The bad (multiline) file must be skipped and the good file must seed successfully.
      ${seedScript}
      touch "$out"
    '';
}
