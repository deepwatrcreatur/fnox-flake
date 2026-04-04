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
