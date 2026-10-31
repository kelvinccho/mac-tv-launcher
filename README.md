# TV Launcher for Mac mini

A standalone native macOS 13+ launcher for a TV controlled with a keyboard. No third-party dependencies. Opens YouTube, Netflix, your configured TeeVee site and named custom web tiles in the default browser. It does not embed a video player or bypass service logins/subscriptions.

## Build and run

Requires Xcode or the Swift 5.9+ command-line tools on a Mac.

```sh
cd mac-tv-launcher
bash scripts/build-app.sh
open "build/TV Launcher.app"
```

Use the packaged `.app` for microphone/speech permission prompts; it includes the required privacy descriptions. The build uses an ad hoc signature, with no developer account required. Developer ID signing and notarization are not configured. You can copy the app to Applications manually if desired. Nothing installs itself or changes login items.

## Download and automated publishing

Download `TV-Launcher-macOS-universal.zip` and `SHA256SUMS` from the [latest GitHub Release](https://github.com/kelvinccho/mac-tv-launcher/releases/latest). In the download directory, run `shasum -a 256 -c SHA256SUMS`, unzip the archive, then move `TV Launcher.app` to Applications. These builds support Apple silicon and Intel Macs running macOS 13 or later.

Downloads are ad hoc signed and **not notarized**. macOS Gatekeeper may block opening them. Only if you trust the source and have verified the download, use System Settings → Privacy & Security → Open Anyway after attempting to open the app. On managed Macs this may require an administrator; building locally is another option. Checksums detect a damaged download; they do not establish the publisher's identity.

The `Build and publish macOS app` GitHub Actions workflow tests pull requests targeting `main` and every push to `main` (including merges). It runs the Swift tests, builds a universal release app, checks both architectures, validates the bundle and signature, then archives the app with `ditto` to preserve its executable permissions and bundle metadata. PR runs retain the ZIP and checksum as a `macos-app` workflow artifact for seven days and do not publish releases.

After a successful build on `main`, a separate job uses the built-in `GITHUB_TOKEN` with `contents: write` to publish a GitHub Release containing the ZIP and checksum. No personal token or Apple signing secrets are required. Repository/organization policy must allow GitHub Actions and this token permission. Each release targets the exact tested commit, uses a unique `main-<run ID>-<attempt>` tag, and becomes the latest release only after both assets are uploaded. Re-running a workflow creates a new release tag; a failed publication can leave a draft for a maintainer to inspect. No release runs from a pull request. GitHub serializes runs per ref; pending runs may be superseded by newer pushes.

To reproduce the universal package build locally:

```sh
swift test --disable-sandbox
bash scripts/build-app.sh --arch arm64 --arch x86_64
lipo -archs 'build/TV Launcher.app/Contents/MacOS/TVLauncher' # expect arm64 and x86_64
codesign --verify --deep --strict 'build/TV Launcher.app'
```

## Keyboard controls

| Key | Action |
| --- | --- |
| Left/Right or Up/Down | Select previous/next tile, wrapping at the ends |
| Return / keypad Enter | Open selected service |
| 1 / 2 / 3 | Open YouTube / Netflix / TeeVee |
| Command–Shift–Space | Start or stop voice control once per press while the launcher is active (Caps Lock supported) |
| Escape | Stop voice control, or leave full screen |
| Control–Command–F | Toggle macOS full screen |
| Command–comma | Edit built-in service addresses |
| Command–N | Add a custom web tile |
| Command–Tab | Switch back from the browser to the launcher |

Settings and Add Tile support normal Tab/Shift–Tab field navigation, Return to save, and Escape to cancel. Command–Shift–Space does not intercept editor input. To include every button in macOS keyboard focus navigation, enable Keyboard navigation in System Settings → Keyboard. The launch tiles always support arrows and Return without this setting.

Set **TeeVee's URL** before first use: the ticket does not identify which TeeVee service to use. Selecting the unconfigured tile opens Settings. Tiles persist locally using macOS UserDefaults under `com.kelvinccho.mactvlauncher`. No credentials or viewing history are stored by the launcher.

## Custom tiles and saved data

Press **Command–N** (or Add Tile). Type a name, press Tab, enter a full HTTP/HTTPS URL, and press Return. The saved tile is selected; press Return again to open it. Escape cancels without saving. Blank names, duplicate names/voice aliases, non-web URLs and URLs containing credentials are rejected without changing saved tiles. Use a distinct, pronounceable name. Settings edits the three built-in addresses; custom tile editing/removal is not included.

Arrow keys move through every tile in order, wrapping at both ends. The three-column grid scrolls to keep selection visible. Return opens the selection; 1–3 always open the original built-in services regardless of collection size.

On first startup, existing `service.youtube`, `service.netflix` and `service.teevie` settings migrate into the versioned `launcher.tiles` collection. The legacy values are retained, and later startup uses the collection. Unconfigured TeeVee still opens Settings. If saved data is malformed or has an unsupported version, the app displays an error and disables edits without overwriting it. Back up the app's preferences before manually repairing `launcher.tiles` or malformed legacy values, then choose Retry loading saved tiles. There is no automatic reset or destructive recovery button.

## Voice control

Press Command–Shift–Space and grant Speech Recognition and Microphone access. Say “open YouTube”, “Netflix”, “TeeVee”, or an exact custom tile name (for example “open BBC News”). Names ignore case, punctuation and accents. The aliases “you tube”, “netflex” and “tee vee” remain supported. Optionally prefix a name with “open”, “launch” or “play”. Multiple destinations, partial names, unknown commands and ambiguous names open nothing. A short pause completes the command. Listening ends after ten seconds, on Escape, when toggled off, when Settings or Add Tile opens, or when the app or launcher window loses focus. There is no background/global hotkey or always-on microphone.

A Mac mini needs a connected microphone (for example a webcam, headset or USB microphone). Apple's Speech Recognition service may require an internet connection and may process audio using Apple's servers. If permissions are denied, enable them in System Settings → Privacy & Security. Unavailable recognition and missing microphones show a message; keyboard launching remains available.

## Verification

```sh
swift test --disable-sandbox
bash scripts/build-app.sh
```

Automated tests cover migration/repeated loads, tile persistence, malformed-data preservation, invalid saves, large collections, name matching, URL validation, shortcut repeat/release behavior and cancellation generations. Physical TV readability, speech capture/permission prompts and playback require manual verification on the target Mac mini:

1. Launch the packaged app; use arrows across both ends, Return and 1–3. Confirm the right site opens and Command–Tab returns.
2. Configure TeeVee entirely with the keyboard, cancel an edit, save an edit, then relaunch and confirm persistence. Try an invalid URL and confirm the error.
3. Press Command–N, type a name, Tab to an HTTP/HTTPS URL, Return to save, then Return to open. Relaunch and open the same tile. Repeat with invalid fields and Escape; confirm no saved data changes. Add enough tiles for multiple rows; arrow through both wrap points and confirm selection scrolls into view.
4. Toggle full screen and Escape. Verify selection remains visible from your seating distance.
5. Grant microphone/speech permissions and speak each service. Test custom names, unknown and ambiguous speech, Escape, timeout, opening either editor and switching apps/windows while listening. Confirm no delayed launch after cancellation. Test Command–Shift–Space with Caps Lock both off and on; hold Space and confirm only one toggle, release and press again to stop. Test the chord in Settings/Add Tile and confirm it does not start recognition or intercept editing.
6. Deny permissions or disconnect the microphone and confirm the app reports the issue and keyboard navigation still works.

Browser playback/DRM, browser full screen, account sign-in and network errors are handled by the selected browser/service.
