{ lib
, stdenv
, fetchFromGitHub
, nodejs_20
, pnpm_9
, python3
, pkg-config
, libusb1
}:

stdenv.mkDerivation rec {
  pname = "hummingbot-gateway";
  version = "2.12.0";

  src = fetchFromGitHub {
    owner = "hummingbot";
    repo = "gateway";
    rev = "v${version}";
    hash = "sha256-Z0uB1/7AqPad0ZvmLRly4xpKm4xTuBRRcqo/KaiKn08=";
  };

  pnpmDeps = pnpm_9.fetchDeps {
    inherit pname version src;
    fetcherVersion = 3;
    hash = "sha256-EK7Rxr6swq9tcUCAQglkKccRJd8TFPjmS0bse3cg4t8=";
  };

  nativeBuildInputs = [
    nodejs_20
    pnpm_9.configHook
    python3
    pkg-config
  ];

  buildInputs = [
    libusb1
  ];

  buildPhase = ''
    runHook preBuild
    pnpm run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/gateway
    cp -r dist node_modules package.json $out/lib/gateway/
    mkdir -p $out/bin
    cat > $out/bin/hummingbot-gateway <<'EOF'
    #!${stdenv.shell}
    exec ${nodejs_20}/bin/node ${placeholder "out"}/lib/gateway/dist/index.js "$@"
    EOF
    chmod +x $out/bin/hummingbot-gateway
    patchShebangs $out/bin
    runHook postInstall
  '';

  meta = with lib; {
    description = "API server for DEX and blockchain interactions";
    homepage = "https://github.com/hummingbot/gateway";
    license = licenses.asl20;
  };
}
