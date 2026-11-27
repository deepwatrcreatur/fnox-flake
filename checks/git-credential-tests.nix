# Runtime tests for mkGitCredentialHelper, driven through real
# `git credential fill` with a fake fnox, so no secrets are needed.
{ pkgs
, fnoxLib
,
}:
let
  # Fake fnox: logs its arguments, returns "ambient" if the secret leaked in
  # from the caller's environment, a fixed token for GITHUB_TOKEN, and fails
  # for anything else.
  fnoxStub = pkgs.writeShellScriptBin "fnox" ''
    printf '%s\n' "$*" >> "$FNOX_TEST_LOG"
    if [ -n "''${GITHUB_TOKEN:-}" ]; then echo ambient; exit 0; fi
    for a in "$@"; do last="$a"; done
    if [ "$last" = GITHUB_TOKEN ]; then echo test-value-from-fnox; exit 0; fi
    echo "mock: secret $last not found" >&2
    exit 1
  '';

  helper = fnoxLib.mkGitCredentialHelper { fnoxPackage = fnoxStub; };
  helperBaked = fnoxLib.mkGitCredentialHelper {
    fnoxPackage = fnoxStub;
    configPath = "/baked/config.toml";
    hosts = [ "github.com" "Gist.GitHub.com:443" ];
  };
  helperOddPath = fnoxLib.mkGitCredentialHelper {
    fnoxPackage = fnoxStub;
    configPath = "/tmp/$(touch /tmp/fnox-injected)/config.toml";
  };
  helperMissing = fnoxLib.mkGitCredentialHelper {
    fnoxPackage = fnoxStub;
    secret = "NOT_STORED";
  };
  helperOddSecret = fnoxLib.mkGitCredentialHelper {
    fnoxPackage = fnoxStub;
    secret = "X$(touch /tmp/fnox-injected-secret)";
    hosts = [ "github.com" "h$(touch /tmp/fnox-injected-host)" ];
  };
in
{
  git-credential-fnox = pkgs.runCommand "git-credential-fnox-tests"
    { nativeBuildInputs = [ pkgs.git ]; }
    ''
      want=test-value-from-fnox
      export HOME="$PWD/home" FNOX_TEST_LOG="$PWD/fnox.log" GIT_CONFIG_NOSYSTEM=1
      mkdir -p "$HOME"
      : > "$FNOX_TEST_LOG"
      # INVARIANT: no fallback helper and no prompt, so only our helper answers.
      export GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/false
      fill() { # helper-dir, request
        cmd="$1/bin/git-credential-fnox"
        printf '%b' "$2" | git -c credential.helper= -c "credential.helper=$cmd" credential fill 2>"$PWD/err" || true
      }

      echo "github.com over https gets the fnox token"
      res="$(fill ${helper} 'protocol=https\nhost=github.com\n\n')"
      echo "$res" | grep -qx 'username=x-access-token'
      echo "$res" | grep -qx "password=$want"
      grep -q -- '--if-missing error get GITHUB_TOKEN' "$FNOX_TEST_LOG"
      grep -q -- "-c $HOME/.config/fnox/config.toml" "$FNOX_TEST_LOG"

      echo "an ambient GITHUB_TOKEN is not passed to fnox"
      res="$(GITHUB_TOKEN=test-value-ambient fill ${helper} 'protocol=https\nhost=github.com\n\n')"
      echo "$res" | grep -qx "password=$want"

      echo "FNOX_CONFIG is honoured when no path is baked in"
      : > "$FNOX_TEST_LOG"
      FNOX_CONFIG=/custom/config.toml fill ${helper} 'protocol=https\nhost=github.com\n\n' >/dev/null
      grep -q -- '-c /custom/config.toml' "$FNOX_TEST_LOG"

      echo "a baked-in path wins over FNOX_CONFIG"
      : > "$FNOX_TEST_LOG"
      FNOX_CONFIG=/custom/config.toml fill ${helperBaked} 'protocol=https\nhost=gist.github.com\n\n' | grep -qx "password=$want"
      grep -q -- '-c /baked/config.toml' "$FNOX_TEST_LOG"

      echo "a baked-in path is used literally, never expanded"
      : > "$FNOX_TEST_LOG"
      fill ${helperOddPath} 'protocol=https\nhost=github.com\n\n' >/dev/null
      grep -qF -- '-c /tmp/$(touch /tmp/fnox-injected)/config.toml' "$FNOX_TEST_LOG"
      [ ! -e /tmp/fnox-injected ]

      echo "configured hosts are normalised the same way"
      fill ${helperBaked} 'protocol=https\nhost=gist.github.com:443\n\n' | grep -qx "password=$want"

      echo "host spelling: case and an explicit :443 still match"
      for h in GitHub.com github.com:443; do
        fill ${helper} "protocol=https\nhost=$h\n\n" | grep -qx "password=$want"
      done

      echo "other hosts and plain http get nothing, and fnox is not asked"
      : > "$FNOX_TEST_LOG"
      for req in 'protocol=https\nhost=gitlab.com\n\n' 'protocol=http\nhost=github.com\n\n' 'protocol=https\nhost=github.com:8443\n\n' 'protocol=https\nhost=evilgithub.com\n\n'; do
        res="$(fill ${helper} "$req")"
        if echo "$res" | grep -q '^password='; then echo "unexpected credential for $req"; exit 1; fi
      done
      [ ! -s "$FNOX_TEST_LOG" ]

      echo "store and erase are ignored and succeed"
      for action in store erase; do
        printf 'protocol=https\nhost=github.com\nusername=u\n%s=%s\n\n' password "$action-value" | ${helper}/bin/git-credential-fnox "$action"
      done
      [ ! -s "$FNOX_TEST_LOG" ]

      echo "a secret fnox cannot provide yields no credential and a message"
      res="$(fill ${helperMissing} 'protocol=https\nhost=github.com\n\n')"
      if echo "$res" | grep -q '^password='; then echo "credential despite missing secret"; exit 1; fi
      grep -q 'no NOT_STORED from fnox' "$PWD/err"

      echo "a secret name or host with shell syntax is never executed"
      fill ${helperOddSecret} 'protocol=https\nhost=github.com\n\n' >/dev/null
      grep -qF 'no X$(touch /tmp/fnox-injected-secret) from fnox' "$PWD/err"
      [ ! -e /tmp/fnox-injected-secret ] && [ ! -e /tmp/fnox-injected-host ]

      echo "the helper never reads token files"
      if grep -qE 'github-token|agenix|/run/secrets' ${helper}/bin/git-credential-fnox; then
        echo "helper references a token file"; exit 1
      fi

      touch "$out"
    '';
}
