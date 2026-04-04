# Wrapper-First Token Migration

This document explains how to migrate from ambient shell token exports (e.g.
`export GITHUB_TOKEN=...` in your shell profile) to the wrapper-first model
where tokens are injected by fnox-backed wrapper commands at the point of use.

## The problem with ambient exports

A typical shell profile might contain:

```bash
export GITHUB_TOKEN="$(cat ~/.config/git/github-token)"
export ANTHROPIC_API_KEY="$(cat ~/.local/share/secrets/anthropic)"
```

This has several drawbacks:

- **Tokens are live in every process** that descends from your login shell,
  including text editors, test runners, and arbitrary scripts. Any process can
  read them from `/proc/<pid>/environ`.
- **Stale or missing files silently produce empty variables.** A failed
  decryption writes an error message into the token file; the shell reads it
  and exports junk. Downstream tools fail with confusing errors.
- **Rotation requires a new login session** — the shell reads the file once at
  startup, so a rotated token is invisible until you restart your shell.

## The wrapper-first end state

In the wrapper-first model:

- Tokens are stored encrypted in fnox.
- Wrapped commands (`gh-fnox`, `bw-fnox`, `opencode-zai`, etc.) decrypt and
  export the token immediately before `exec`-ing the real binary.
- The token is never in the environment of the parent shell or any other
  process — only the wrapped command and its children see it.
- Your shell profile exports nothing.

```bash
# Before (ambient)
export GITHUB_TOKEN="$(cat ~/.config/git/github-token)"
gh pr list   # any process can read GITHUB_TOKEN from this shell

# After (wrapper-first)
gh-fnox pr list   # GITHUB_TOKEN exists only inside gh-fnox's process tree
```

## Prerequisites before removing ambient exports

Work through this checklist before removing any `export` lines from your
shell profile:

1. **fnox is seeded.** Run `fnox get GITHUB_TOKEN` (or the relevant key) and
   confirm it returns the correct token, not an error.

2. **The wrapped command works end-to-end.** Run `gh-fnox repo list` (or
   equivalent) and confirm it authenticates successfully.

