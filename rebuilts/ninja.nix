{ pkgs, fetchgit }:

pkgs.ninja.overrideAttrs {
  version = "1.9";

  # Override to remove `re2c` from the environment, as otherwise the build system regenerates a generated file that AOSP ninja has edited.
  nativeBuildInputs = with pkgs; [
    python3
    installShellFiles
    asciidoc
    docbook_xml_dtd_45
    docbook_xsl
    libxslt.bin
  ];

  # AOSP has a fork of ninja with new command line flags and other fun stuff
  src = fetchgit {
    url = "https://android.googlesource.com/platform/external/ninja/";
    rev = "d2fa73d4b6328e51ba86281588e87213ec45b948";

    outputHash = "sha256-iydLrPAcStT0J4/2ABdDU6I1zqiNzEg7Tq+3zduW1gE=";
  };
}
