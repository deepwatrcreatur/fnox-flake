# fnox-flake Wrapper Catalog

This document is the authoritative reference for which wrapper commands are
provided by `fnox-flake`, what secrets they inject, and which patterns are
intentionally left to downstream repos.

Read [`docs/wrapper-first-migration.md`](./wrapper-first-migration.md) for
migration guidance and [`docs/security.md`](./security.md) for the trust
model.

---

## Built-in Wrappers

These wrappers are produced by `defaultWrappedCommandSpecs` and appear in
`packages` and `apps` automatically when the underlying package is present in
`nixpkgs`. They are the supported reusable surface of `fnox-flake`.

### `gh-fnox`

| Field | Value |
|-------|-------|
| Wraps | `pkgs.gh` (GitHub CLI) |
| Binary | `gh` |
| Secrets injected | `GITHUB_TOKEN`, `GH_TOKEN` (both from fnox key `GITHUB_TOKEN`) |
| nixpkgs condition | `pkgs ? gh` |

Canonical wrapper for GitHub operations. Injects both `GITHUB_TOKEN` and
`GH_TOKEN` so tools that check either variable work correctly. Use this
instead of exporting `GITHUB_TOKEN` in your shell profile.

```bash
gh-fnox pr list
gh-fnox repo clone owner/repo
```

---

### `bw-fnox`

| Field | Value |
|-------|-------|
| Wraps | `pkgs.bitwarden-cli` |
| Binary | `bw` |
| Secrets injected | `BW_SESSION` |
| nixpkgs condition | `pkgs ? bitwarden-cli` |

Injects an active Bitwarden session key. The session key is short-lived;
re-run `bw unlock` and re-seed `BW_SESSION` when it expires.

```bash
bw-fnox list items --search github
```

---

### `opencode-zai`

| Field | Value |
|-------|-------|
| Wraps | `pkgs.opencode` |
| Binary | `opencode` |
| Secrets injected | `OPENAI_API_KEY` (from fnox key `Z_AI_API_KEY`) |
| Extra env vars set | `OPENCODE_PROVIDER=z.ai`, `OPENCODE_MODEL=GLM 4.7` |
| nixpkgs condition | `pkgs ? opencode` |

Specialized for the Z.AI provider. If you use a different provider, define a
repo-local wrapper with `mkWrappedCommand` rather than overriding this one.

```bash
opencode-zai
```

---

### `claude-fnox`

| Field | Value |
|-------|-------|
| Wraps | `pkgs.claude-code` (Anthropic Claude Code CLI) |
| Binary | `claude` |
| Secrets injected | `ANTHROPIC_API_KEY` |
| nixpkgs condition | `pkgs ? claude-code` |

Injects `ANTHROPIC_API_KEY` for the Anthropic Claude Code CLI. Use this
instead of exporting `ANTHROPIC_API_KEY` globally.

```bash
claude-fnox
```

---

### `gemini-fnox`

| Field | Value |
|-------|-------|
| Wraps | `pkgs.gemini-cli` (Google Gemini CLI) |
| Binary | `gemini` |
| Secrets injected | `GEMINI_API_KEY` |
| nixpkgs condition | `pkgs ? gemini-cli` |

Injects `GEMINI_API_KEY` for the Google Gemini CLI.

```bash
gemini-fnox
```

---

### `droid-fnox`

| Field | Value |
|-------|-------|
| Wraps | `pkgs.factory-droid` (Factory.ai Droid CLI) |
| Binary | `droid` |
| Secrets injected | `FACTORY_API_KEY` |
| nixpkgs condition | `pkgs ? factory-droid` |

Injects `FACTORY_API_KEY` for the Factory.ai Droid CLI.

```bash
droid-fnox
```

---

## Provisional and Experimental Wrappers

None currently. New wrappers start in this section and are promoted to
Built-in once they have been used across more than one downstream repo.

---

## Intentionally Out of Scope

These commands have been evaluated and will not receive built-in wrappers.
Downstream repos should use `mkWrappedCommand` for their own needs.

### curl / xh / httpie

HTTP clients can call any API, and the required secret depends on the
specific endpoint. A shared default would need to hardcode one key, which is
too prescriptive. Use `mkWrappedCommand` in your flake and inject the key
your repo needs. See
[`examples/custom-wrapped-command.nix`](../examples/custom-wrapped-command.nix).

### Proxmox CLIs (`pvesh`, `qm`, `pveam`, etc.)

`PROXMOX_API_TOKEN` is in `defaultSecretDefinitions` for seeding. The token
injection part is solved. The invocation patterns, however, vary too much
between hosts to standardize here. Define a repo-local wrapper when the usage
pattern is stable across enough machines to be worth sharing.

### Additional `opencode` provider variants

The `opencode-zai` wrapper covers the Z.AI provider. Additional providers
should be repo-local until the opencode auth API stabilizes and there is clear
demand for a second built-in variant.

### `ssh`

Authentication is handled by the SSH agent (`ssh-add`). No environment
variable secret injection is needed.

### `nix` / `nixos-rebuild`

Neither reads secrets from the environment in a way that benefits from fnox
injection.

---

## Adding a New Built-in Wrapper

A wrapper belongs in `defaultWrappedCommandSpecs` (and therefore in this
catalog) when:

1. It wraps a command that appears in `nixpkgs` under a stable attribute name.
2. The secret(s) to inject are fixed and unambiguous (not dependent on the
   specific endpoint or host).
3. The wrapper would be reused across more than one downstream repo.
4. The secret name is declared in `defaultSecretDefinitions`.

If all four are true, add the spec to `lib/default.nix` following the
`lib.optionalAttrs (pkgs ? <name>)` pattern, add a `nix flake check` entry in
`flake.nix`, and add a row to this file.

---

## Adopting a Built-in Wrapper Downstream

Canonical wrapper names are stable. Downstream repos can rely on:

```nix
# In your flake outputs (after applying the overlay or using packages directly):
packages.x86_64-linux.gh-fnox     # always wraps pkgs.gh with GITHUB_TOKEN
packages.x86_64-linux.bw-fnox     # always wraps pkgs.bitwarden-cli with BW_SESSION
packages.x86_64-linux.opencode-zai # always wraps pkgs.opencode with Z_AI_API_KEY
packages.x86_64-linux.claude-fnox  # always wraps pkgs.claude-code with ANTHROPIC_API_KEY
packages.x86_64-linux.gemini-fnox  # always wraps pkgs.gemini-cli with GEMINI_API_KEY
packages.x86_64-linux.droid-fnox   # always wraps pkgs.factory-droid with FACTORY_API_KEY
```

The wrapper is absent (not null, absent) if the underlying package is not in
your nixpkgs channel. Guard against this with `pkgs.lib.optionalAttrs` or
check for the package before referencing it.