3. **Token files are healthy.** If you use `seedSecretSources`, confirm each
   source file contains a single-line token, not an error message. See
   [Handling corrupted token files](security.md#handling-corrupted-token-files).

4. **All callers are using the wrapped command.** Search your scripts,
   Makefiles, CI configs, and shell aliases for direct invocations of `gh`,
   `bw`, `opencode`, etc. and update them to use the wrapper.

5. **Fallback paths are understood.** Decide what happens if fnox is
   unavailable (e.g. the age key file is missing). The wrappers exit non-zero
   with a clear error — make sure that is acceptable for your workflows.

## Migration steps

### Step 1 — Seed secrets into fnox

If you have not already run `home-manager switch` with `seedSecretSources`
configured, seed secrets manually:

```bash
fnox set GITHUB_TOKEN "$(cat ~/.config/git/github-token)"
fnox set ANTHROPIC_API_KEY "$(cat ~/.local/share/secrets/anthropic)"
```

Verify with:

```bash
fnox get GITHUB_TOKEN
fnox get ANTHROPIC_API_KEY
```

### Step 2 — Test the wrapped commands

Run each wrapped command that you intend to rely on and confirm it works:

```bash
gh-fnox repo list
bw-fnox list items --search example 2>/dev/null | head -5
```

### Step 3 — Remove ambient exports one at a time

Comment out each `export` in your shell profile, reload your shell, and
retest. Remove one at a time so regressions are easy to attribute:

```bash
# ~/.config/fish/config.fish  or  ~/.bashrc  etc.

# Remove or comment out:
# export GITHUB_TOKEN="$(cat ~/.config/git/github-token)"

# Reload and test:
# gh-fnox repo list
```

### Step 4 — Update aliases and scripts

Replace direct tool invocations with their wrapped equivalents:

| Before | After |
|--------|-------|
| `gh pr list` | `gh-fnox pr list` |
| `bw list items` | `bw-fnox list items` |
| `opencode` | `opencode-zai` |

### Step 5 — Optionally clean up token files

Once fnox is the sole source of truth, the plaintext seed files are no
longer needed. You may delete them or leave them in place as backup seeds.
If you leave them, ensure they are mode `0600` and still contain a valid
single-line token (not an error message).

## Which commands are good wrapper candidates

| Command | Good candidate? | Notes |
|---------|----------------|-------|
| `gh` | Yes | Single token (`GITHUB_TOKEN`/`GH_TOKEN`); `gh-fnox` is built-in |
| `bw` (Bitwarden CLI) | Yes | Session token (`BW_SESSION`); `bw-fnox` is built-in |
| `opencode` | Yes | Provider API key; `opencode-zai` is built-in |
| `claude` (Claude Code CLI) | Yes | `ANTHROPIC_API_KEY`; `claude-fnox` is built-in |
| `gemini` (Gemini CLI) | Yes | `GEMINI_API_KEY`; `gemini-fnox` is built-in |
| `curl` / `xh` / `httpie` | Repo-local | Invocation shape and required key vary per repo — use `mkWrappedCommand` rather than a shared default; see below |
| Proxmox CLIs (`pvesh`, `qm`, `pveam`) | Repo-local | `PROXMOX_API_TOKEN` is in `defaultSecretDefinitions` but command patterns are host-specific — define locally with `mkWrappedCommand` |
| `git` (credential helper) | Indirect | Use `gh-fnox` as the credential helper: `git config credential.helper 'gh-fnox auth git-credential'` |
| `ssh` | No | Key agent handles authentication; no env var secret needed |
| `nix` / `nixos-rebuild` | No | Does not read secrets from the environment |
| Scripts that call multiple tools | Case-by-case | Wrap at the outermost entry point, not each inner tool call |

### Why curl/xh and Proxmox are repo-local

**curl / xh / httpie** — The secret to inject depends entirely on which API
the command is calling. A generic `curl-api` wrapper would need to hardcode
one key, which is too prescriptive. Use `mkWrappedCommand` in your flake and
inject the specific key your repo needs. The
[`examples/custom-wrapped-command.nix`](../examples/custom-wrapped-command.nix)
file demonstrates exactly this pattern with curl.

**Proxmox CLIs** — `PROXMOX_API_TOKEN` is declared in `defaultSecretDefinitions`
so it participates in config generation and seeding. However, Proxmox
invocation patterns (`pvesh`, `qm create`, `pveam update`, etc.) are too
host-specific to be useful as a shared default. If your Proxmox workflows are
stable and repeated across machines, define a repo-local `mkWrappedCommand`
wrapper and consider contributing it upstream when the pattern solidifies.

## Wrapping a custom command

For a tool not covered by the built-in wrappers, use `mkWrappedCommand`
from `fnoxLib`. See [`examples/custom-wrapped-command.nix`](../examples/custom-wrapped-command.nix)
for a complete example.

The pattern:

```nix
packages.curl-with-api-key = fnoxLib.mkWrappedCommand {
  name = "curl-with-api-key";
  command = pkgs.curl;
  binaryName = "curl";
  inherit fnoxPackage;
  secrets = [
    (fnoxLib.mkSecretSpec {
      envVar = "MY_API_KEY";
      fnoxPath = "MY_API_KEY";
    })
  ];
};
```

## Shell aliases during the transition

If you want `gh` to transparently call `gh-fnox` during migration without
updating every script, add a shell alias:

```bash
# Fish
alias gh gh-fnox

# Bash / Zsh
alias gh=gh-fnox
```

Remove the alias once all direct invocations are updated. Aliases hide the
migration progress — prefer updating callers explicitly.

## Rollback

If something breaks, re-add the ambient export to your shell profile. The
wrapped commands do not interfere with ambient environment variables — if
`GITHUB_TOKEN` is already set in the environment, `gh` will use it and the
wrapper's decryption is redundant but harmless.
