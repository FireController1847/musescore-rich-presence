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
    thumbnailName: "current_score_info.png"
    requiresScore: false

    property bool monitoring: false
    property string lastScore: ""
    property double startedAt: 0
    property int stateIndex: 0
    property bool hasScore: false
    property double nextRotation: 0
    property string activityMode: "Editing"
    property bool idlePublished: false

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
        function onPreferencesChanged() {
            if (!root.monitoring)
                return
            root.stateIndex = 0
            root.nextRotation = Date.now() + root.discord.preferences.rotation * 1000
            root.updateSafely()
        }
        function onEnabledChanged() {
            if (!root.monitoring || !root.discord)
                return

            root.hasScore = false
            root.lastScore = ""
            root.stateIndex = 0
            root.nextRotation = 0
            root.activityMode = "Editing"
            root.idlePublished = false

            if (root.discord.enabled) {
                refresh.start()
                root.updateSafely()
            } else {
                refresh.stop()
            }
        }
    }

    Window {
        id: statusWindow
        title: "Discord Rich Presence"
        width: 420
        height: 190
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
                text: "Settings…"
                enabled: !!root.discord
                onClicked: root.discord.openSettings()
            }
            Button {
                text: "Close"
                onClicked: statusWindow.close()
            }
        }
    }

    Timer {
        id: refresh
        interval: 1000
        repeat: true
        onTriggered: root.updateSafely()
    }

    onRun: {
        console.log("MuseScore Rich Presence: menu invoked")
        loadError = ""
        try {
            loadBridge()
            if (discord.initializeMonitor("577645453429047314")) {
                // Only the first QML instance owns score monitoring. The
                // native singleton and status bar can toggle it later.
                monitoring = true
                discord.start("577645453429047314")
            } else {
                discord.toggle()
            }
        } catch (error) {
            loadError = String(error)
            console.error("MuseScore Rich Presence: " + loadError)
        }

        // The notation bar exists only on the score page.
        if (loadError || !discord || (curScore && !discord.statusBarAvailable))
            statusWindow.show()
    }

    function updateSafely() {
        try {
            updateActivity()
        } catch (error) {
            console.error("MuseScore Rich Presence: score update failed: " + error)
        }
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

    onScoreStateChanged: function(state) {
        // Selection-only changes (including selecting a note on pause)
        // are not edits. An actual layout-changing edit ends paused mode.
        if (monitoring && activityMode === "Paused" && state
                && (state.undoRedo || state.instrumentsChanged
                    || (state.startLayoutTick !== undefined && state.startLayoutTick >= 0))) {
            activityMode = "Editing"
            updateSafely()
        }
    }

    function updateActivity() {
        if (!monitoring || !discord || !discord.enabled)
            return

        var prefs = discord.preferences
        var score = curScore
        var now = Date.now()
        if (!score) {
            if (hasScore) {
                hasScore = false
                lastScore = ""
                stateIndex = 0
                nextRotation = 0
                activityMode = "Editing"
                idlePublished = false
            }
            if (prefs.hideWithoutScore) {
                discord.clearActivity()
                idlePublished = false
            } else {
                if (!idlePublished) {
                    startedAt = Math.floor(now / 1000)
                    idlePublished = true
                }
                var idle = {
                    details: "Browsing scores",
                    assets: { large_image: "musescore4-square", large_text: "MuseScore 4" },
                    instance: false
                }
                if (prefs.elapsed)
                    idle.timestamps = { start: startedAt }
                discord.setActivity(idle)
            }
            return
        }

        idlePublished = false
        var name = String(score.scoreName || "Untitled")
        if (!hasScore || name !== lastScore) {
            hasScore = true
            lastScore = name
            startedAt = Math.floor(now / 1000)
            stateIndex = 0
            nextRotation = now + prefs.rotation * 1000
            activityMode = "Editing"
        } else if (now >= nextRotation) {
            stateIndex++
            nextRotation = now + prefs.rotation * 1000
        }

        if (prefs.playback) {
            var playback = discord.playbackSnapshot()
            if (!playback.known) {
                activityMode = "Editing"
            } else if (playback.playing) {
                activityMode = "Playing"
            } else if (activityMode === "Playing" || activityMode === "Paused") {
                var atEnd = playback.duration > 0 && playback.position >= playback.duration - 100
                activityMode = playback.position > 0 && !atEnd ? "Paused" : "Editing"
            }
        } else {
            activityMode = "Editing"
        }

        var title = String(score.title || score.metaTag("workTitle") || "").trim()
        var subtitle = String(score.metaTag("subtitle") || "").trim()
        var composer = String(score.composer || score.metaTag("composer") || "").trim()
        var filename = name.replace(/\\/g, "/").split("/").pop()
        if (!/\.mscz$/i.test(filename))
            filename = filename.replace(/\.mscx$/i, "") + ".mscz"

        // Filename sharing is opt-in, even for the primary details line.
        var displayName = prefs.title && title ? title : (prefs.filename ? filename : "")
        var details = displayName
                ? (activityMode === "Paused" ? "Paused: " : activityMode + " ") + displayName
                : (activityMode === "Playing" ? "Playing a score"
                   : activityMode === "Paused" ? "Playback paused" : "Composing")

        var states = []
        if (prefs.filename && displayName !== filename)
            states.push("File: " + filename)
        if (prefs.subtitle && subtitle)
            states.push("Subtitle: " + subtitle)
        if (prefs.composer && composer)
            states.push("Composer: " + composer)
        if (prefs.measures)
            states.push("Contains " + score.nmeasures + " Measures")
        if (prefs.pages)
            states.push("Contains " + score.npages + " Pages")
        if (prefs.tracks)
            states.push("Contains " + score.ntracks + " Tracks")

        var activity = {
            details: bounded(details),
            assets: {
                large_image: "musescore4-square",
                small_image: "musescore4-circle",
                large_text: "MuseScore 4",
                small_text: activityMode === "Editing" ? "Composing" : activityMode
            },
            instance: false
        }
        if (states.length) {
            stateIndex %= states.length
            activity.state = bounded(states[stateIndex])
        } else {
            stateIndex = 0
        }
        if (prefs.elapsed)
            activity.timestamps = { start: startedAt }
        discord.setActivity(activity)
    }
}
