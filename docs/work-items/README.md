# Fnox Work Items

Start here if you are assigning another agent:

- [`START-HERE.md`](./START-HERE.md)

This folder is the agent-facing queue for `fnox-flake`.

## How To Use

- Treat each file in this folder as one PR-sized work stream.
- Prefer one agent per file/branch.
- Mark the file as `in-progress` in its header once an agent starts it.
- When work is fully merged, either delete the file or keep it briefly as
  `done` if it records useful outcome notes.
- `done` items must not remain in the active ranking; archive or delete them
  once their notes are no longer useful.
- If the work changes shape materially, update the file instead of letting the
  plan drift only in chat or PR comments.

## Status Model

- `blocked`: do not start yet
- `ready`: can be started now
- `in-progress`: owned by an active branch / agent
- `done`: merged; may remain briefly for outcome notes, but should be archived
  or deleted and removed from the active ranking

## Recommended Process

1. Keep this folder in git as the agent-facing source of truth.
2. Use GitHub issues only for discussion-heavy or multi-PR work.
3. For narrow implementation tasks, the file in this folder is enough and is
   easier for agents to consume than issue threads.
4. For autonomous agent selection, use the rules in
   [`START-HERE.md`](./START-HERE.md).

## Ranking

Highest value first:

1. `12-agent-cli-wrapper-coverage.md`
2. `13-api-and-proxmox-helper-wrappers.md`
3. `14-wrapper-catalog-and-support-boundary.md`
4. `15-shellcheck-generated-scripts.md`
5. `16-extended-wrapper-and-seed-tests.md`
6. `17-home-manager-module-usability.md`
7. `18-troubleshooting-guide.md`

## Source

The seed roadmap for this queue comes from [`IMPROVEMENTS.md`](../../IMPROVEMENTS.md).
