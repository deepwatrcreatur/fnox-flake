Status: `done`
Suggested branch: `docs/fnox-troubleshooting`
Priority: `low`

# Troubleshooting Guide

## Goal

Add a `docs/troubleshooting.md` that maps common runtime errors to their
causes and recovery steps.

## Why

The docs cover the trust model (`security.md`) and migration path
(`wrapper-first-migration.md`) but there is no user-facing troubleshooting
reference. Users debugging failures today must read the implementation or ask
for help. The most common failure modes are:

- "fnox binary not found at $FNOX_BIN" — age key or config not yet created
- "failed to decrypt ... for ..." — wrong key file, unreadable key, or the
  secret was never seeded
- "secret not found" from fnox — unseeded or config points to the wrong store
- wrapped command exits with "Error: ..." before the real binary runs — config
  path is wrong or key file is missing
- seed script exits 0 but secret still not available — multiline source file
  was skipped silently, or all sources were missing
- Home Manager assertion fires at eval time — missing recipients, duplicate
  envVar, or fnoxPath not declared

## Scope

- create `docs/troubleshooting.md` with one section per failure mode
- each section: symptom, likely cause(s), diagnostic commands, fix
- cross-reference `docs/security.md` for trust-model context
- add a link from the README

## Non-Goals

- documenting fnox itself (link to upstream docs instead)
- replacing the security model or migration docs

## Validation

- all failure modes listed in the Why section are covered
- each diagnostic command can be run by a user without root access
- README links to the new doc
