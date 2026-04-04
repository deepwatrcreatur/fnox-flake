# fnox-flake Security and Operations Notes

This document covers threat model assumptions, secret value handling behaviour,
and operational expectations for fnox-flake. Read this if you are deciding
whether fnox-flake fits your security posture or if you are debugging unexpected
behaviour with secret values.

## Trust Model

| Asset | Role | Risk if compromised |
|-------|------|---------------------|
| Age private key (`FNOX_AGE_KEY_FILE`) | Root of trust — decrypts all fnox secrets | All secrets become readable without fnox |
| fnox config (`FNOX_CONFIG`) | Lists age recipients; controls who can encrypt | Attacker could add their own recipient and re-encrypt |
| fnox data store | Encrypted secret ciphertexts | Encrypted; no risk without the private key |
| Source files (`seedSecretSources`) | Plaintext seeds used during activation | Plaintext exposure; restrict permissions to 0600 |

`fnox-flake` assumes:

- The local filesystem is controlled by the user. The age private key is only
  as safe as the file system that holds it.
- Processes running as the same user (or root) can inspect environment variables
  of the wrapper-launched process via `/proc/<pid>/environ`. This is the same
  threat model as any program that uses environment variables for secrets.
- The machine is not shared with untrusted local users who could enumerate
  processes.

## Secret Value Handling

### Trailing newlines

Shell command substitution (`$(...)`) strips trailing newlines. Both the seed
script and the wrapper use command substitution to read values:

```bash
# seed script
value="$(cat "$file" 2>/dev/null || true)"

# wrapper
value=$("$FNOX_BIN" ... get "$path")
```

As a result, **values stored in fnox and exported to the environment never have
a trailing newline**, regardless of whether the source file has one. Most
consumers (API clients, tokens, etc.) expect this. If a value must preserve a
trailing newline, store and read it outside fnox.

### Environment variable exposure

Wrapper scripts decrypt secrets and export them into the wrapped command's
environment using `export VAR="$value"`. The values are:

- Visible to the wrapped process and any child it spawns.
- Visible to processes that can read `/proc/<pid>/environ` (same-user or root).
- **Not** visible to the parent shell that invoked the wrapper. The wrapper
  uses `exec` as its final step, which replaces the wrapper process rather than
  returning to the parent.
- **Not** recorded in interactive shell history because the decryption happens
  inside a generated script, not at an interactive prompt.

### Process argument exposure during seeding

The seed script calls `fnox set "$name" "$value"` with the secret value as a
process argument. Process arguments are briefly visible in `/proc/<pid>/cmdline`
and in tools like `ps`. This exposure is short-lived (the duration of the
`fnox set` call) and occurs only during Home Manager activation, not on every
login. If your threat model requires zero process-argument exposure, seed
secrets out-of-band using `fnox set` directly rather than relying on
`seedSecretSources`.

## Seed Operation Precedence

When `seedSecretSources` is configured, the seed script runs once per
`home-manager switch`. Precedence rules:

1. **Existing fnox value wins.** If `fnox get <name>` succeeds, the secret is
   already in the store and the seed script moves on without overwriting it.
   Seeding is intentionally idempotent.

2. **First readable, non-empty source file wins.** Sources are tried in the
   order listed. As soon as one source is read and `fnox set` succeeds, the
   remaining sources for that secret are skipped.

3. **Errors from `fnox set` are fatal.** If `fnox set` returns non-zero (e.g.
   age encryption fails because no recipients are configured), the activation
   script exits immediately rather than continuing with a partially seeded
   state.

4. **Unreadable or empty sources are skipped silently.** A missing file, an
   empty file, or a file whose read permission is denied is treated as "not
   available" and the next source is tried. No error is printed; only a warning
   is logged for unreadable files.

5. **Multiline sources are skipped with a warning.** If a source file contains
   more than one line, the seed script emits a warning and tries the next
   source. Real tokens and API keys are always single-line; a file with
   multiple lines almost certainly contains an error message (e.g. a SOPS or
   decrypt failure) rather than a usable secret. Seeding a junk value into
   fnox would silently break every wrapped command that depends on it — the
   multiline check catches this before `fnox set` is ever called.

### Handling corrupted token files

Some systems produce token files that contain error messages rather than
tokens. A common example is a file written by a failed SOPS decryption:

```
Error: SOPS decryption failed
could not find a valid key
```

If such a file exists at a `seedSecretSources` path, the seed script will:

1. Skip it (because the content is multiline) and log a warning.
2. Try any remaining sources for the same secret.
3. Leave the secret unseeded if no valid source is found.

The wrapped command will then fail at runtime when it attempts `fnox get`.
This is the correct behaviour: a junk value in fnox would silently break all
downstream consumers, while an unseeded value produces a clear error at the
point of use.

To recover, fix or remove the corrupted file and re-run `home-manager switch`.

## Minimal-Environment Assumptions

The generated scripts make these assumptions about the runtime environment:

- `mktemp` is available (for the wrapper's stderr temp file).
- `$HOME` is set (used to derive default paths for `FNOX_CONFIG` and
  `FNOX_AGE_KEY_FILE` when those variables are not already set).
- Both defaults can be overridden by setting `FNOX_CONFIG` and
  `FNOX_AGE_KEY_FILE` before invoking the wrapper or seed script.

The seed script exits 0 early (with a warning) if the fnox binary is not
found at `$FNOX_BIN`. This makes the activation script safe to run on machines
where fnox is not yet installed.
