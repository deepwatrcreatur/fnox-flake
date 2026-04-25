Status: `done`
Suggested branch: `test/fnox-extended-wrapper-seed-tests`
Priority: `medium`

# Extended Wrapper And Seed Tests

## Goal

Add sandbox tests for behavior paths that are exercised in production but not
currently covered by `checks/wrapper-tests.nix`.

## Why

The existing tests prove the happy path and basic error paths for single-secret
wrappers. Real-world usage frequently involves multiple secrets, custom
`extraWrapperScript` code, and edge-case seed file content. These paths are
untested:

- a wrapper that loads two or more secrets — verifies that all are exported and
  that the temp-file reuse pattern is safe across multiple iterations
- a wrapper with `extraWrapperScript` — verifies the extra code runs between
  secret decryption and `exec`
- `seed-skips-already-seeded` currently uses a mock that accepts `set`; it
  should use a mock that fails on `set` to prove `set` is never called when
  a secret is already in the store
- a seed source file containing only whitespace — should be treated as empty
  and skipped (same as the empty-source case)

## Scope

- add tests in `checks/wrapper-tests.nix` for the above scenarios
- update the `seed-skips-already-seeded` test to use a `set`-fails mock so it
  actually proves `set` is not called
- keep fake-fnox helpers minimal and clearly named

## Non-Goals

- testing Home Manager activation end-to-end
- testing edge cases in fnox itself (not our code)

## Validation

- all new and existing checks pass under `nix flake check`
- each test has a comment explaining the invariant it proves
