# nix-android-sdk

An attempt to build the Android SDK, specifically enough tools to compile a basic Expo React Native app, with the following criteria:

- Compiles in the Nix sandbox
- Can be compiled on an AArch64 machine
- Produces binaries for x64 and aarch64 linux
- Does not substantially rewrite the AOSP build system, aka I don't want to rewrite make/soong.

## Status

- [x] Download AOSP via repo
- [x] `source envsetup.sh` completes without error
- [ ] `lunch` configuration completes without error
- [ ] `make sdk` completes without error
- [ ] A working toolchain is produced for compilation.
