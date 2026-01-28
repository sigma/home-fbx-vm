# Overlay that adds our custom packages to pkgs
final: prev: {
  hummingbot = final.callPackage ./hummingbot { };
  hummingbot-gateway = final.callPackage ./hummingbot-gateway { };
}
