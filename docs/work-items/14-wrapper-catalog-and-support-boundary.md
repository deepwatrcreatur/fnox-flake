# 14 Wrapper Catalog And Support Boundary

Status: `done`

Suggested branch: `docs/fnox-wrapper-catalog`

## Goal

Publish a concise wrapper catalog for `fnox-flake` so downstream repos know
which wrapped commands are supported, which are intentionally out of scope, and
which are still provisional.

## Why

The current wrapper story is split across code, tests, and downstream queue
items. That makes it harder to tell:

- which wrappers are part of the supported reusable surface
- which commands should stay repo-local
- which wrappers are safe to adopt under canonical names

As wrapper coverage grows, `fnox-flake` needs a small, explicit support
boundary.

## Scope

- document the currently supported wrappers and their intended secret sources
- note which command categories are intentionally out of scope
- distinguish stable reusable wrappers from experimental or downstream-specific
  patterns
- add short downstream guidance for canonical-name adoption and fallback

## Non-Goals

- implementing every missing wrapper in this PR
- broad security-model docs that belong elsewhere
- replacing runtime tests with prose

## Validation

- downstream repos can decide whether to adopt a wrapper without inspecting the
  full implementation
- the supported wrapper surface is documented in one place
- wrapper-first migration tasks can refer to this catalog directly
