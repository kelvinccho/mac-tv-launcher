# EB-25 verification

Verified on 31 October 2026 in the Engineer Board task workspace.

- `swift test --disable-sandbox`: **4 XCTest tests passed, 0 failures** on the publication verification run. This also compiled the native SwiftUI/AppKit/Speech executable.
- `bash scripts/build-app.sh`: **passed**, creating `build/TV Launcher.app` with a local ad hoc signature and microphone/speech usage descriptions. The release linker required execution outside the restricted sandbox.
- `codesign --verify --deep --strict 'build/TV Launcher.app'`: **passed**.
- `plutil -lint 'build/TV Launcher.app/Contents/Info.plist'`: **passed**.
- `git diff --check`: **passed**.

Computer Use did not grant access to the built TV Launcher app, so no rendered UI, real keyboard interaction, microphone permission flow, spoken command, browser launch or playback test is claimed. Use the manual checklist in README.md on the target Mac mini/TV.

TeeVee intentionally requires a user-configured URL because the ticket does not identify the service address. Voice control requires a microphone and macOS permissions, and may require Apple's online recognition service. The shortcut works while the launcher is active; Command–Tab returns from the browser. Distribution signing/notarization and a global shortcut are outside this implementation.
