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
      hash = "";
      variant = "eng";
      extraProjects = [
        "external/starlark-go"
        "platform/build/release"
      ];
    };
    "15" = {
      hash = "";
      variant = "eng";
      extraProjects = [
        "external/starlark-go"
        "platform/prebuilts/bazel/common"
        "platform/build/release"
      ];
    };
    "14" = {
      hash = "";
      variant = "UP1A";
      extraProjects = [
        "external/starlark-go"
        "platform/prebuilts/bazel/common"
      ];
    };
    "13" = {
      hash = "";
      variant = "TP1A";
      extraProjects = [ "external/starlark-go" ];
    };
    "12" = {
      hash = "sha256-LBPcf/gqZFQejvSQchtP5v2iDTni5zU7fb+I50IdXb0=";
      variant = "SP1A";
      extraProjects = [
        "external/starlark-go"
        "platform/prebuilts/vndk/v28"
        "platform/prebuilts/vndk/v29"
        "platform/prebuilts/vndk/v30"
      ];
    };
    "11" = {
      hash = "";
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

  fetchWithRepo = callPackage ./fetchWithRepo { };
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

      # Dependencies of the SDK
      "external/apache-xml"
      "external/conscrypt"
      "external/llvm"
      "external/protobuf"
      "external/skia"
      "external/okhttp"
      "kernel/configs"
      "platform/bionic"
      "platform/art"
      "platform/cts"
      "platform/libcore"
      "platform/libnativehelper"
      "platform/external/apache-harmony"
      "platform/external/bouncycastle"
      "platform/external/hamcrest"
      "platform/external/googletest"
      "platform/external/guava"
      "platform/external/junit"
      "platform/external/jsilver"
      "platform/external/jsoncpp"
      "platform/external/kotlinc"
      "platform/external/python/cpython3"
      "platform/frameworks/av"
      "platform/frameworks/base"
      "platform/frameworks/native"
      "platform/hardware/interfaces"
      "platform/hardware/libhardware"
      "platform/packages/modules/Connectivity"
      "platform/packages/modules/common"
      "platform/packages/modules/Wifi"
      "platform/packages/modules/NetworkStack"
      "platform/packages/modules/NeuralNetworks"
      "platform/system/apex"
      "platform/system/logging"
      "platform/system/libvintf"
      "platform/system/linkerconfig"
      "platform/system/tools/aidl"
      "platform/system/tools/hidl"
      "platform/system/tools/xsdc"
      "platform/tools/apksig"
      "platform/tools/tradefederation/prebuilts"
      "platform/tools/metalava"
      # - Pulling in for the precompiled java deps that are hopefully cross-platform
      "platform/prebuilts/tools"
      "platform/prebuilts/misc"
      "platform/prebuilts/sdk"
      # - Need to get rid of these
      "platform/prebuilts/clang/host/linux-x86"

      # What we actually want to compile
      "platform/sdk"
    ]
    ++ buildInfo.extraProjects;
  };

  patches = [
    ./patches/0001-add-arm-host-arch.patch
    ./patches/0002-add-arm-combo-mk.patch
  ]
  ++ (if androidVersionInt < 13 then [ ./patches/0003-remove-go-tests.patch ] else [ ])
  ++ [
    ./patches/0005-disable-path-sandbox.patch
  ];

  postPatch = ''
    patchShebangs ./build

    substituteInPlace ./build/envsetup.sh --replace-fail complete :
    substituteInPlace ./build/envsetup.sh --replace-fail /bin/pwd $(which pwd)
    substituteInPlace ./build/make/common/core.mk --replace-fail /bin/bash $(which bash)
    substituteInPlace ./build/core/product_config.mk --replace-fail "| sed" "| $(which sed)"

    # I cannot find the `vts_proto_fuzzer_default` or `VtsHalDriverDefaults` defines.
    substituteInPlace ./system/tools/hidl/build/hidl_interface.go --replace-fail "if shouldGenerateVts" "if false" 

    # I love starting `/bin/sh` with no env variables so I have to do this.
    substituteInPlace ./build/blueprint/bootstrap/bootstrap.go --replace-fail "mv -f" "$(which mv) -f"
    substituteInPlace ./build/blueprint/bootstrap/bootstrap.go --replace-fail dirname $(which dirname)
    substituteInPlace ./build/blueprint/bootstrap/bootstrap.go --replace-fail basename $(which basename)
    substituteInPlace ./build/blueprint/bootstrap/bootstrap.go --replace-fail "env -i" "$(which env) -i"
    substituteInPlace ./build/blueprint/bootstrap/bootstrap.go --replace-fail "cp \$in" "$(which cp) \$in"
    substituteInPlace ./build/blueprint/bootstrap/bootstrap.go --replace-fail "cp \$out" "$(which cp) \$out"
    substituteInPlace ./build/blueprint/bootstrap/bootstrap.go --replace-fail "cmp --quiet" "$(which cmp) --quiet"

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
    make sdk
  '';
}
