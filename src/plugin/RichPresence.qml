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
    property double playbackStart: 0
    property double playbackEnd: 0
    property string playbackStateText: ""
    property bool refreshPlaybackText: true

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
            root.refreshPlaybackText = true
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
            root.playbackStart = 0
            root.playbackEnd = 0
            root.refreshPlaybackText = true

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

    function scoreHeading(score, style, metadata, placeholders) {
        // The title printed on the score is a styled Text element in a
        // leading vertical frame, independent of the workTitle meta tag.
        // MeasureBase.prev and frame.elements are exposed since MuseScore 4.6.
        var visibleText = ""
        try {
            var first = score.firstMeasure
            var frame = first ? first.prev : null
            while (frame) {
                if (frame.type === Element.VBOX) {
                    var elements = frame.elements
                    for (var i = 0; i < elements.length; i++) {
                        var element = elements[i]
                        if (element.type === Element.TEXT && Number(element.subStyle) === Number(style)) {
                            var text = discord.plainScoreText(String(element.text || ""))
                            if (text && placeholders.indexOf(text.toLowerCase()) === -1) {
                                // Traversing backwards makes the topmost frame win.
                                visibleText = text
                                break
                            }
                        }
                    }
                }
                frame = frame.prev
            }
        } catch (error) {
            // Older MuseScore versions may not expose frame traversal.
            // Fall back to meaningful metadata rather than failing presence.
        }
        if (visibleText)
            return visibleText

        var fallback = String(metadata || "").trim()
        return placeholders.indexOf(fallback.toLowerCase()) === -1 ? fallback : ""
    }

    function formatPlaybackTime(ms) {
        var seconds = Math.max(0, Math.floor(ms / 1000))
        var hours = Math.floor(seconds / 3600)
        var minutes = Math.floor(seconds / 60) % 60
        var remainder = seconds % 60
        return (hours ? hours + ":" + (minutes < 10 ? "0" : "") : "")
                + minutes + ":" + (remainder < 10 ? "0" : "") + remainder
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
                playbackStart = 0
                playbackEnd = 0
                refreshPlaybackText = true
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
                    type: 0,
                    status_display_type: 0,
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
            playbackStart = 0
            playbackEnd = 0
            refreshPlaybackText = true
        } else if (now >= nextRotation) {
            stateIndex++
            refreshPlaybackText = true
            nextRotation = now + prefs.rotation * 1000
        }

        var playback = prefs.playback ? discord.playbackSnapshot() : ({ known: false })
        var playing = playback.known && playback.playing
        var mode = playing ? "Playing" : "Editing"
        if (mode !== activityMode) {
            activityMode = mode
            stateIndex = 0
            nextRotation = now + prefs.rotation * 1000
            playbackStart = 0
            playbackEnd = 0
            refreshPlaybackText = true
        }

        var title = scoreHeading(score, Tid.TITLE, score.title || score.metaTag("workTitle"),
                                 ["untitled score", "untitled", "title"])
        var subtitle = scoreHeading(score, Tid.SUBTITLE, score.metaTag("subtitle"), ["subtitle"])
        var composer = scoreHeading(score, Tid.COMPOSER, score.composer || score.metaTag("composer"),
                                    ["composer / arranger", "composer", "arranger"])
        var filename = name.replace(/\\/g, "/").split("/").pop()
        if (!/\.mscz$/i.test(filename))
            filename = filename.replace(/\.mscx$/i, "") + ".mscz"

        // Filename sharing is opt-in, even for the primary details line.
        var displayName = prefs.title && title ? title : (prefs.filename ? filename : "")
        var details = displayName ? activityMode + " " + displayName
                                  : (playing ? "Playing a score" : "Composing")

        var states = []
        if (!playing) {
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

        } else {
            if (prefs.playMeasure && playback.measure > 0) {
                var measure = "Measure " + playback.measure
                if (playback.measures > 0)
                    measure += " of " + playback.measures
                if (playback.beat > 0)
                    measure += " · Beat " + playback.beat
                states.push(measure)
            }
            if (prefs.playTime && playback.position >= 0) {
                var time = formatPlaybackTime(playback.position)
                if (playback.duration > 0)
                    time += " / " + formatPlaybackTime(playback.duration)
                states.push(time)
            }
            if (prefs.playTempo && playback.bpm > 0)
                states.push(playback.bpm + " BPM")
        }

        var activity = {
            type: playing && prefs.playProgress ? 2 : 0,
            status_display_type: 0,
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
            if (playing) {
                if (refreshPlaybackText || !playbackStateText)
                    playbackStateText = bounded(states[stateIndex])
                activity.state = playbackStateText
            } else {
                activity.state = bounded(states[stateIndex])
            }
        } else {
            stateIndex = 0
            playbackStateText = ""
        }
        refreshPlaybackText = false

        if (playing) {
            if (prefs.playProgress && playback.position >= 0
                    && playback.duration > playback.position) {
                // Anchor the clock to the actual transport position. Reuse
                // the same timestamps until seeking, looping or a duration
                // change makes them inaccurate; avoid sending a new frame
                // every second merely because the clock has advanced.
                var start = (now - playback.position) / 1000
                var end = start + playback.duration / 1000
                if (!playbackStart || Math.abs(start - playbackStart) > 2
                        || Math.abs(end - playbackEnd) > 2) {
                    playbackStart = Math.round(start)
                    playbackEnd = Math.max(playbackStart + 1, Math.ceil(end))
                    refreshPlaybackText = true
                }
                activity.timestamps = { start: playbackStart, end: playbackEnd }
            } else {
                playbackStart = 0
                playbackEnd = 0
            }
        } else if (prefs.elapsed) {
            activity.timestamps = { start: startedAt }
        }
        discord.setActivity(activity)
    }
}
