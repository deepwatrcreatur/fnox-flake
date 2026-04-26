# 12 Agent CLI Wrapper Coverage

Status: `done`

Suggested branch: `feat/fnox-agent-cli-wrappers`

## Progress

- **gh-fnox**: Wraps GitHub CLI with `GITHUB_TOKEN` and `GH_TOKEN`.
- **bw-fnox**: Wraps Bitwarden CLI with `BW_SESSION`.
- **claude-fnox**: Wraps Claude Code with `ANTHROPIC_API_KEY` (gated on `allowUnfree`).
- **gemini-fnox**: Wraps Gemini CLI with `GEMINI_API_KEY`.
- **droid-fnox**: Wraps Factory.ai `droid` CLI with `FACTORY_API_KEY`.
- **opencode-zai**: Wraps `opencode` with `Z_AI_API_KEY` (aliased to `OPENAI_API_KEY`) and pre-configures z.ai provider/model.

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
