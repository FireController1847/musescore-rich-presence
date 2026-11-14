# AGENTS.md

## Project and workflow

- MuseScore Rich Presence integrates MuseScore Studio with Discord. Keep the public README human-oriented: installation, usage, preview, troubleshooting, AI disclosure, and licensing. Put implementation details here.
- Develop the current native implementation on `main`. The `previous` branch preserves the older version.
- Favor small, maintainable changes. Keep QML responsible for score information and activity formatting, and C++ responsible for native integration.
- Preserve the maintainer's Git identity and append `Co-authored-by: Codex <noreply@openai.com>` to agent-created commits.
- Do not create tests or custom CI workflows. Builds are permitted; manual verification belongs to the maintainer. Report 2–3 or fewer concise verification items and disclose unverified behavior.
- Preserve the README title, preview images, and AI disclosure unless explicitly requested otherwise.

## Architecture

| Path | Responsibility |
| --- | --- |
| `src/plugin/RichPresence.qml` | Plugin entry point, active score tracking, selection/transport state, metadata, rotation, Discord activity payloads. |
| `src/plugin/DiscordIPC/qmldir` | Native QML module declaration. |
| `src/native/discordipc.cpp`, `discordipc.h` | Qt singleton, settings, native UI discovery, playback snapshot, text decoding, Discord IPC. |
| `src/native/plugin.cpp` | QML module registration. |
| `src/native/StatusButton.qml`, `SettingsWindow.qml`, `statusbar.qrc` | Status-bar integration and persistent preference UI. |
| `CMakeLists.txt`, `CMakePresets.json`, `.vscode/` | Build, staging and automatic deployment. |

The QML plugin loads the native module on invocation rather than discovery. Only the first instance owns monitoring; subsequent invocations toggle activity. MuseScore's legacy plugin manager has no automatic startup hook. The native module locates the notation status bar and playback toolbar through the host's Qt/QML objects, so internal host changes may require compatibility fixes.

Discord IPC uses `QLocalSocket` directly, including socket discovery, handshake, framing, reconnection, deduplication and activity cleanup. Do not introduce Node.js, intermediate JSON files, external companion processes or administrator requirements. Socket discovery supports Windows and Unix; the maintainer has verified Discord activity on macOS only.

## Activity contract

When playback is enabled, active transport takes precedence over selection. Otherwise, any selection (including non-staff text) means Editing; no selection means Viewing. No open score clears activity by default or displays Browsing scores if configured.

| Viewing | Editing | Playing / Listening |
| --- | --- | --- |
| Measures | Measure · Staff | System · Page |
| Systems | Dynamics · BPM | Dynamics · BPM |
| Staves | Key · Time signature | Key · Time signature |
| Pages | Instrument | Instrument (· Sustained while Listening) |

