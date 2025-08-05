{
  lib,
  pkgs,
  stdenv,
  callPackage,
}:

let
  fetchWithRepo = callPackage ./fetchWithRepo.nix { };
  androidVersion = "16";
  androidSubversion = "s2";
  fullVersion = "${androidVersion}-${androidSubversion}";

  archLookup = {
    "aarch64-linux" = "linux-arm64";
    "x86_64-linux" = "linux-x86";
    "aarch64-darwin" = "darwin-arm64";
    "x86_64-darwin" = "darwin-x86";
  };

  archFolder =
    if lib.strings.toInt androidVersion > 15 then
      archLookup.${stdenv.buildPlatform.system}
    # Android before 16 has no support for aarch64-linux, so we need to put our builds in the `linux-x86` folder.
    else if lib.strings.hasSuffix "linux" stdenv.buildPlatform then
      "linux-x86"
    else
      "darwin-x86";

  katiPkg = pkgs.kati;
  goPkg = pkgs.go.overrideAttrs {
    # The prebuilt Go toolchain is built with this option, which precompiles the standard library.
    GODEBUG = "installgoroot=all";
    preInstall = '''';
  };
in
stdenv.mkDerivation {
  name = "androidsdk";
  version = fullVersion;

  nativeBuildInputs = with pkgs; [
    ps
    goPkg
    which
    katiPkg
    writableTmpDirAsHomeHook
  ];

  src = fetchWithRepo {
    manifestUrl = "https://android.googlesource.com/platform/manifest";
    outputHash = "sha256-ETuszUWCInIAMNbYiNBqgEFzEDvftkyI+oAJ2mQ+KwA=";
    manifestBranch = "android${fullVersion}-release";
    projects = [
      # Absolutely necessary for configuring.
      "platform/build"
      "platform/build/release"
      "build/blueprint"
      "build/soong"
      "external/golang-protobuf"
      "external/starlark-go"

      # What we actually want to compile
      "platform/sdk"
    ];
  };

  patches = [
    ./patches/0001-add-arm-host-arch.patch
  ];

  postPatch = ''
    patchShebangs ./build

    substituteInPlace ./build/envsetup.sh --replace-fail complete :
    substituteInPlace ./build/envsetup.sh --replace-fail /bin/pwd $(which pwd)
    substituteInPlace ./build/make/shell_utils.sh --replace-fail /bin/pwd $(which pwd)
    substituteInPlace ./build/make/common/core.mk --replace-fail /bin/bash $(which bash)

    # Symlink the Nix packaged versions of prebuilts, to allow for aarch64 builds.
    mkdir -p ./prebuilts/go/
    mkdir -p ./prebuilts/build-tools/${archFolder}/bin/
    ln -s ${goPkg}/share/go ./prebuilts/go/${archFolder}
    ln -s ${katiPkg}/bin/ckati ./prebuilts/build-tools/${archFolder}/bin/ckati
  '';

  configurePhase = ''
    . build/envsetup.sh
    lunch aosp_arm64-aosp_current-eng
  '';

  buildPhase = ''
    make sdk
  '';
}
