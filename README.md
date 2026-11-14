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
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache%202.0-526b80?style=flat-square" alt="Apache 2.0"></a>
</p>

<p align="center">
  <a href="#preview">Preview</a> &bull;
  <a href="#installation">Installation</a> &bull;
  <a href="#ai-assisted-development">Development</a>
</p>

> [!NOTE]
> This is the new version of MuseScore Rich Presence for MuseScore Studio 4. If you are looking for an older version, see the [previous branch](https://github.com/FireController1847/musescore-rich-presence/tree/previous).

## About

MuseScore Rich Presence integrates [MuseScore](https://musescore.org/) with Discord, displaying your current score, musical details, and editing session through Rich Presence.

Whether you're composing, arranging, or transcribing, your Discord profile can reflect the music you're working on.

## Preview

<p align="center">
  <img src="https://i.imgur.com/l88zb4H.png" width="270" alt="Rich Presence example 1">
  <img src="https://i.imgur.com/ygCtOAM.png" width="270" alt="Rich Presence example 2">
  <img src="https://i.imgur.com/Izgtps5.png" width="270" alt="Rich Presence example 3">
</p>

<table align="center">
  <thead>
    <tr><th>#</th><th>Viewing</th><th>Editing</th><th>Listening</th></tr>
  </thead>
  <tbody>
    <tr><td>1</td><td>Measures</td><td>Measure · Staff</td><td>System · Page</td></tr>
    <tr><td>2</td><td>Systems</td><td>Dynamics · BPM</td><td>Dynamics · BPM</td></tr>
    <tr><td>3</td><td>Staves</td><td>Key · Time Signature</td><td>Key · Time Signature</td></tr>
    <tr><td>4</td><td>Pages</td><td>Instrument</td><td>Instrument · Sustained¹</td></tr>
  </tbody>
</table>

¹ Sustained appears only when an active pedal marking is detected. Playing without the progress bar uses the same rotations, except for sustain detection.

## Installation

The native plugin targets MuseScore Studio 4.7 and requires Discord Desktop. It runs directly inside MuseScore without Node.js or an external companion application.

### Install from GitHub Releases

1. Download the ZIP for your operating system from the [latest release](https://github.com/FireController1847/musescore-rich-presence/releases/latest):
   - **macOS:** `MuseScoreRichPresence-<version>-macos-universal.zip` (Apple Silicon and Intel)
   - **Windows:** `MuseScoreRichPresence-<version>-windows-x64.zip`
2. Close MuseScore.
3. Extract the `MuseScoreRichPresence` folder into your MuseScore plugins directory (normally `Documents/MuseScore4/Plugins/`). If updating, replace the existing plugin folder.
4. Open MuseScore and follow the [instructions below](#enable-the-plugin) to enable the plugin.

The native plugin targets MuseScore Studio 4.7. macOS builds target macOS 13 or later; Windows uses the x64 MuseScore build, including when running under emulation on Windows 11 ARM64. Only download a release asset for a supported platform.

### Build from source

You'll need CMake 3.21 or newer, a C++17 compiler, and a Qt development SDK matching the version and architecture bundled with MuseScore. On macOS, also install Ninja.

On macOS, the build looks for the matching Qt SDK in `~/Qt`. For example, if MuseScore uses Qt 6.10.2, you can install it with:

```powershell
uvx --from aqtinstall aqt install-qt mac desktop 6.10.2 clang_64 -O "$HOME/Qt"
```

On Windows, install Visual Studio 2022 Build Tools with Desktop development with C++, MSVC x64 target tools and the Qt 6.10.2 MSVC x64 SDK, even on ARM64. The SDK can also be installed using vcpkg; see [Windows build setup](AGENTS.md#windows-development).

Close MuseScore before building. In VS Code, install the recommended CMake Tools extension and run the default **Build** task, or use the command line:

```powershell
cmake --preset dev
cmake --build --preset dev
```

On Windows:

```powershell
cmake --preset dev-windows
cmake --build --preset dev-windows
```

The build stages the plugin in `dist/MuseScoreRichPresence/` and automatically installs it in your user plugins directory (normally `Documents/MuseScore4/Plugins/`).

If your installation uses a different Qt SDK or plugins directory, see [build configuration](AGENTS.md#build-and-deployment). To create a distributable macOS or Windows ZIP in `dist/` instead of installing locally, run the VS Code **Publish plugin** task or use the [release preset](AGENTS.md#release-packaging). Windows runtime compatibility is not yet verified.

## Using Rich Presence

### Enable the plugin

1. Open Discord Desktop and make sure activity sharing is enabled.
2. Open MuseScore and enable **Discord Rich Presence** in the Plugins Manager.
3. Select **Discord Rich Presence** from the Plugins menu.

The plugin needs to be started once each time you launch MuseScore. After that, it follows your active score automatically.

Once enabled, a Discord icon appears in the notation status bar:

- **Click** to enable or disable Rich Presence.
- **Right-click** to open settings.
- **Hover** to see the connection status.

A dimmed icon indicates that the plugin is waiting or connecting; a crossed-out icon indicates that it is disabled.

### Activity

Your Discord presence changes automatically depending on what you're doing:

| Activity | What Discord displays |
| :--- | :--- |
| Viewing | Score totals when nothing is selected. |
| Editing | Musical details at your selection. |
| Listening | Score title, author, live musical details, and a playback progress bar. |
| Playing | Live musical details without a progress bar, when the bar is disabled. |

When no score is open, your activity is hidden by default. You can choose to show that you're browsing scores instead.

### Personalize your presence

Right-click the Discord icon to choose which score details appear, how often they rotate, and whether to show elapsed time or playback progress. Changes are saved automatically.

The plugin prefers the title and credits printed on your score. Hover over the small activity icon in Discord to see the subtitle, composer and lyricist. Filename fallback is enabled by default and only used when a title is unavailable. Missing information is skipped. During playback, musical details refer to a representative instrument in the score.

## Troubleshooting

- **Plugin missing:** Check MuseScore's configured plugins directory and enable all categories in the Plugins Manager.
- **No Discord activity:** Make sure Discord Desktop is running and activity sharing is enabled. Hover over the status icon to check the connection.
- **Plugin fails to start:** Verify that the Qt SDK matches MuseScore's Qt version and architecture. MuseScore's logs contain messages prefixed with `MuseScore Rich Presence`.

For development and implementation details, see [AGENTS.md](AGENTS.md).

## AI Assisted Development

Originally developed before the adoption of AI coding agents, MuseScore Rich Presence is now developed collaboratively by **human contributors and AI coding agents**, with human direction, engineering oversight, and review.

All contributions are held to the same standards of correctness, maintainability, security, attribution, and licensing, regardless of how they were produced.

## License and Independence

Licensed under the [Apache License, Version 2.0](LICENSE). The Discord outline SVGs are adapted from [Simple Icons](https://github.com/simple-icons/simple-icons/blob/develop/icons/discord.svg) (CC0); Discord trademarks remain the property of their respective owner.

MuseScore Rich Presence is an independent project and is not affiliated with, endorsed by, or sponsored by MuseScore or Discord.
