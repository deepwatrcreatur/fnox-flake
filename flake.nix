{
  description = "A flake for fnox, a secret manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        version = "1.7.0";
      in
      {
        packages.default =
          if pkgs.stdenv.isLinux && pkgs.stdenv.isx86_64 then
            # Use pre-built binary for Linux x86_64 to avoid compilation issues
            pkgs.stdenv.mkDerivation {
              pname = "fnox";
              inherit version;

              src = pkgs.fetchurl {
                url = "https://github.com/jdx/fnox/releases/download/v${version}/fnox-x86_64-unknown-linux-gnu.tar.gz";
                sha256 = "d593b853806212a75db74048d4cb27ac70f6811e591c1e29f496fb8af38475f3";
              };

              installPhase = ''
                mkdir -p $out/bin
                tar -xzf $src
                cp fnox $out/bin/
                chmod +x $out/bin/fnox
              '';

              meta = with pkgs.lib; {
                description = "A shell-agnostic secret manager";
                homepage = "https://github.com/jdx/fnox";
                license = licenses.mit;
                maintainers = [ ];
                platforms = [ "x86_64-linux" ];
              };
            }
          else
            # Fallback to input for other platforms
            inputs.fnox.packages.${pkgs.stdenv.hostPlatform.system}.default;
      }
    );
}
