# MuseScore Rich Presence
This MuseScore plugin allows users to showcase their current score on their Discord profile through Rich Presence integration. Information such as the score's title, author, composer, and number of measures will be displayed, providing a convenient way for others to see what you're working on and get a glimpse into your musical endeavors. With this plugin, you can easily share your musical creations with your Discord community and showcase your talents to the world.

## Installation & Usage
\* Adding support for Mac should be really easy, but I don't own a Mac to test it on.

### MuseScore 4
1. Install Node.js ([Direct Link](https://nodejs.org/en/))
2. Install the `CurrentScore-MS4.qml` AND `current_score_info.png` Plugin Into MuseScore 4 ([Handbook](https://musescore.org/en/handbook/3/plugins#installation))
3. Open MuseScore 4 and ensure to **run it as an administrator**!
4. When inside MuseScore 4, enable the plugin. Then click on the button once under Plugins -> CurrentScoreInfo to run it.
5. Clone this repository and install node modules (`npm i`)
6. Run rpc.js (`node src/rpc.js`)

### MuseScore 3
1. Install Node.js ([Direct Link](https://nodejs.org/en/))
2. Install the `CurrentScoreInfo-MS3.qml` Plugin Into MuseScore 3 ([Handbook](https://musescore.org/en/handbook/3/plugins#installation))
3. Open MuseScore 3 and ensure to **run it as an administrator**!
4. When inside MuseScore 3, enable the plugin. Then click on the button once under Plugins -> CurrentScoreInfo to run it.
5. Clone this repository and install node modules (`npm i`)
6. Run rpc.js (`node src/rpc.js`)

### MuseScore 2
1. Install Node.js ([Direct Link](https://nodejs.org/en/))
2. Install the `CurrentScoreInfo-MS2.qml` Plugin Into MuseScore 2 ([Handbook](https://musescore.org/en/handbook/2/plugins#installation))
3. Open MuseScore 2 and ensure to **run it as an administrator**!
4. When inside MuseScore 2, enable the plugin. Then click on the button once under Plugins -> CurrentScoreInfo to run it.
5. Clone this repository and install node modules (`npm i`)
6. Run rpc.js (`node src/rpc.js`)

## Examples
\* This plugin uses Active States. Active States is a feature that rotates between multiple rich presence details, creating a dynamic and informative experience for anyone viewing the user's profile.

![](https://i.imgur.com/9jbFAto.png)  
![](https://i.imgur.com/jDGESp9.png)  
![](https://i.imgur.com/Z7xH5ku.png)  
![](https://i.imgur.com/7sWW6Rw.png)  
![](https://i.imgur.com/pJ2ACGV.png)  
  
![](https://i.imgur.com/4QCRN4D.png)
![](https://i.imgur.com/bDRqdES.png)