- Viewing and Editing headlines use `Viewing <title>...` and `Editing <title>...`; playback uses the title alone. The title is not repeated in rotations. Filename is enabled by default and used only as the headline fallback when the title is unavailable; disabling title sharing does not expose a filename for a titled score. Metadata never rotates. Skip disabled or unavailable fields; join paired values with ` · `. Default rotation: 5 seconds, configurable 5–60 seconds.
- Listening uses Discord type 2, with the title in `name` and `details`, author credit in `state`, and rotating playback statistics in `assets.large_text` (Discord renders this as the third text line). Do not restore the static MuseScore 4 caption in Listening. Playing without a progress bar uses type 0 and the normal rotating state.
- Use the `musescore4` large asset and small assets `view` for Viewing, `pencil` for Editing, and `play` for Playing/Listening. Small-image hover text joins enabled, nonempty subtitle, composer and lyricist values in that order with newlines, without labels. Flatten internal line breaks before joining, preserve the intentional separators, and apply the Discord text limit. Browsing has no score tooltip. Preserve existing sharing preferences, elapsed session timestamps, and playback start/end timestamps synchronized with the transport. Reset the elapsed timer when changing scores.
- Prefer visible heading text in leading vertical frames (MuseScore 4.6+) over non-placeholder metadata. Decode rich text and flatten CRLF, CR, LF, Unicode line separators and encoded newlines to spaces; preserve consecutive logical line breaks as consecutive spaces. Bound Discord text to 128 characters without splitting a surrogate pair.
- Playback uses MuseScore 4.7's internal transport model. It is score-wide, so select the first chord track at or before the current position within the measure, falling back to a rest track for staff-specific information. Editing uses the selection. Display staff numbers as one-based staff indices, and count actual staves rather than voice slots. Internal MuseScore track indices remain necessary for voice-specific queries.
- While Listening, append ` · Sustained` to the instrument rotation if the representative playback segment lies inside a playback-enabled `Element.PEDAL` spanner in the instrument's part. Match the entire part, including both staves of a piano, and treat the end tick as exclusive. This is a notation-based estimate at the sampled playback position, not live audio or MIDI pedal telemetry. Preserve the normal rotation cadence and omit the suffix when the pedal is inactive or unavailable.
- Count musical systems across the score, excluding frame-only systems. Use the local key and time signature; if no mode is specified, use the requested display heuristic (flats → minor, sharps or no accidentals → major). Explicit key modes take precedence; this heuristic does not establish the actual tonality. Dynamics use full names for the latest explicit sustained marking, not interpolated volume, hairpins or transient accents.
- Keep the settings UI and defaults synchronized with activity changes; preferences are persisted through QSettings. Preserve the fallback status window for native module load or status-bar discovery failures.

## Build and deployment

Requires CMake 3.21+, C++17, and the host-compatible Qt SDK with Core, Network, Qml and Quick. Non-Windows presets use Ninja; Windows presets use the Visual Studio 2022 generator.

```powershell
cmake --preset dev
cmake --build --preset dev
```

The `dev` preset (or `dev-windows` on Windows) uses a Release build, stages to `dist/`, and enables automatic deployment. Windows uses a separate x64 build directory. The VS Code default Build task configures and builds; **Install plugin (MuseScore user directory)** is an alias. Close MuseScore before replacing its loaded library.

```text
dist/MuseScoreRichPresence/
├── RichPresence.qml
├── current_score_info.png
├── LICENSE
└── DiscordIPC/
    ├── qmldir
    └── libDiscordIPC.dylib
```

The library is `libDiscordIPC.dylib` on macOS and `DiscordIPC.dll` on Windows. The default destination is `Documents/MuseScore4/Plugins/MuseScoreRichPresence/` under the user's home/profile.

