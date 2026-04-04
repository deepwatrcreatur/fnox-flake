# 13 API And Proxmox Helper Wrappers

Status: `done`

Suggested branch: `feat/fnox-api-proxmox-helpers`

## Goal

Decide whether `fnox-flake` should expose reusable wrappers for tokenized API
calls and Proxmox helper commands, and implement only the helpers that are
clearly worth standardizing.

## Why

Downstream repos already want:

- a safe API helper path without overriding raw `curl`
- a stable place for Proxmox-token-backed commands if repeated usage patterns
  exist

That decision belongs in `fnox-flake` if the wrappers are going to be reused,
rather than being reinvented in each consumer repo.

## Scope

- evaluate a dedicated API helper wrapper such as `xh-api` or `curl-api`
- evaluate whether a Proxmox helper wrapper belongs here or should stay
  repo-local until command usage stabilizes
- keep the scope narrow: add helpers only when the secret source and intended
  command shape are unambiguous
- document the support boundary for downstream consumers

## Non-Goals

- replacing raw `curl`
- wrapping every command that can take an auth header
- encoding one repo’s private Proxmox workflow as a generic default

## Validation

- any added helper wrappers evaluate cleanly
- docs make it obvious when a downstream repo should reuse a helper versus
  define a repo-local wrapper
- deferred helpers have explicit rationale
