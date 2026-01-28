{ lib
, python3Packages
, fetchFromGitHub
, stdenv
}:

python3Packages.buildPythonApplication rec {
  pname = "hummingbot";
  version = "2.12.0";
  format = "setuptools";

  src = fetchFromGitHub {
    owner = "hummingbot";
    repo = "hummingbot";
    rev = "v${version}";
    hash = "sha256-yxNJtkM3Rrc9TwwCI8Ko8CKrER4yICCZ9Q/WYMymYmY=";
  };

  nativeBuildInputs = [
    python3Packages.cython
    python3Packages.numpy
  ];

  buildInputs = [
    stdenv.cc.cc.lib
  ];

  propagatedBuildInputs = with python3Packages; [
    aiohttp
    numpy
    pandas
    scipy
    web3
    sqlalchemy
    pydantic
    cryptography
    protobuf
    pyyaml
    requests
    websockets
    ujson
  ];

  doCheck = false;

  preBuild = ''
    export HOME=$TMPDIR
  '';

  meta = with lib; {
    description = "Open-source framework for automated trading strategies";
    homepage = "https://hummingbot.org";
    license = licenses.asl20;
  };
}
