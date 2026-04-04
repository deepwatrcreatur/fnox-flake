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
      sourceFile = pkgs.writeText "mock-secret-source" "my-test-secret-value";
      seedScript = pkgs.writeShellScript "test-seed-already-seeded" (
        fnoxLib.mkSeedSecretsScript {
          # get succeeds → already seeded → set should never be called
          fnoxPackage = fnoxGetSucceeds;
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
}
