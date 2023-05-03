const wi = require("@arcsine/win-info");
const fp = require("find-process");
const path = require("path");
const fs = require("fs");

const { Client } = require("discord-rpc");
const client = new Client({ transport: "ipc" });

let start = new Date();
let lastfile = "";
let stateindex = 0;
let sheetcache = null;

async function update() {
    const apps = await fp("name", "MuseScore");
    let app;
    for (let i = 0; i < apps.length; i++) {
        if (["MuseScore.exe", "MuseScore2.exe", "MuseScore3.exe", "MuseScore4.exe"].includes(apps[i].name)) {
            app = apps[i];
            break;
        }
    }

    let window;
    if (app) {
        try {
            window = await wi.getByPid(app.pid);
        } catch (e) {
            // ...
        }
    }
    if (window) {
        const currDir = path.join(window.owner.path, "../../ScoreInfo.json");
        if (fs.existsSync(currDir)) {
            try {
                const curr = JSON.parse(fs.readFileSync(currDir));
                // console.log(curr);
                window.sheet = curr;
                if (window.sheet.scoreName != lastfile) {
                    start = new Date();
                    lastfile = window.sheet.scoreName;
                }
            } catch(e) {
                console.log("X Unable to read ScoreInfo.json! Is the file corrupt?")
            }
        } else {
            console.log("X Whoops! I wasn't able to find the ScoreInfo.json. Did you install the CurrentScoreInfo MuseScore plugin?");
        }
    }

    let largeImageKey = "musescore-square";
    let smallImageKey = "musescore-circle";
    let appTitle = "MuseScore";
    if (app.name == "MuseScore3.exe") {
        largeImageKey = "musescore3-square";
        smallImageKey = "musescore3-circle";
        appTitle = "MuseScore 3";
    } else if (app.name == "MuseScore4.exe") {
        largeImageKey = "musescore4-square";
        smallImageKey = "musescore4-circle";
        appTitle = "MuseScore 4";
    }

    if (window && window.sheet || app && !window && sheetcache) {
        if (window && window.sheet) sheetcache = window.sheet;
        else if (sheetcache) {
            window = {};
            window.sheet = sheetcache;
        }
        var states = [];
        if (window.sheet.title) states.push(`Title: ${window.sheet.title}`);
        if (window.sheet.subtitle) states.push(`Subtitle: ${window.sheet.subtitle}`);
        if (window.sheet.composer) states.push(`Composer: ${window.sheet.composer}`);
        states.push(`Contains ${window.sheet.nmeasures} Measures`);
        states.push(`Contains ${window.sheet.npages} Pages`);
        // Possibly unessecary? How does this apply to more than 1 instrument?
        // states.push(`Contains ${window.sheet.nstaves} Staves`);
        states.push(`Contains ${window.sheet.ntracks} Tracks`);
        

        stateindex++;
        if (stateindex >= states.length) stateindex = 0;

        client.setActivity({
            details: `Editing ${window.sheet.scoreName}`,
            state: states[stateindex],
            startTimestamp: start,
            largeImageKey: largeImageKey,
            smallImageKey: smallImageKey,
            largeImageText: appTitle,
            smallImageText: `Contains ${window.sheet.nmeasures} Measures`
        }, (app.pid || null));
    } else {
        client.setActivity({
            details: "Musescore",
            state: "Unknown",
            startTimestamp: start,
            largeImageKey: largeImageKey,
            smallImageKey: smallImageKey,
            largeImageText: appTitle,
            smallImageText: "Composing"
        }, (app.pid || null));
    }
}

update();

client.on("ready", () => {
    console.log("✓ Online and ready to rock!")
    update();
    setInterval(() => {
        update();
    }, 5000);
});

console.log("Connecting...");
client.login({ clientId: "577645453429047314" });

process.on("unhandledRejection", console.error);