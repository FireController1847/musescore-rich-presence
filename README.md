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
> The project is undergoing a redesign to eliminate the external Node.js dependency. The embedded implementation is not yet ready for general use. The existing implementation is available on the [master branch](https://github.com/FireController1847/musescore-rich-presence/tree/master).

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

## Development Status

The next generation of MuseScore Rich Presence aims to simplify installation and run directly within MuseScore.

| Current Implementation | Embedded Implementation (Planned) |
| :--- | :--- |
| QML plugin and external Node.js process | Self-contained MuseScore plugin |
| Intermediate JSON file | Direct access to score information |
| Windows-specific process detection | Platform-independent score tracking |
| Manual companion process startup | Integrated activity management |

Cross-platform Discord communication is a development goal and remains subject to validation.

## Installation

Installation instructions will be updated once the embedded implementation is available.

> [!NOTE]
> For the original Windows implementation and its installation instructions, see the [master branch](https://github.com/FireController1847/musescore-rich-presence/tree/master).

## AI Assisted Development

Originally developed before the adoption of AI coding agents, MuseScore Rich Presence is now developed collaboratively by **human contributors and AI coding agents**, with human direction, engineering oversight, and review.

All contributions are held to the same standards of correctness, maintainability, security, attribution, and licensing, regardless of how they were produced.

## License and Independence

All rights reserved. See [LICENSE](LICENSE).

MuseScore Rich Presence is an independent project and is not affiliated with, endorsed by, or sponsored by MuseScore or Discord.
