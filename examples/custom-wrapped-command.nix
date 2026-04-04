# Example: custom wrapped command that injects a fnox secret as an env var.
#
# This example builds a wrapper around `curl` that loads MY_API_KEY from fnox
# before exec-ing curl. Adapt it to any CLI tool that reads secrets from the
# environment.
#
# HOW TO USE IN YOUR FLAKE
# ------------------------
#
#   packages.x86_64-linux.curl-with-api-key =
#     import ./examples/custom-wrapped-command.nix {
#       inherit pkgs;
#       fnoxLib  = fnox.lib.x86_64-linux;
#       fnoxPackage = fnox.packages.x86_64-linux.fnox;
#     };
#
# REQUIREMENTS
# ------------
# - MY_API_KEY must be declared in your fnox config under secretDefinitions.
#   With the default Home Manager module config this means adding:
#
#       programs.fnox.secretDefinitions.MY_API_KEY.description = "My API key";
#
# - The fnox config and age key must be present at runtime (set via
#   FNOX_CONFIG and FNOX_AGE_KEY_FILE or the defaults in $HOME/.config/).

{ pkgs, fnoxLib, fnoxPackage }:
fnoxLib.mkWrappedCommand {
  # Name of the resulting binary in $out/bin/.
  name = "curl-with-api-key";

  # The package whose binary will be exec'd after secrets are loaded.
  command = pkgs.curl;
  binaryName = "curl";

  # The fnox package that provides the fnox binary.
  inherit fnoxPackage;

  # Secrets to decrypt and export before running the wrapped command.
  # envVar  — the environment variable name the wrapped program reads.
  # fnoxPath — the key name in the fnox secret store / config.
  secrets = [
    (fnoxLib.mkSecretSpec {
      envVar = "MY_API_KEY";
      fnoxPath = "MY_API_KEY";
    })
  ];

  # Optional: extra shell code to run after secrets are loaded but before exec.
  extraWrapperScript = ''
    # Example: set a default base URL if not already in the environment.
    export MY_SERVICE_URL="''${MY_SERVICE_URL:-https://api.example.com}"
  '';
}
