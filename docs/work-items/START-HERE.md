# Agent Start Here

If you are a coding agent starting work in this repo, follow this file.

## Objective

Pick the next highest-value work item that is not already in progress, do it in
its own branch, and keep the work scoped to one PR.

## Where The Queue Lives

Read first:

- [`README.md`](./README.md)
- [`agent-prompts.md`](./agent-prompts.md)

The authoritative queue is the ordered list in [`README.md`](./README.md).

## How To Choose Work

0. Refresh remote state first: `git fetch origin`
1. Start with the ordered list in [`README.md`](./README.md).
2. Find the first item whose header says `Status: \`ready\``.
3. If the suggested branch/worktree exists, treat that only as a hint.
4. Once you take an item:
   - create or switch to the suggested branch
   - update that work-item file header from `ready` to `in-progress`
   - commit and push that claim promptly

## PR Workflow

1. implement and validate locally
2. push the branch and open a PR
3. wait briefly for CI and bot review
4. read comments and checks
5. fix substantive issues
6. merge after checks are green or remaining comments are intentionally
   non-blocking

## Completion Rules

When your PR merges:

- update the work-item file to `done` or delete it if fully complete
- if your work changes the plan materially, update the relevant work-item file
  and add a new numbered item if needed

## Invariants

- keep tasks PR-sized
- do not mix unrelated packaging, module, and docs changes into one PR unless
  the work-item explicitly says to
- prefer adding tests/checks when fixing behavior
