# EB-27 verification

Verified on 31 October 2026 in the isolated Engineer Board checkout, branch `engineer/eb-27-e8591b`.

## Automated and package checks

- `swift test --disable-sandbox`: **16 XCTest tests passed, 0 failures**. Compiles the native SwiftUI/AppKit/Speech app as well as the core.
- Coverage: migration of all three legacy addresses; repeated/new-store loads and stable custom IDs; default unconfigured TeeVee; invalid adds/settings preserving saved bytes; malformed, duplicate-ID and future-version documents preserved and edits refused; malformed legacy data preserved; 43-tile persistence/navigation; built-in aliases and exact custom-name ambiguity; web URL validation; one toggle per key press/release, repeat suppression, modifier/input guards; recognition session cancellation, replacement and one-shot completion.
- `bash scripts/build-app.sh`: **passed**, producing `build/TV Launcher.app` with an ad hoc signature.
- `codesign --verify --deep --strict 'build/TV Launcher.app'`: **passed**.
- `plutil -lint 'build/TV Launcher.app/Contents/Info.plist'`: **passed**. Bundle identifier remains `com.kelvinccho.mactvlauncher`; microphone and speech privacy descriptions are present, including custom tile names.
- `git diff --check`: **passed**.
- Apple's Swift tools required execution outside the filesystem sandbox for their temporary/cache directories. The initial restricted attempt failed; the permitted runs above succeeded.

## Shortcut diagnosis and repair

The previous local key-down monitor compared the entire device-independent modifier set to exactly Command+Shift. Caps Lock adds another flag, preventing a match. It also toggled for every repeated key-down event when Space was held. The new monitor considers Command/Shift/Control/Option individually, ignores Caps Lock/device flags, and uses a key-up latch plus repeat suppression. Editor input bypasses launcher handling; repeated voice chords are consumed outside editors to avoid activating a focused button. Both key-up and key-down are monitored, and focus loss resets the latch.

Voice matching now requires a complete normalized tile name or supported built-in alias, optionally prefixed with open/launch/play. Unknown, multiple and ambiguous destinations do not launch. Custom names are supplied as recognizer context. Recognition errors take priority over any accompanying transcript. Permission, result, silence and timeout callbacks use the same cancellable generation; cancellation invalidates pending callbacks before stopping the engine.

## Manual results and remaining limitations

Computer Use inventory returned: **“The Mac is locked and automatic unlock could not unlock it.”** No native app surface was available. No rendered UI, real keyboard interaction, Caps Lock/held-key behavior in the packaged app, keyboard-only Add Tile flow, actual app relaunch persistence, browser opening, permission dialogs, microphone failure, live speech, timeout/focus cancellation or TV readability result is claimed. Core tests verify the underlying logic, not these end-to-end behaviors.

The manual checklist in README.md remains required on an unlocked target Mac mini/TV, particularly selection scrolling across multiple screens and physical Command–Shift–Space presses with Caps Lock on/off, held Space, and editor focus. Test grant/denial and a missing microphone, and ensure stale commands never launch after Escape, timeout, Settings/Add Tile or focus loss. No host settings, user preferences or permission grants were changed during verification.

The collection is stored as versioned JSON Data in UserDefaults (`launcher.tiles`); migration retains the original `service.*` keys. Corrupt/future data requires manual backup/repair before edits. Custom editing/removal, global shortcuts, distribution signing and notarization are outside this ticket. Voice capture may depend on Apple's online recognition service. RacePlan and `.kitchen-context` were not modified.
