# 10 Bad Secret File Handling

Status: `done`

Suggested branch: `fix/fnox-bad-secret-file-handling`

## Goal

Make `fnox`-style wrapper usage safer when a seed source file exists but does
not contain a valid secret, such as when a failed decrypt writes an error
message into a token file.

## Why

- Some hosts currently end up with files like `~/.config/git/github-token`
  containing a SOPS failure message instead of a real token.
- Wrapper and shell-injection flows then consume that bogus content as if it
  were a secret.
- `fnox-flake` is the right place to define what “good enough to seed” means for
  token-backed command wrappers.

## Scope

- document the failure mode in repo docs
- add tests for wrapper behavior when a seed file exists but contains junk or
  multiline error output
- decide whether wrappers should:
  - reject obviously invalid values,
  - skip them and continue to later seed sources,
  - or surface a clearer failure
- keep the behavior deterministic and documented

## Validation

- tests cover bad token file contents and fallback behavior
- resulting behavior is explicit in docs, not inferred from implementation
