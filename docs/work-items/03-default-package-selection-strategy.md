Status: `done`
Suggested branch: `design/fnox-default-package-strategy`
Priority: `high`

# Default Package Selection Strategy

## Goal

Revisit whether `packages.default` should prefer binaries or source builds.

## Tasks

- document current behavior and its tradeoffs
- decide whether to keep binary-first, switch to source-first, or make it
  configurable

## Validation

- chosen strategy is explicit in docs and flake outputs
