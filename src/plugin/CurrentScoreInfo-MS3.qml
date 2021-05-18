import QtQuick 2.0
import MuseScore 3.0
import FileIO 3.0

MuseScore {
    menuPath: "Plugins.Start Current Score Info"
    description: "A plugin that outputs the current score's information to a text file in the installation directory"
    version: "1.0.0"
    requiresScore: true
    onRun: {
        if (Qt.csitimer == undefined || Qt.csitimer == null) {
            Qt.csitimer = csitimer;
            Qt.csitimer.start();
        } else {
            if (Qt.csitimer.running) {
                Qt.csitimer.stop();
                Qt.csitimer = null;
            }
        }
    }
    FileIO {
        id: outfile
        source: "../ScoreInfo.json"
        onError: console.log(msg)
    }
    Timer {
        id: csitimer
        interval: 1000
        running: false
        repeat: true
        onTriggered: {
            makeScoreInfo();
        }
    }
    function makeScoreInfo() {
        const score = fetchScoreInfo(curScore, null);
        outfile.write(JSON.stringify(score, null, 2));
    }
    function fetchScoreInfo(obj, score) {
        if (score == null) {
            score = {};
        }
        for (var prop in obj) {
            if (typeof obj[prop] != "function" && typeof obj[prop] != "object") {
                if (typeof obj[prop] == "object") {
                    score[prop] = fetchScoreInfo(obj[prop], score);
                } else {
                    score[prop] = obj[prop];
                }
            }
        }
        return score;
    }
}