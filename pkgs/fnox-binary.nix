{ pkgs
, version
,
}:
let
  platformMap = {
    x86_64-linux = {
      filename = "x86_64-unknown-linux-gnu";
      sha256 = "sha256:137ajbf36dwc89y2c02wgad58za6alpjqifxlganf4jmp3fk8p76";
    };
    aarch64-linux = {
      filename = "aarch64-unknown-linux-gnu";
      sha256 = "sha256:1rdg1a7cmn827v1jki2163i4jspbbipls3m7nh7208vf378mxnpv";
    };
    x86_64-darwin = {
      filename = "x86_64-apple-darwin";
      sha256 = "sha256:0s7kx90gi3c9j8vffvkv61i96jqvfpaabqy2v7sf1q6j67br09qh";
    };
    aarch64-darwin = {
      filename = "aarch64-apple-darwin";
      sha256 = "sha256:02fw2np13y7w90wxkyvqkfibyilmji1gmkhdx36xxshw294wp571";
    };
  };
  platform = platformMap.${pkgs.stdenv.hostPlatform.system} or null;
in
if platform == null then
  null
else
  pkgs.stdenv.mkDerivation {
    pname = "fnox";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/jdx/fnox/releases/download/v${version}/fnox-${platform.filename}.tar.gz";
      sha256 = platform.sha256;
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
      description = "A shell-agnostic secret manager (pre-built binary)";
      homepage = "https://github.com/jdx/fnox";
      license = licenses.mit;
      maintainers = with maintainers; [ ];
      mainProgram = "fnox";
      platforms = [ pkgs.stdenv.hostPlatform.system ];
    };
  }
