# TV Launcher for Mac mini

A standalone native macOS 13+ launcher for a TV controlled with a keyboard. No third-party dependencies. Opens YouTube, Netflix and your configured TeeVee site in the default browser. It does not embed a video player or bypass service logins/subscriptions.

## Build and run

Requires Xcode or the Swift 5.9+ command-line tools on a Mac.

```sh
cd mac-tv-launcher
bash scripts/build-app.sh
open "build/TV Launcher.app"
```

Use the packaged `.app` for microphone/speech permission prompts; it includes the required privacy descriptions. The build uses an ad hoc signature for local use, with no developer account required. Distribution/notarization is not configured. You can copy the app to Applications manually if desired. Nothing installs itself or changes login items.

## Keyboard controls

| Key | Action |
| --- | --- |
| Left/Right or Up/Down | Select previous/next tile, wrapping at the ends |
| Return / keypad Enter | Open selected service |
| 1 / 2 / 3 | Open YouTube / Netflix / TeeVee |
| Command–Shift–Space | Start or stop voice control while the launcher is active |
| Escape | Stop voice control, or leave full screen |
| Control–Command–F | Toggle macOS full screen |
| Command–comma | Edit service addresses |
| Command–Tab | Switch back from the browser to the launcher |

Settings supports normal Tab/Shift–Tab field navigation, Return to save, and Escape to cancel. To include every button in macOS keyboard focus navigation, enable Keyboard navigation in System Settings → Keyboard. The launch tiles always support arrows and Return without this setting.

Set **TeeVee's URL** before first use: the ticket does not identify which TeeVee service to use. Selecting the unconfigured tile opens Settings. Addresses persist locally using macOS UserDefaults under `com.kelvinccho.mactvlauncher`. No credentials or viewing history are stored by the launcher.

## Voice control

Press Command–Shift–Space and grant Speech Recognition and Microphone access. Say “open YouTube”, “Netflix” or “TeeVee”. A short pause completes the command; unknown or ambiguous commands open nothing. Listening ends after ten seconds, on Escape, when toggled off, when Settings opens, or when the app loses focus. There is no background/global hotkey or always-on microphone.

A Mac mini needs a connected microphone (for example a webcam, headset or USB microphone). Apple's Speech Recognition service may require an internet connection and may process audio using Apple's servers. If permissions are denied, enable them in System Settings → Privacy & Security. Unavailable recognition and missing microphones show a message; keyboard launching remains available.

## Verification

```sh
swift test --disable-sandbox
bash scripts/build-app.sh
```

Automated tests cover arrow wrapping, command aliases/ambiguity and URL validation. Physical TV readability, speech capture/permission prompts and playback require manual verification on the target Mac mini:

1. Launch the packaged app; use arrows across both ends, Return and 1–3. Confirm the right site opens and Command–Tab returns.
2. Configure TeeVee entirely with the keyboard, cancel an edit, save an edit, then relaunch and confirm persistence. Try an invalid URL and confirm the error.
3. Toggle full screen and Escape. Verify selection remains visible from your seating distance.
4. Grant microphone/speech permissions and speak each service. Test unknown and ambiguous speech, Escape, timeout and switching apps while listening.
5. Deny permissions or disconnect the microphone and confirm the app reports the issue and keyboard navigation still works.

Browser playback/DRM, browser full screen, account sign-in and network errors are handled by the selected browser/service.
