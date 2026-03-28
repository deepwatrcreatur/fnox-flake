{
  pkgs,
  version,
  fnoxSrc,
}:
pkgs.rustPlatform.buildRustPackage {
  pname = "fnox";
  inherit version;

  src = fnoxSrc;

  cargoHash = "sha256-4ZHB1N+9hTcC75RvSnjx8rZfwgXRgz27fCytMnKWDZw=";

  nativeBuildInputs = with pkgs; [
    perl
    pkg-config
  ];

  buildInputs = with pkgs; [
    openssl
    udev
  ];

  doCheck = false;

  meta = with pkgs.lib; {
    description = "A shell-agnostic secret manager";
    homepage = "https://github.com/jdx/fnox";
    license = licenses.mit;
    mainProgram = "fnox";
    platforms = platforms.unix;
  };
}
