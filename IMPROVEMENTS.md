# Repository Improvement Suggestions

## High impact

1. **Pin and expose the `fnox` version in one place with update workflow docs.**
   - The version and hashes are currently spread across `flake.nix`,
     `pkgs/fnox-binary.nix`, and `pkgs/fnox-source.nix`.
   - Add a short "release bump" section in `README.md` with exact commands
     (update version, refresh source hash, refresh per-platform binary hashes,
     run checks).

2. **Add wrapper behavior tests for error paths.**
   - Existing checks verify that generated scripts contain key strings, but do
     not exercise runtime behavior.
   - Add Nix checks (or shell tests) that validate:
     - wrapper exits non-zero when `fnox get` fails,
     - wrapper exports expected vars for success path,
     - seed script skips unreadable/empty files and continues to fallbacks.

3. **Offer a reproducibility-first default package selection strategy.**
   - `packages.default` currently prefers prebuilt binaries when available.
   - Consider switching default to source builds (or making this configurable)
     and exposing binary as an explicit opt-in package for speed-sensitive
     users.

## Medium impact

4. **Strengthen Home Manager module validation.**
   - Add assertions for common misconfiguration cases:
     - empty `recipients` when writing an age provider config,
     - duplicate `envVar` entries in a wrapped command,
     - secret definitions missing required fields in user overrides.

5. **Improve shell safety and portability in generated scripts.**
   - Use safer iteration for seed sources to avoid subtle word-splitting issues
     if paths contain whitespace.
   - Consider `mktemp` fallback guidance for minimal environments and add
     explicit cleanup traps for temp files in wrappers.

6. **Document operational expectations and security model.**
   - Clarify whether seeded values are expected to include trailing newlines.
   - Document secret precedence when both existing fnox values and seed sources
     are present.
   - Add a short section describing threat model assumptions (local key file
     protection, process environment exposure, shell history practices).

## Nice to have

7. **Expose structured examples as templates.**
   - Add `examples/` with a minimal Home Manager config and a custom wrapped
     command.
   - This reduces copy/paste from README and makes validation easier in CI.

8. **Expand metadata and quality gates.**
   - Add maintainers to `meta` fields.
   - Add a formatter/lint target (e.g., `nix fmt` + `statix`/`deadnix`) and run
     via `nix flake check`.

9. **Reduce minor flake complexity.**
   - Remove unused helper bindings and keep the system iteration strategy
     consistent (currently both `supportedSystems` and
     `flake-utils.eachDefaultSystem` are present).
