# nix-android-sdk

An attempt to build the Android SDK, specifically enough tools to compile a basic Expo React Native app, with the following criteria:

- Compiles in the Nix sandbox
- Can be compiled on an AArch64 machine
- Produces binaries for x64 and aarch64 linux
- Does not substantially rewrite the AOSP build system, aka I don't want to rewrite make/soong.

## File structure

- `flake.nix` (locked in `flake.lock`): Dependency declarations and entrypoint.
- `fetchWithRepo.nix`: A Nix Fetcher which handles using Google's `repo` tool to fetch AOSP.
- `android-sdk.nix`: The actual build script for the Android SDK, using the rest of the tooling and called from `flake.nix`.

- `hashfile.json`: A lookup table for `fetchWithRepo` to map Android Version and Project name to a FOD hash.
- `update_hashfile.py`: Generator for said lookup table, needed when adding support for a new android version or package.

- `rebuilts`: A directory for the build scripts for replacements to the `prebuilts` folder of AOSP, mainly to allow for aarch64 builds.
- `patches`: A directory for code patches that wouldn't fit in `android-sdk.nix`'s `postPatch` bash script, generated using `git`.

## Status

Android 11-12:

- [x] Download AOSP via repo
- [x] `source envsetup.sh` completes without error
- [x] `lunch` configuration completes without error
- [ ] `make sdk` completes without error
- [ ] A working toolchain is produced for compilation.

Android 13-16:

- [x] Download AOSP via repo
- [x] `source envsetup.sh` completes without error
- [ ] `lunch` configuration completes without error
- [ ] `make sdk` completes without error
- [ ] A working toolchain is produced for compilation.