- `CMAKE_PREFIX_PATH`: custom Qt SDK location. macOS detects the Qt major/minor version from the MuseScore app bundle and searches `~/Qt`; Windows looks for Qt 6.10.2 MSVC x64 in `QTDIR`, `%USERPROFILE%/Qt`, or `C:/Qt` unless a custom SDK/toolchain is selected.
- `MUSESCORE_APP`: override the macOS MuseScore app bundle used for Qt detection.
- `MUSESCORE_PLUGINS_DIR`: override the user plugins directory in a local CMake cache or user preset.
- `MUSESCORE_AUTO_DEPLOY=OFF`: packaging-only build; use the staged directory.
- macOS defaults to deployment target 13.0 (Qt 6.10's minimum), independently of the build SDK. Explicit nonempty deployment targets or environment overrides take precedence. Reconfigure older caches with `-DCMAKE_OSX_DEPLOYMENT_TARGET=13.0` if needed; inspect the packaged dylib with `vtool -show-build` to confirm both slices.
- macOS selects the active Xcode compiler. Preserve the SDK 27.2 / Apple Clang 21 fallback to SDK 26.5 when installed; explicit compiler and SDK settings take precedence.

### Windows development

Install Visual Studio 2022 (or Build Tools) with Desktop development with C++, a Windows SDK, CMake, and the MSVC v143 x64 target tools (including on ARM64 Windows). The Windows presets use the Visual Studio generator with an explicit x64 target and Release configuration; a Developer PowerShell is not required. Official MuseScore Studio 4.7 Windows releases are x64 only. Windows 11 ARM64 runs that host through x64 emulation, so use the same x64 plugin there. Windows DLLs are not macOS-style universal binaries; do not build a native ARM64 plugin for an x64 MuseScore process. The official Qt 6.10.2 MSVC x64 SDK is preferred to match MuseScore 4.7. For example:

```powershell
uvx --from aqtinstall aqt install-qt windows desktop 6.10.2 win64_msvc2022_64 -O "$HOME/Qt"
cmake --preset dev-windows
cmake --build --preset dev-windows
```

Alternatively, use vcpkg with the repository manifest. It pins the 2026.03.18 baseline containing Qt 6.10.2 and uses the shared `x64-windows` triplet, so the module can link against host Qt. Set up vcpkg once in a separate directory:

```powershell
git clone --branch 2026.03.18 https://github.com/microsoft/vcpkg.git "$HOME/vcpkg"
& "$HOME/vcpkg/bootstrap-vcpkg.bat" -disableMetrics
$env:VCPKG_ROOT = "$HOME/vcpkg"
```

From the plugin repository, configure and build with `dev-vcpkg` or `release-vcpkg`. CMake's vcpkg toolchain installs dependencies automatically. The vcpkg Qt build can take substantial time; its runtime compatibility with MuseScore has not been established. Never redistribute vcpkg Qt or its dependency DLLs alongside the plugin; the host supplies Qt. The presets disable vcpkg app-local dependency copying. Official Qt is preferred for public releases until the alternative is verified.

### Release packaging

```powershell
cmake --preset release
cmake --build --preset release
```

The `release` preset on macOS and `release-windows` preset on Windows use separate build directories and disable user-directory deployment. On Windows, run `cmake --preset release-windows` and `cmake --build --preset release-windows`. Windows explicitly targets MSVC x64 regardless of host architecture; macOS targets both Apple Silicon and Intel by default. The macOS Qt SDK must support both architectures. To target one architecture, override `CMAKE_OSX_ARCHITECTURES` at configure time (e.g. `cmake --preset release -DCMAKE_OSX_ARCHITECTURES=arm64`). The VS Code **Publish plugin** task selects the appropriate platform preset and performs both steps. The release build's explicit `publish` target runs CPack after staging; it is also part of the default release build. Normal `dev` builds do not publish.

CMake stages the complete plugin in `dist/MuseScoreRichPresence/`; CPack independently packages the install manifest into `dist/MuseScoreRichPresence-<version>-macos-universal.zip` (or `-macos-arm64.zip` / `-macos-x64.zip`) on macOS and `dist/MuseScoreRichPresence-<version>-windows-x64.zip` on Windows, with matching `.sha256` checksums. To publish using vcpkg on Windows, run `cmake --preset release-vcpkg` and `cmake --build --preset release-vcpkg`, or the corresponding VS Code task. The ZIP contains the top-level plugin folder and license, without Qt frameworks. On macOS only, sign and verify the installed dylib ad hoc (`codesign --force --sign -`) after install-time RPATH changes, including the isolated CPack install. Do not sign only the build-tree binary. A signature failure must fail packaging. Ad-hoc signing is not Developer ID signing or notarization; downloaded plugins may still encounter Gatekeeper or host library validation. The maintainer verifies the archive in MuseScore before manually attaching it to a GitHub Release.

## Verification

A successful build or Plugins Manager listing does not prove that the native module loaded. Check the status icon, Discord activity and MuseScore logs prefixed with `MuseScore Rich Presence`. Verify selection transitions, playback layout and preference changes in the actual host when relevant. Do not claim untested platform support.
