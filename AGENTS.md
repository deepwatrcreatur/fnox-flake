# Notes for coding agents and contributors

Packages [fnox](https://github.com/jdx/fnox) from source, exports wrapper
helpers for secret-backed CLI commands, and provides a Home Manager module.

- Outputs: `packages` (`default`, `fnox`), `lib` (wrapper helpers),
  `overlays.default`, `homeManagerModules.default`, `apps`, `checks`.
- Validate: `nix flake check` (includes `checks/wrapper-tests.nix`), then
  `nix build .#fnox`, then run `result/bin/fnox`.
- Rust package: when bumping `version`, update both the source `hash` and
  `cargoHash`.
- Security model for wrappers: `docs/security.md`. Planned work:
  `docs/work-items/`.
- Published to FlakeHub by `.github/workflows/flakehub-publish.yml`.

<!-- nix-agent-guides:core BEGIN (v2). Synced from deepwatrcreatur/nix-agent-guides templates/agents-core.md by scripts/sync-agents-core.sh. Edit it there, not here. -->
## Shared conventions

Canonical, newest version:
https://raw.githubusercontent.com/deepwatrcreatur/nix-agent-guides/main/CONVENTIONS.md
If you can fetch it, read it before larger changes; where it differs from the
summary below, it is newer. This repo's own instructions above take
precedence over both.

Summary (offline fallback):

- **Comments explain why, not what.** Mark them `# WHY:`, `# GOTCHA:`,
  `# INVARIANT:`, `# SECURITY:`, `# UPSTREAM:` or `# TODO(#issue):`. One to
  three lines above the code they protect; longer reasoning goes in `docs/`
  with a pointer (`# WHY: docs/x.md#heading`). Never narrate the next line.
- **Before editing a file**, read its tags:
  `rg -n '# (WHY|GOTCHA|INVARIANT|SECURITY|UPSTREAM|TODO)' <file>`.
  Fix or delete any tag your change makes untrue.
- **Exported Nix functions** get RFC 145 doc comments (`/** ... */`).
- **Validate before committing:** the narrowest `nix build` first, then
  `nix flake check`; read all output. Run `bash -n`/`shellcheck` on shell
  generated from Nix. Exit code 0 is not proof the change worked.
- **Same change, same PR:** behaviour changes come with docs and a check.
- **Never commit secrets**, and do not deploy to or change live hosts unless
  asked.
<!-- nix-agent-guides:core END -->
