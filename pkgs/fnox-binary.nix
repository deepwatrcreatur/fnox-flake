{
  pkgs,
  version,
}:
pkgs.stdenv.mkDerivation {
  pname = "fnox";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://github.com/jdx/fnox/releases/download/v${version}/fnox-x86_64-unknown-linux-gnu.tar.gz";
    sha256 = "sha256-1ZO4U4BiEqddt0BI1MsnrHD2gR5ZHB4p9Jb7ivOEdfM=";
  };

  sourceRoot = ".";

  unpackPhase = ''
    runHook preUnpack
    tar -xzf "$src"
    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    install -m755 fnox "$out/bin/fnox"
    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "A shell-agnostic secret manager";
    homepage = "https://github.com/jdx/fnox";
    license = licenses.mit;
    mainProgram = "fnox";
    platforms = [ "x86_64-linux" ];
  };
}
