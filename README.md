# fnox-flake

`fnox-flake` packages [`fnox`](https://github.com/jdx/fnox), exports wrapper helpers for secret-backed CLI commands, and provides a Home Manager module for declarative integration.

## Outputs

- `packages.<system>.default`, `packages.<system>.fnox`: source-built `fnox` — reproducible, identical on all platforms
- `packages.<system>.fnox-binary`: upstream pre-built binary (x86\_64-linux, aarch64-linux, x86\_64-darwin, aarch64-darwin) — opt-in for faster installs
- `packages.<system>.fnox-from-source`: explicit alias for the source build
- `packages.<system>.gh-fnox`, `bw-fnox`, `opencode-zai`: wrapped commands that load only the secrets they need
- `apps.<system>.*`: `nix run` entrypoints for the packages above
- `lib.<system>`:
  - `mkSecretSpec`
  - `mkWrappedCommand`
  - `mkFnoxConfigToml`
  - `mkSeedSecretsScript`
  - `defaultSecretDefinitions`
  - `defaultWrappedCommandSpecs`
  - `wrappedCommandSpecs`
- `homeManagerModules.default`: reusable Home Manager module
- `overlays.default`: exposes `fnox` in an overlay

## Package Selection Strategy

`packages.default` and `packages.fnox` are always the **source build**. This guarantees bit-for-bit reproducibility regardless of platform and does not depend on upstream publishing a binary release.

Use `packages.fnox-binary` when build time matters and you are on a supported platform (x86\_64-linux, aarch64-linux, x86\_64-darwin, aarch64-darwin):

```nix
environment.systemPackages = [
  fnox.packages.${pkgs.system}.fnox-binary  # pre-built, faster install
];
```

The wrapped commands (`gh-fnox`, `bw-fnox`, `opencode-zai`) always use the source-built `fnox` internally so their behaviour is consistent across machines.

## Package Usage

```nix
{
  inputs.fnox.url = "github:deepwatrcreatur/fnox-flake";

  outputs = { self, nixpkgs, fnox, ... }: {
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          nixpkgs.overlays = [ fnox.overlays.default ];
          environment.systemPackages = [
            pkgs.fnox
            fnox.packages.${pkgs.system}.gh-fnox
          ];
        })
      ];
    };
  };
}
```

## Home Manager Usage

```nix
{
  imports = [ inputs.fnox.homeManagerModules.default ];
  nixpkgs.overlays = [ inputs.fnox.overlays.default ];

  programs.fnox = {
    enable = true;
    recipients = [
      "age1example000000000000000000000000000000000000000000000000000000"
    ];

    seedSecretSources = {
      GITHUB_TOKEN = [
        "$HOME/.config/git/github-token"
        "$HOME/.local/share/agenix-user-secrets/github-token"
      ];
      Z_AI_API_KEY = [
        "$HOME/.local/share/agenix-user-secrets/z-ai-api-key"
      ];
    };
  };
}
```

The module default for `programs.fnox.package` is `pkgs.fnox`, so the overlay is required unless you set `programs.fnox.package` explicitly.

## Version

The canonical `fnox` version is defined in **`flake.nix`** at the top of the `let` block:

```nix
version = "1.19.0";
fnoxSrc = builtins.fetchTarball {
  url = "https://github.com/jdx/fnox/archive/refs/tags/v${version}.tar.gz";
  sha256 = "sha256:...";
};
```

All packages receive `version` as an argument — there is no other place to change the version string.

Three hashes must be updated together whenever the version changes:

| Hash | File | Purpose |
|------|------|---------|
| `fnoxSrc.sha256` | `flake.nix` | Source tarball |
| `cargoHash` | `pkgs/fnox-source.nix` | Cargo dependency lock |
| Per-platform `sha256` | `pkgs/fnox-binary.nix` | Pre-built binaries (4 platforms) |

## Releasing a New fnox Version

When upstream publishes a new release, update in this order:

**1. Bump the version and source hash in `flake.nix`:**

```bash
# Set the new version
NEW_VERSION="1.20.0"   # replace with target version

# Get the new source hash
nix-prefetch-url --unpack \
  "https://github.com/jdx/fnox/archive/refs/tags/v${NEW_VERSION}.tar.gz"
```

Edit `flake.nix`:
- set `version = "${NEW_VERSION}";`
- set `fnoxSrc.sha256` to the hash printed above (use `sha256:` prefix)

**2. Update `cargoHash` in `pkgs/fnox-source.nix`:**

Set `cargoHash` to an empty string first, then let Nix tell you the correct hash:

```bash
# Temporarily set cargoHash = lib.fakeHash; in pkgs/fnox-source.nix, then:
nix build .#fnox-from-source 2>&1 | grep 'got:'
```

Replace `cargoHash` with the `got:` value.

**3. Update binary hashes in `pkgs/fnox-binary.nix`:**

```bash
for platform in x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu \
                x86_64-apple-darwin aarch64-apple-darwin; do
  echo "=== ${platform} ==="
  nix-prefetch-url \
    "https://github.com/jdx/fnox/releases/download/v${NEW_VERSION}/fnox-${platform}.tar.gz"
done
```

Update the four `sha256` entries in `pkgs/fnox-binary.nix`.

**4. Validate:**

```bash
nix flake check
nix flake show
```

**5. Commit:**

```bash
git add flake.nix pkgs/fnox-source.nix pkgs/fnox-binary.nix
git commit -m "chore: update to fnox v${NEW_VERSION}"
```

## Development

Run:

```bash
nix flake check
nix flake show
```

The dev shell contains the Rust toolchain and packaging dependencies needed to maintain the fnox package build.

## Agent Work Queue

If you are assigning or running coding agents, start here:

- [`docs/work-items/START-HERE.md`](docs/work-items/START-HERE.md)

The seed roadmap behind that queue is tracked in [`IMPROVEMENTS.md`](IMPROVEMENTS.md).
