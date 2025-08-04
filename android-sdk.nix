{
  pkgs,
  stdenv,
  callPackage,
}:

let
  fetchWithRepo = callPackage ./fetchWithRepo.nix { };
  sdkVersion = "-latest";

  katiPkg = pkgs.kati;
  goPkg = pkgs.go.overrideAttrs {
    # The prebuilt Go toolchain is built with this option, which precompiles the standard library.
    GODEBUG = "installgoroot=all";
    preInstall = '''';
  };
in
stdenv.mkDerivation {
  name = "androidsdk";
  version = sdkVersion;

  nativeBuildInputs = with pkgs; [
    ps
    goPkg
    which
    katiPkg
    writableTmpDirAsHomeHook
  ];

  src = fetchWithRepo {
    manifestUrl = "https://android.googlesource.com/platform/manifest";
    outputHash = "sha256-z+UTBGNWbofvxEnbhaAjh3iTDU1UmXDmCxpzXUSnJl0=";
    manifestBranch = "android${sdkVersion}-release";
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

  patchPhase = ''
    patchShebangs ./build

    substituteInPlace ./build/envsetup.sh --replace-fail complete :
    substituteInPlace ./build/envsetup.sh --replace-fail /bin/pwd $(which pwd)
    substituteInPlace ./build/make/shell_utils.sh --replace-fail /bin/pwd $(which pwd)

    substituteInPlace ./build/make/common/core.mk --replace-fail /bin/bash $(which bash)

    # Symlink the Nix packaged versions of prebuilts, to allow for aarch64 builds.
    mkdir -p ./prebuilts/go/
    mkdir -p ./prebuilts/build-tools/linux-x86/bin/
    ln -s ${goPkg}/share/go ./prebuilts/go/linux-x86
    ln -s ${katiPkg}/bin/ckati ./prebuilts/build-tools/linux-x86/bin/ckati
  '';

  configurePhase = ''
    . build/envsetup.sh
    lunch aosp_arm64-aosp_current-eng
  '';

  buildPhase = ''
    make sdk
  '';
}
