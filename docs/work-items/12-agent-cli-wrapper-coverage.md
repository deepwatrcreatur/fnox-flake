# 12 Agent CLI Wrapper Coverage

Status: `ready`

Suggested branch: `feat/fnox-agent-cli-wrappers`

## Goal

Add or document first-class `fnox` wrapper support for the agent CLIs that are
natural fits for secret injection.

## Why

Downstream repos want to stop exporting API keys globally and rely more on
wrapped commands. The highest-value next targets are the agent CLIs that
regularly need token injection:

- `opencode`
- `claude-code`
- `gemini-cli`
- `droid`

Today the downstream policy is ahead of the reusable `fnox` support surface.

## Scope

- audit whether each target CLI already has enough stable invocation shape to
  justify a wrapper
- add wrapper support for the commands that clearly benefit from `fnox`
- keep unfree-backed wrappers opt-in so default CI does not fail on package
  policy
- document any commands intentionally deferred because their CLI surface is too
  unstable or their auth model does not fit the current wrapper pattern
- keep wrapper names and env-var behavior predictable for downstream repos

## Non-Goals

- wrapping generic build tools
- forcing every AI-related command into `fnox`
- downstream alias rollout in this PR

## Validation

- wrapped commands evaluate cleanly
- wrapper behavior is documented clearly enough for downstream repos to adopt
- deferred commands have explicit reasons, not silent omission
