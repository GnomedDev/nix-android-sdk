{
  pkgs,
  lib,
  stdenvNoCC,
}:
{
  manifestUrl,
  manifestBranch,
  projects,
  hashes,
}:

let
  projectOutputs = lib.forEach projects (
    pkgs.callPackage ./fetchSingle.nix {
      inherit manifestUrl;
      inherit manifestBranch;
      outputHash = hashes [ androidVersion ];
    }
  );
in
stdenvNoCC.runCommand "${lib.sources.urlToName manifestUrl}-${manifestBranch}" { } ''
  mkdir $out
  mv ${lib.concatStringsSep " " projectOutputs} $out
''
