{
  description = "A flake for fnox, a secret manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
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
          if true && pkgs.stdenv.isLinux && pkgs.stdenv.isx86_64 then
            # Use pre-built binary for Linux x86_64 to avoid compilation issues
            pkgs.stdenv.mkDerivation {
              pname = "fnox";
              inherit version;

              src = pkgs.fetchurl {
                url = "https://github.com/jdx/fnox/releases/download/v${version}/fnox-x86_64-unknown-linux-gnu.tar.gz";
                sha256 = "d593b853806212a75db74048d4cb27ac70f6811e591c1e29f496fb8af38475f3";
              };

              sourceRoot = ".";

              unpackPhase = ''
                mkdir -p $sourceRoot
                tar -xzf $src -C $sourceRoot --strip-components=0
              '';

              installPhase = ''
                mkdir -p $out/bin
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
            # Fallback to source build for other platforms
            pkgs.rustPlatform.buildRustPackage {
              pname = "fnox";
              inherit version;

              src = pkgs.fetchFromGitHub {
                owner = "jdx";
                repo = "fnox";
                rev = "v${version}";
                hash = "sha256-ThGs9KFbwVp80RtivKOiwnrzx52H1t0RDu+EhUXHCzw=";
              };

              cargoHash = "sha256-U3poZWMd1AMYv1v/rCoCuL24mxQOo++1WkLD/SxwNvU=";

              nativeBuildInputs = with pkgs; [
                pkg-config
                perl
              ];

              buildInputs =
                with pkgs;
                [
                  openssl
                  openssl.dev
                ]
                ++ lib.optionals stdenv.isDarwin [
                  darwin.apple_sdk.frameworks.Security
                  darwin.apple_sdk.frameworks.SystemConfiguration
                ];

              OPENSSL_NO_VENDOR = 1;
              OPENSSL_DIR = "${pkgs.openssl.dev}";
              OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
              OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";
              PERL = "${pkgs.perl}/bin/perl";

              doCheck = false;

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
