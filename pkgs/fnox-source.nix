{
  pkgs,
  version,
  fnoxSrc,
}:
pkgs.rustPlatform.buildRustPackage {
  pname = "fnox";
  inherit version;

  src = fnoxSrc;

  cargoHash = "sha256-U3poZWMd1AMYv1v/rCoCuL24mxQOo++1WkLD/SxwNvU=";

  nativeBuildInputs = with pkgs; [
    perl
    pkg-config
  ];

  buildInputs = with pkgs; [
    openssl
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
