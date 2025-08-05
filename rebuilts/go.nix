{ pkgs }:

pkgs.go.overrideAttrs {
  # The prebuilt Go toolchain is built with this option, which precompiles the standard library.
  GODEBUG = "installgoroot=all";
  preInstall = '''';
}
