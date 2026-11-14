import QtQuick 2.15
import MuseScore 3.0
import QtQuick.Controls 2.15
import QtQuick.Window 2.15

MuseScore {
    id: root
    title: "Discord Rich Presence"
    menuPath: "Plugins.Discord Rich Presence"
    description: qsTr("Display your current score on Discord.")
    version: "2.0"
    categoryCode: "composing"
    requiresScore: false

    property bool enabledPresence: false
    property string lastScore: ""
    property double startedAt: 0
    property int stateIndex: 0

    property var bridge: null
    property var discord: bridge ? bridge.client : null
    property string loadError: ""

    // The legacy loader discovers metadata without loading the module.
    // Load on invocation so native import errors can be shown to the user.
    function loadBridge() {
        if (!bridge) {
            bridge = Qt.createQmlObject(
                'import QtQuick 2.15; import "DiscordIPC" 1.0 as IPC; QtObject { property var client: IPC.DiscordClient }',
                root, Qt.resolvedUrl("DiscordBridge.qml").toString())
        }
    }

    Connections {
        target: root.discord
        function onEnabledChanged() {
            if (!root.discord.enabled) {
                root.enabledPresence = false
                refresh.stop()
            }
        }
    }

    Window {
        id: statusWindow
        title: "Discord Rich Presence"
        width: 420
        height: 150
        flags: Qt.Dialog
        modality: Qt.NonModal
        visible: false

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Label {
                width: parent.width
                wrapMode: Text.Wrap
                text: root.loadError || (root.discord ? root.discord.status : "Not started")
            }
            Button {
                text: "Close"
                onClicked: statusWindow.close()
            }
        }
    }

    Timer {
        id: refresh
        interval: 5000
        repeat: true
        onTriggered: {
            try {
                root.updateActivity()
            } catch (error) {
                console.error("MuseScore Rich Presence: score update failed: " + error)
            }
        }
    }

    onRun: {
        console.log("MuseScore Rich Presence: menu invoked")
        loadError = ""
        try {
            loadBridge()
            if (discord.enabled) {
                discord.stop()
            } else {
                enabledPresence = true
                lastScore = ""
                stateIndex = 0
                startedAt = Math.floor(Date.now() / 1000)
                discord.start("577645453429047314")
                // Publish a fallback before accessing score-specific properties.
                discord.setActivity({
                    details: "MuseScore",
                    state: "Composing",
                    timestamps: { start: startedAt }
                })
                refresh.start()
                updateActivity()
            }
        } catch (error) {
            loadError = String(error)
            console.error("MuseScore Rich Presence: " + loadError)
        }
        statusWindow.show()
    }

    function bounded(value) {
        // Discord limits details and state to 128 characters.
        var result = String(value)
        if (result.length > 128) {
            result = result.substring(0, 128)
            var last = result.charCodeAt(result.length - 1)
            if (last >= 0xD800 && last <= 0xDBFF)
                result = result.substring(0, result.length - 1)
        }
        return result
    }

    function updateActivity() {
        if (!enabledPresence || !discord || !discord.enabled)
            return

        var score = curScore
        var name = score ? String(score.scoreName || "Untitled") : ""
        if (name !== lastScore) {
            lastScore = name
            startedAt = Math.floor(Date.now() / 1000)
            stateIndex = 0
        }

        var details = "MuseScore"
        var state = "Composing"
        var smallText = "Composing"

        if (score) {
            details = "Editing " + name
            var states = []
            var title = score.title || score.metaTag("workTitle")
            var subtitle = score.metaTag("subtitle")
            var composer = score.composer || score.metaTag("composer")

            if (title)
                states.push("Title: " + title)
            if (subtitle)
                states.push("Subtitle: " + subtitle)
            if (composer)
                states.push("Composer: " + composer)

            states.push("Contains " + score.nmeasures + " Measures")
            states.push("Contains " + score.npages + " Pages")
            states.push("Contains " + score.ntracks + " Tracks")
            smallText = "Contains " + score.nmeasures + " Measures"

            stateIndex %= states.length
            state = states[stateIndex]
            stateIndex = (stateIndex + 1) % states.length
        }

        discord.setActivity({
            details: bounded(details),
            state: bounded(state),
            timestamps: { start: startedAt },
            assets: {
                large_image: "musescore4-square",
                small_image: "musescore4-circle",
                large_text: "MuseScore 4",
                small_text: bounded(smallText)
            },
            instance: false
        })
    }
}
