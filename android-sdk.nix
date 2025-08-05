{
  lib,
  pkgs,
  stdenv,
  callPackage,
}:

let
  androidVersion = "16";
  hashLookup = {
    "16" = "sha256-z+UTBGNWbofvxEnbhaAjh3iTDU1UmXDmCxpzXUSnJl0=";
    "15" = "sha256-chjqREDvDAvHEGQTg5+iOeASjJ1b49esS0JVgwZ3ugQ=";
    "14" = "sha256-+G+/RQzOttl9oLrEIosFcV7+zmaEiiwBLmHVHSl6350=";
    "13" = "sha256-ihAYU/H122bBx0NwDsdfcmdS++K32qxd/G0y1q9GY38=";
    "12" = "sha256-z71Saqh6stiVB7ICvvM18GaA+E8tgcVFdFNs+uk71/4=";
    "11" = "sha256-SixtYTYaozENm2KCsNCY/qLZk8b9v5mDocrnVuKkHIY=";
  };

  releaseConfig = if androidVersion == "11" then "eng" else "aosp_current";

  variantLookup = {
    "11" = "RP1A";
    "12" = "SP1A";
    "13" = "TP1A";
    "14" = "UP1A";
    "15" = "eng";
    "16" = "eng";
  };

  projectsLookup = {
    "16" = [
      "external/starlark-go"
      "platform/build/release"
    ];
    "15" = [
      "external/starlark-go"
      "platform/prebuilts/bazel/common"
      "platform/build/release"
    ];
    "14" = [
      "external/starlark-go"
      "platform/prebuilts/bazel/common"
    ];
    "13" = [ "external/starlark-go" ];
    "12" = [ "external/starlark-go" ];
    "11" = [
      "platform/prebuilts/vndk/v28"
      "platform/prebuilts/vndk/v29"
    ];
  };

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
    else if lib.strings.hasSuffix "linux" stdenv.buildPlatform.system then
      "linux-x86"
    else
      "darwin-x86";

  katiPkg = pkgs.kati;
  goPkg = pkgs.go.overrideAttrs {
    # The prebuilt Go toolchain is built with this option, which precompiles the standard library.
    GODEBUG = "installgoroot=all";
    preInstall = '''';
  };

  fetchWithRepo = callPackage ./fetchWithRepo.nix { };
in
stdenv.mkDerivation {
  name = "androidsdk";
  version = androidVersion;

  nativeBuildInputs = with pkgs; [
    ps
    goPkg
    which
    katiPkg
    writableTmpDirAsHomeHook
  ];

  src = fetchWithRepo {
    manifestUrl = "https://android.googlesource.com/platform/manifest";
    manifestBranch = "android${androidVersion}-release";
    outputHash = hashLookup.${androidVersion};
    projects = [
      # Absolutely necessary for configuring.
      "platform/build"
      "build/blueprint"
      "build/soong"
      "external/golang-protobuf"

      # What we actually want to compile
      "platform/sdk"
    ]
    ++ projectsLookup.${androidVersion};
  };

  patches = [
    ./patches/0001-add-arm-host-arch.patch
    ./patches/0002-add-arm-combo-mk.patch
  ];

  postPatch = ''
    patchShebangs ./build

    substituteInPlace ./build/envsetup.sh --replace-fail complete :
    substituteInPlace ./build/envsetup.sh --replace-fail /bin/pwd $(which pwd)
    substituteInPlace ./build/make/common/core.mk --replace-fail /bin/bash $(which bash)
    substituteInPlace ./build/core/product_config.mk --replace-fail "| sed" "| $(which sed)"

    if ((${androidVersion} > 13)); then
      substituteInPlace ./build/make/shell_utils.sh --replace-fail /bin/pwd $(which pwd)
    else
      substituteInPlace ./build/soong/soong_ui.bash --replace-fail /bin/pwd $(which pwd)
    fi

    if ((${androidVersion} < 15)); then
      substituteInPlace ./build/make/core/config.mk --replace-fail uname $(which uname)
      substituteInPlace ./build/make/core/config.mk --replace-fail date $(which date)
    fi

    # Symlink the Nix packaged versions of prebuilts, to allow for aarch64 builds.
    mkdir -p ./prebuilts/go/
    mkdir -p ./prebuilts/build-tools/${archFolder}/bin/
    ln -s ${goPkg}/share/go ./prebuilts/go/${archFolder}
    ln -s ${katiPkg}/bin/ckati ./prebuilts/build-tools/${archFolder}/bin/ckati
  '';

  configurePhase = ''
    . build/envsetup.sh
    lunch aosp_arm64-${releaseConfig}-${variantLookup.${androidVersion}}
  '';

  buildPhase = ''
    make sdk
  '';
}
