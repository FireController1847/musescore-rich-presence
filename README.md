<h1 align="center">MuseScore Rich Presence</h1>

<p align="center">
  <strong>Share what you're composing, right from MuseScore.</strong>
</p>

<p align="center">
  <em>Bring your musical projects to life on your Discord profile with real-time score information.</em>
</p>

<p align="center">
  <a href="https://musescore.org/"><img src="https://img.shields.io/badge/MuseScore-Studio-1a70b8?style=flat-square" alt="MuseScore Studio"></a>
  <a href="https://discord.com/"><img src="https://img.shields.io/badge/Discord-Rich%20Presence-5865F2?style=flat-square&amp;logo=discord&amp;logoColor=white" alt="Discord Rich Presence"></a>
  <img src="https://img.shields.io/badge/Language-QML-41CD52?style=flat-square&amp;logo=qt&amp;logoColor=white" alt="QML">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-All%20Rights%20Reserved-526b80?style=flat-square" alt="All Rights Reserved"></a>
</p>

<p align="center">
  <a href="#features">Features</a> &bull;
  <a href="#preview">Preview</a> &bull;
  <a href="#installation">Installation</a> &bull;
  <a href="#ai-assisted-development">Development</a>
</p>

> [!IMPORTANT]
> The native implementation is experimental and targets MuseScore 4. Discord activity has been verified on macOS by the project maintainer; other platforms remain unverified. The original Node.js implementation remains available on the [master branch](https://github.com/FireController1847/musescore-rich-presence/tree/master).

## About

MuseScore Rich Presence integrates [MuseScore](https://musescore.org/) with Discord, displaying your current score, musical details, and editing session through Rich Presence.

Whether you're composing, arranging, or transcribing, your Discord profile can reflect the music you're working on.

## Features

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>🎼 Current Score</h3>
      Display the name of the score you're editing, directly on your Discord profile.
    </td>
    <td width="50%" valign="top">
      <h3>🎵 Musical Details</h3>
      Showcase the score's title, subtitle, composer, measure count, page count, and track count.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🔄 Active States</h3>
      Automatically cycle through available score details to make your activity more dynamic.
    </td>
    <td width="50%" valign="top">
      <h3>⏱️ Editing Sessions</h3>
      Display elapsed time for the current score, alongside MuseScore artwork.
    </td>
  </tr>
</table>

## Preview

<p align="center">
  <img src="https://i.imgur.com/9jbFAto.png" width="270" alt="Rich Presence example 1">
  <img src="https://i.imgur.com/jDGESp9.png" width="270" alt="Rich Presence example 2">
  <img src="https://i.imgur.com/Z7xH5ku.png" width="270" alt="Rich Presence example 3">
</p>
<p align="center">
  <img src="https://i.imgur.com/7sWW6Rw.png" width="270" alt="Rich Presence example 4">
  <img src="https://i.imgur.com/pJ2ACGV.png" width="270" alt="Rich Presence example 5">
</p>
<p align="center">
  <img src="https://i.imgur.com/4QCRN4D.png" width="270" alt="Rich Presence example 6">
  <img src="https://i.imgur.com/bDRqdES.png" width="270" alt="Rich Presence example 7">
</p>

<p align="center"><em>Examples from the original implementation, showcasing rotating score information.</em></p>

## Architecture

The plugin reads score information directly from MuseScore using QML. A small native Qt extension handles Discord IPC using `QLocalSocket`, including connection discovery, handshake, framing, reconnection, and activity cleanup.

| QML | Native Qt extension |
| :--- | :--- |
| Score tracking and elapsed time | Discord socket discovery |
| Active States and activity payloads | IPC handshake and frame processing |
| Enable/disable toggle | Activity publication and reconnection |

No Node.js, intermediate JSON files, external companion processes, or administrator privileges are required by the new design. The native extension must be built for the Qt version and architecture used by MuseScore. Windows and Unix socket discovery are implemented, but platform compatibility remains unverified.

## Installation

### Build from source

Requires CMake 3.21+, Ninja, a C++17 compiler, and a Qt development SDK with Core, Network, Qml, and Widgets matching your MuseScore installation.

Open the folder in VS Code and install the recommended CMake Tools extension. CMake configures automatically using the `dev` preset; **Build** (or the default Build task) stages the plugin into `dist/`.

On macOS, the build detects MuseScore's bundled Qt major/minor version and searches the standard `~/Qt` SDK directory. Install the matching SDK once if needed. For example, for MuseScore using Qt 6.10.2:

```powershell
uvx --from aqtinstall aqt install-qt mac desktop 6.10.2 clang_64 -O "$HOME/Qt"
```

A custom Qt SDK can be selected with `-DCMAKE_PREFIX_PATH=/path/to/qt`. The macOS configuration also selects the active Xcode compiler and works around the known SDK 27.2 / Clang 21 mismatch when SDK 26.5 is installed. Existing custom build settings take precedence.

Outside VS Code:

```powershell
cmake --preset dev
cmake --build --preset dev
```

The staged plugin directory contains:

```text
dist/MuseScoreRichPresence/
├── RichPresence.qml
├── current_score_info.png
└── DiscordIPC/
    ├── qmldir
    └── libDiscordIPC.dylib
```

The native library has a platform-specific extension. Copy the entire `MuseScoreRichPresence` directory into your MuseScore user plugins directory (shown in MuseScore's preferences). Preserve the directory structure.

Alternatively, use the VS Code task **Install plugin (MuseScore user directory)** to build and install directly into the default user plugin directory. Change the destination if your MuseScore preferences use a different path.

Quit MuseScore before replacing the native library. Open Discord Desktop, restart MuseScore, enable the plugin in the Plugins Manager, and invoke **Discord Rich Presence** from the Plugins menu. A native menu bar/status tray icon appears after activation on supported desktops. Its check mark indicates accepted activity, an ellipsis indicates waiting or connecting, and a slash indicates disabled. Click the icon to view the current status or enable/disable Rich Presence. The top-level Plugins menu action also toggles it. A status dialog remains available as a fallback on desktops without a tray, or if the native module fails to load.

MuseScore requires the plugin to be invoked once per application session. After activation, it automatically publishes when a score is opened or selected, clears activity when no score is open, and resets the elapsed timer for a different score. MuseScore's plugin manager does not provide an automatic startup hook for legacy QML plugins.

If no activity appears, inspect the tray menu (or fallback status window) and MuseScore's application logs for `MuseScore Rich Presence` messages. Listing the plugin in the manager alone does not establish that its native module loaded. Check that Discord activity sharing is enabled and that the Qt SDK version and architecture match MuseScore.

> [!NOTE]
> For the original Windows implementation and its installation instructions, see the [master branch](https://github.com/FireController1847/musescore-rich-presence/tree/master).

## AI Assisted Development

Originally developed before the adoption of AI coding agents, MuseScore Rich Presence is now developed collaboratively by **human contributors and AI coding agents**, with human direction, engineering oversight, and review.

All contributions are held to the same standards of correctness, maintainability, security, attribution, and licensing, regardless of how they were produced.

## License and Independence

All rights reserved. See [LICENSE](LICENSE).

MuseScore Rich Presence is an independent project and is not affiliated with, endorsed by, or sponsored by MuseScore or Discord.
