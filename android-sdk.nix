{
  lib,
  pkgs,
  stdenv,
  callPackage,
}:

let
  androidVersion = "12";
  androidVersionInt = lib.strings.toInt androidVersion;

  buildInfo = buildInfoLookup.${androidVersion};
  buildInfoLookup = {
    "16" = {
      hash = "sha256-z+UTBGNWbofvxEnbhaAjh3iTDU1UmXDmCxpzXUSnJl0=";
      variant = "eng";
      extraProjects = [
        "external/starlark-go"
        "platform/build/release"
      ];
    };
    "15" = {
      hash = "sha256-chjqREDvDAvHEGQTg5+iOeASjJ1b49esS0JVgwZ3ugQ=";
      variant = "eng";
      extraProjects = [
        "external/starlark-go"
        "platform/prebuilts/bazel/common"
        "platform/build/release"
      ];
    };
    "14" = {
      hash = "sha256-+G+/RQzOttl9oLrEIosFcV7+zmaEiiwBLmHVHSl6350=";
      variant = "UP1A";
      extraProjects = [
        "external/starlark-go"
        "platform/prebuilts/bazel/common"
      ];
    };
    "13" = {
      hash = "sha256-ihAYU/H122bBx0NwDsdfcmdS++K32qxd/G0y1q9GY38=";
      variant = "TP1A";
      extraProjects = [ "external/starlark-go" ];
    };
    "12" = {
      hash = "sha256-ePIYb0IW5VLxzfxqhKbacAAnQcmalFbyKUxa0IViVrs=";
      variant = "SP1A";
      extraProjects = [
        "external/starlark-go"
        "platform/prebuilts/vndk/v28"
        "platform/prebuilts/vndk/v29"
        "platform/prebuilts/vndk/v30"
      ];
    };
    "11" = {
      hash = "sha256-SixtYTYaozENm2KCsNCY/qLZk8b9v5mDocrnVuKkHIY=";
      variant = "RP1A";
      extraProjects = [
        "platform/prebuilts/vndk/v28"
        "platform/prebuilts/vndk/v29"
      ];
    };
  };

  releaseConfig = if androidVersionInt > 12 then "aosp_current" else "eng";

  archLookup = {
    "aarch64-linux" = "linux-arm64";
    "x86_64-linux" = "linux-x86";
    "aarch64-darwin" = "darwin-arm64";
    "x86_64-darwin" = "darwin-x86";
  };

  archFolder =
    if androidVersionInt > 15 then
      archLookup.${stdenv.buildPlatform.system}
    # Android before 16 has no support for aarch64-linux, so we need to put our builds in the `linux-x86` folder.
    else if lib.strings.hasSuffix "linux" stdenv.buildPlatform.system then
      "linux-x86"
    else
      "darwin-x86";

  katiPkg = pkgs.kati;
  goPkg = callPackage ./rebuilts/go.nix { };
  ninjaPkg = callPackage ./rebuilts/ninja.nix { };

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
    ninjaPkg
    writableTmpDirAsHomeHook
  ];

  src = fetchWithRepo {
    manifestUrl = "https://android.googlesource.com/platform/manifest";
    manifestBranch = "android${androidVersion}-release";
    outputHash = buildInfo.hash;
    projects = [
      # Absolutely necessary for configuring.
      "platform/build"
      "build/blueprint"
      "build/soong"
      "external/golang-protobuf"

      # What we actually want to compile
      "platform/sdk"
    ]
    ++ buildInfo.extraProjects;
  };

  patches = [
    ./patches/0001-add-arm-host-arch.patch
    ./patches/0002-add-arm-combo-mk.patch
    ./patches/0003-remove-go-tests.patch
    ./patches/0004-buildversion-add-arm-variant.patch
  ];

  postPatch = ''
    patchShebangs ./build

    substituteInPlace ./build/envsetup.sh --replace-fail complete :
    substituteInPlace ./build/envsetup.sh --replace-fail /bin/pwd $(which pwd)
    substituteInPlace ./build/make/common/core.mk --replace-fail /bin/bash $(which bash)
    substituteInPlace ./build/core/product_config.mk --replace-fail "| sed" "| $(which sed)"
    substituteInPlace ./build/soong/ui/build/path.go --replace-fail \
      'ctx.Printf("Disallowed PATH tool %q used: %#v", log.Basename, log.Args)' \
      'continue'

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
    ln -s ${ninjaPkg}/bin/ninja ./prebuilts/build-tools/${archFolder}/bin/ninja
  '';

  configurePhase = ''
    . build/envsetup.sh
    lunch aosp_arm64-${releaseConfig}-${buildInfo.variant}
  '';

  buildPhase = ''
    export TEMPORARY_DISABLE_PATH_RESTRICTIONS=1
    make sdk
  '';
}
