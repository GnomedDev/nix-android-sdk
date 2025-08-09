{
  runCommand,
  pkgs,
  lib,

  manifestUrl,
  manifestBranch,
  outputHash,
  outputHashAlgo ? "sha256",
  project,
}:
runCommand "${lib.sources.urlToName manifestUrl}-${manifestBranch}"
  {
    nativeBuildInputs = with pkgs; [
      writableTmpDirAsHomeHook
      git-repo
      cacert
      gnupg
    ];

    outputHashMode = "recursive";
    inherit outputHash outputHashAlgo;
  }
  ''
    mkdir $out
    cd $out

    repo init -u ${manifestUrl} -b ${manifestBranch} --depth 1
    repo sync -c --fail-fast ${project}

    rm -rf .repo
  ''
