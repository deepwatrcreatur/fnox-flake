# Troubleshooting Guide

This guide helps you identify and resolve common runtime errors encountered when
using `fnox-flake` wrappers and seed scripts.

## Common Failure Modes

### 1. "fnox binary not found at /nix/store/.../bin/fnox"

*   **Symptom:** The wrapped command or Home Manager activation fails with a
    warning about a missing fnox binary.
*   **Likely Cause:** The fnox package was not successfully built or linked.
*   **Diagnostic:**
    ```bash
    nix build .#fnox --print-out-paths
    ls -l $(nix build .#fnox --no-link --print-out-paths)/bin/fnox
    ```
*   **Fix:** Ensure the `fnox` overlay is applied or that `programs.fnox.package`
    is explicitly set to a valid package. Re-run `home-manager switch`.

### 2. "failed to decrypt ... for ..."

*   **Symptom:** The wrapped command exits with a decryption error from fnox.
*   **Likely Cause:** 
    - The age private key file is missing or unreadable.
    - The private key does not match any of the recipients in the fnox config.
    - The secret was never successfully seeded into the current data store.
*   **Diagnostic:**
    ```bash
    # Check key file visibility
    ls -l "$FNOX_AGE_KEY_FILE"
    
    # Try to get the secret manually with verbose output
    fnox -v get <SECRET_NAME>
    ```
*   **Fix:**
    - Ensure your age key exists at `~/.config/sops/age/keys.txt` (or the path
      set in `programs.fnox.ageKeyFile`).
    - Verify that your public key is in `programs.fnox.recipients`.
    - If the secret is missing, re-run `home-manager switch` or seed it manually
      with `fnox set`.

### 3. "secret not found"

*   **Symptom:** Fnox reports that the secret key does not exist.
*   **Likely Cause:**
    - The secret was never seeded.
    - The configuration points to a different data store than intended.
*   **Diagnostic:**
    ```bash
    fnox list
    ```
*   **Fix:** Seed the secret into fnox using `seedSecretSources` during Home
    Manager activation or via `fnox set`.

### 4. Wrapped command exits with error before the real binary runs

*   **Symptom:** The command prints an error and exits immediately without
    starting the underlying program.
*   **Likely Cause:** The wrapper script encountered a fatal error during
    decryption (e.g. missing config or key file).
*   **Diagnostic:**
    ```bash
    # Run with bash -x to see where it fails
    bash -x $(which <command>-fnox)
    ```
*   **Fix:** Follow the fixes for "failed to decrypt" above.

### 5. Seed script exits 0 but secret is still not available

*   **Symptom:** Home Manager activation finishes successfully, but `fnox get`
    still fails.
*   **Likely Cause:**
    - All seed source files were missing, empty, or contained multiline junk
      (error messages) and were skipped.
    - The fnox binary was missing during activation (emits a warning, not an error).
*   **Diagnostic:**
    - Check the Home Manager activation logs for "Warning: fnox seed source ...
      contains multiple lines; skipping".
*   **Fix:** Ensure your seed source files contain valid, single-line tokens.
    See [Handling corrupted token files](security.md#handling-corrupted-token-files).

### 6. Home Manager assertion fires at evaluation time

*   **Symptom:** `nix build` or `home-manager switch` fails with an evaluation
    error message starting with `assertion failed`.
*   **Likely Cause:**
    - `programs.fnox.recipients` is empty.
    - A wrapped command has duplicate `envVar` names.
    - A `fnoxPath` is referenced but not declared in `secretDefinitions`.
*   **Fix:** Read the error message carefully; it now contains the specific
    field name and a hint for the fix. Update your Home Manager configuration
    accordingly.

## Security Context

For a deeper understanding of the assumptions and trust model behind these
behaviours, see [Security and Operations Notes](security.md).
