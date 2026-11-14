# MuseScore Rich Presence

Display your current MuseScore activity on your Discord profile.

MuseScore Rich Presence connects [MuseScore](https://musescore.org/) with [Discord Rich Presence](https://discord.com/developers/docs/rich-presence/overview), allowing others to see which score you are working on and learn more about your musical projects.

## Features

- Display the current score's name and elapsed editing time.
- Share score metadata, including its title, subtitle, and composer.
- Display the number of measures, pages, and tracks.
- Rotate between score details using **Active States**.
- Display MuseScore artwork alongside the activity.

## Development Status

The project is being revisited to simplify installation and eliminate the external Node.js dependency.

The goal is to provide a self-contained MuseScore plugin that communicates directly with Discord, with cross-platform support where possible. This implementation is currently in development.

The existing implementation still uses a QML plugin and a separate Node.js process on Windows.

## Installation

Installation instructions will be updated as the embedded implementation develops.

For the existing Node.js-based implementation, see the [master branch](https://github.com/FireController1847/musescore-rich-presence/tree/master).

## Examples

Active States rotate through available score information, allowing a single Discord activity to display several different details over time.

![](https://i.imgur.com/9jbFAto.png)
![](https://i.imgur.com/jDGESp9.png)
![](https://i.imgur.com/Z7xH5ku.png)
![](https://i.imgur.com/7sWW6Rw.png)
![](https://i.imgur.com/pJ2ACGV.png)

![](https://i.imgur.com/4QCRN4D.png)
![](https://i.imgur.com/bDRqdES.png)

## AI Assisted Development

Originally developed before the adoption of AI coding agents, MuseScore Rich Presence is now developed collaboratively by **human contributors and AI coding agents**, with human direction, engineering oversight, and review.

All contributions are held to the same standards of correctness, maintainability, security, attribution, and licensing, regardless of how they were produced.

## License and Independence

All rights reserved. See [LICENSE](LICENSE).

MuseScore Rich Presence is an independent project and is not affiliated with or endorsed by MuseScore or Discord.
