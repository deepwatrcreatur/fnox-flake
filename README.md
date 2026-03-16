# fnox-flake

`fnox-flake` packages [`fnox`](https://github.com/jdx/fnox), exports wrapper helpers for secret-backed CLI commands, and provides a Home Manager module for declarative integration.

## Outputs

- `packages.<system>.fnox`: source-built `fnox`
- `packages.<system>.fnox-binary`: upstream binary, only on `x86_64-linux`
- `packages.<system>.gh-fnox`, `bw-fnox`, `opencode-claude`, `opencode-zai`: wrapped commands that load only the secrets they need
- `apps.<system>.*`: `nix run` entrypoints for the packages above
- `lib.<system>`:
  - `mkWrappedCommand`
  - `mkFnoxConfigToml`
  - `mkSeedSecretsScript`
  - `defaultSecretDefinitions`
  - `defaultWrappedCommandSpecs`
- `homeManagerModules.default`: reusable Home Manager module
- `overlays.default`: exposes `fnox` in an overlay

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

## Development

Run:

```bash
nix flake check
nix flake show
```

The dev shell contains the Rust toolchain and packaging dependencies needed to maintain the fnox package build.
