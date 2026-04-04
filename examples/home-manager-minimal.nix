# Minimal Home Manager module configuration for fnox-flake.
#
# HOW TO USE
# ----------
# 1. Add fnox-flake to your flake inputs:
#
#      inputs.fnox.url = "github:deepwatrcreatur/fnox-flake";
#
# 2. Import this file (or paste the programs.fnox block) into your Home Manager
#    configuration module and pass `inputs.fnox` as a specialArg or use it
#    directly in your home.nix imports:
#
#      imports = [ inputs.fnox.homeManagerModules.default ];
#
# 3. Apply the overlay so `pkgs.fnox` resolves:
#
#      nixpkgs.overlays = [ inputs.fnox.overlays.default ];
#
# NOTES
# -----
# - `recipients` must contain at least one age public key (assertion enforced).
#   Generate a key with: age-keygen -o ~/.config/sops/age/keys.txt
# - `seedSecretSources` is optional. Each secret tries each path in order;
#   the first readable, non-empty file wins. Already-seeded values are never
#   overwritten. See docs/security.md for full precedence rules.

{ ... }:
{
  programs.fnox = {
    enable = true;

    # Your age public key (from age-keygen or similar).
    recipients = [
      "age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p"
    ];

    # Optional: seed secrets from local files on activation.
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
