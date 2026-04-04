# Fnox Agent Prompts

Use one prompt per agent. Each prompt maps to one work-item file in this
folder.

Before using any prompt, read:

- [`START-HERE.md`](./START-HERE.md)

## Prompt 1: Centralize Version And Release Bump Docs

Work on [`01-centralize-version-and-release-bump-docs.md`](./01-centralize-version-and-release-bump-docs.md).

Create a branch named `docs/fnox-release-bump-workflow`.

Task:
- centralize the `fnox` version story
- add a release bump workflow to `README.md`
- make version/hash refreshes easier to follow for maintainers

Deliver:
- branch commit(s)
- short summary of what is now canonical

## Prompt 2: Wrapper Runtime Tests

Work on [`02-wrapper-runtime-tests.md`](./02-wrapper-runtime-tests.md).

Create a branch named `test/fnox-wrapper-runtime-behavior`.

Task:
- add behavior-oriented tests for wrapper success and failure paths
- cover seed fallback behavior without requiring real secrets

Deliver:
- branch commit(s)
- summary of runtime paths covered

## Prompt 3: Default Package Selection Strategy

Work on [`03-default-package-selection-strategy.md`](./03-default-package-selection-strategy.md).

Create a branch named `design/fnox-default-package-strategy`.

Task:
- evaluate whether `packages.default` should stay binary-first
- propose or implement the clearest reproducibility-first strategy

Deliver:
- branch commit(s)
- summary of the chosen default and tradeoffs

## Prompt 4: Home Manager Validation

Work on [`04-home-manager-validation.md`](./04-home-manager-validation.md).

Create a branch named `feat/fnox-home-manager-validation`.

Task:
- add assertions for common misconfiguration cases in the Home Manager module

Deliver:
- branch commit(s)
- list of new validation cases

## Prompt 5: Shell Safety And Portability

Work on [`05-shell-safety-and-portability.md`](./05-shell-safety-and-portability.md).

Create a branch named `fix/fnox-shell-safety`.

Task:
- harden generated scripts against whitespace and temp-file handling pitfalls

Deliver:
- branch commit(s)
- summary of portability improvements

## Prompt 6: Security Model And Ops Docs

Work on [`06-security-model-and-ops-docs.md`](./06-security-model-and-ops-docs.md).

Create a branch named `docs/fnox-security-model`.

Task:
- document operational expectations, precedence rules, and threat model basics

Deliver:
- branch commit(s)
- summary of the clarified security/ops model

## Prompt 7: Example Templates

Work on [`07-example-templates.md`](./07-example-templates.md).

Create a branch named `feat/fnox-example-templates`.

Task:
- add structured examples/templates for common fnox-flake usage

Deliver:
- branch commit(s)
- summary of new example coverage

## Prompt 8: Metadata And Quality Gates

Work on [`08-metadata-and-quality-gates.md`](./08-metadata-and-quality-gates.md).

Create a branch named `chore/fnox-quality-gates`.

Task:
- improve metadata and add lightweight lint/format quality gates

Deliver:
- branch commit(s)
- summary of new quality gates

## Prompt 9: Flake Complexity Cleanup

Work on [`09-flake-complexity-cleanup.md`](./09-flake-complexity-cleanup.md).

Create a branch named `refactor/fnox-flake-cleanup`.

Task:
- remove minor flake complexity and unused bindings without changing behavior

Deliver:
- branch commit(s)
- summary of simplifications made

## Prompt 15: Shellcheck Generated Scripts

Work on [`15-shellcheck-generated-scripts.md`](./15-shellcheck-generated-scripts.md).

Create a branch named `chore/fnox-shellcheck`.

Task:
- add shellcheck to `devShells.default`
- add one or more `nix flake check` entries that run shellcheck on
  representative generated wrapper/seed scripts
- fix any shellcheck findings in `lib/default.nix`

Deliver:
- branch commit(s)
- list of findings fixed and the check that now enforces shellcheck going forward

## Prompt 16: Extended Wrapper And Seed Tests

Work on [`16-extended-wrapper-and-seed-tests.md`](./16-extended-wrapper-and-seed-tests.md).

Create a branch named `test/fnox-extended-wrapper-seed-tests`.

Task:
- add a test for a wrapper that loads multiple secrets simultaneously
- add a test that verifies `extraWrapperScript` runs before `exec`
- update `seed-skips-already-seeded` to use a `set`-fails mock so it proves
  `set` is never called when a secret is already seeded
- add a test for a whitespace-only seed source file (should be skipped)

Deliver:
- branch commit(s)
- summary of new invariants proven by the added tests

## Prompt 17: Home Manager Module Usability

Work on [`17-home-manager-module-usability.md`](./17-home-manager-module-usability.md).

Create a branch named `feat/fnox-hm-module-usability`.

Task:
- default `fnoxPath` to `config.envVar` in the `secrets` submodule so users
  don't need to repeat themselves when the two values are the same
- improve all three existing assertion messages to include the field name and
  a one-line fix hint

Deliver:
- branch commit(s)
- before/after examples showing the simplified module syntax

## Prompt 18: Troubleshooting Guide

Work on [`18-troubleshooting-guide.md`](./18-troubleshooting-guide.md).

Create a branch named `docs/fnox-troubleshooting`.

Task:
- write `docs/troubleshooting.md` covering the failure modes listed in the
  work-item file
- add a link to it from `README.md`

Deliver:
- branch commit(s)
- list of failure modes documented
