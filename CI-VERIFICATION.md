# EB-28 publishing workflow verification

Verified locally on 31 October 2026.

- `swift test --disable-sandbox`: 16 tests passed, zero failures.
- `bash scripts/build-app.sh --arch arm64 --arch x86_64`: passed.
- Executed the workflow's actual `Verify app and package download` shell block against that build: passed (Info.plist validation, both architectures, strict signature verification, ZIP creation and SHA-256 manifest).
- Extracted the ZIP with `ditto`; verified the checksum, executable permission, strict code signature and both architectures on the extracted app.
- `xcrun vtool -show-build` reports minimum macOS 13.0 for both binary slices. The local newer linker emitted an Intel architecture deprecation warning, but the build succeeded.
- `actionlint` 1.7.12 passed (ShellCheck integration disabled because ShellCheck is not installed); `bash -n` passed for the build script and workflow shell blocks.
- `git diff --check`: passed.

Apple's compiler/cache tools required execution outside the filesystem sandbox; the initial restricted test attempt failed and the permitted test run passed. The local `lipo -verify_arch` command rejected its arguments; the workflow instead checks the output of `lipo -archs` for both required architectures, which passed.

The workflow runs checks for pull requests targeting main. Only the separate publish job on a successful push to main receives write permission. It downloads the build artifact, verifies its checksum, creates a draft release at the tested commit with both assets, then publishes it. Action versions are pinned to official release commit SHAs. A unique run/attempt tag avoids overwriting earlier releases on retries.

No release was published during local verification. The real `GITHUB_TOKEN` release creation path must be confirmed after merge; it requires repository policy to permit Actions and `contents: write`. This change does not configure Developer ID signing or notarization, and Gatekeeper may block downloaded apps. No app UI, voice permissions, playback or physical Intel Mac execution was tested for this CI change. Installation limitations and failed-publication recovery are documented in README.md.
