# 11 Wrapper First Token Migration

Status: `done`

Suggested branch: `docs/fnox-wrapper-first-migration`

## Goal

Document and support the migration pattern where hosts stop exporting
`GITHUB_TOKEN` globally and instead rely on wrapped commands for token
injection.

## Why

- Downstream repos are already using `gh-fnox`, `bw-fnox`, and related wrapped
  commands, but many shells still export `GITHUB_TOKEN` globally.
- That leaves operators in a mixed state where wrappers exist but are not the
  real trust boundary.
- `fnox-flake` should explain the intended end state and the preconditions for
  removing ambient shell exports.

## Scope

- document the wrapper-first migration path for downstream repos
- spell out prerequisites:
  - wrapped commands exist for the important tools
  - token files are healthy
  - fallback paths are understood
- note which commands are good wrapper candidates and which should stay
  unwrapped
- add concise examples showing wrapper-first usage for GitHub-backed CLIs

## Validation

- docs are specific enough that downstream repos can adopt the pattern without
  improvising the security model
- examples stay aligned with the actual wrapped commands exported by the flake
