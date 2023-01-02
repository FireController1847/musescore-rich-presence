import QtQuick 2.2
import QtQuick.Dialogs 1.1
import MuseScore 3.0
import FileIO 3.0

MuseScore {
    version: "1.0"
    title: "Current Score Info"
    description: qsTr("A plugin that outputs the current score's information to a text file in the installation directory")
    categoryCode: "current-score-info"
    thumbnailName: "current_score_info.png"
    onRun: {
        if (Qt.csitimer == undefined || Qt.csitimer == null) {
            Qt.csitimer = csitimer;
            Qt.csitimer.start();
            startedDialog.open();
        } else {
            if (Qt.csitimer.running) {
                Qt.csitimer.stop();
                Qt.csitimer = null;
                stoppedDialog.open();
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
    MessageDialog {
        id: startedDialog
        title: "Plugin Has Been Enabled"
        text: qsTr("The plugin has been enabled.")
        onAccepted: {
            
        }
        visible: false
    }
    MessageDialog {
        id: stoppedDialog
        title: "Plugin Has Been Disabled"
        text: qsTr("The plugin has been disabled.")
        onAccepted: {

        }
        visible: false
    }
    function makeScoreInfo() {
        if (curScore == null) {
            outfile.write("{}");
        } else {
            const score = fetchScoreInfo(curScore, null);
            outfile.write(JSON.stringify(score, null, 2));
        }
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