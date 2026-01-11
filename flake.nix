{
  description = "A flake for fnox, a secret manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        version = "1.7.0";
      in
      {
        packages.default = pkgs.rustPlatform.buildRustPackage {
          pname = "fnox";
          inherit version;

          src = pkgs.fetchFromGitHub {
            owner = "jdx";
            repo = "fnox";
            rev = "v${version}";
            hash = "sha256-0g0bqx2qb17g1q8xvml7kp3z6yn2laivqqhvs5y5mhavl7saq4af";
          };

          # Update this hash after the first failed build
          cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

          nativeBuildInputs = with pkgs; [
            pkg-config
          ];

          buildInputs = with pkgs; [
            openssl
          ] ++ lib.optionals stdenv.isDarwin [
            darwin.apple_sdk.frameworks.Security
            darwin.apple_sdk.frameworks.SystemConfiguration
          ];

          doCheck = false; # Skip tests for faster builds

          meta = with pkgs.lib; {
            description = "A shell-agnostic secret manager";
            homepage = "https://github.com/jdx/fnox";
            license = licenses.mit;
            maintainers = [ ];
          };
        };
      }
    );
}
