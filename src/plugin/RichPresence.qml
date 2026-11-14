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

    function measureAt(score, number) {
        if (number < 1)
            return null
        var measure = score.firstMeasure
        for (var i = 1; measure && i < number; i++)
            measure = measure.nextMeasure
        return measure
    }

    function systemAt(score, measure) {
        if (!measure)
            return 0
        try {
            var tick = measure.tick.ticks
            var systems = score.systems
            var number = 0
            for (var i = 0; i < systems.length; i++) {
                var first = systems[i].firstMeasure
                var last = systems[i].lastMeasure
                if (!first || !last)
                    continue
                number++
                if (tick >= first.tick.ticks && tick < last.tick.ticks + last.ticks.ticks)
                    return number
            }
        } catch (error) {
            // Keep the measure number when the layout is unavailable.
        }
        return 0
    }

    function playbackSegment(measure, playback) {
        if (!measure)
            return null
        var segment = measure.firstSegment
        if (!segment)
            return null
        // Beat position is internal only; it locates the dynamic marking.
        var denominator = measure.timesigNominal.denominator
        var tick = measure.tick.ticks + Math.max(0, playback.beat - 1)
                   * division * 4 / Math.max(1, denominator)
        while (segment.nextInMeasure && segment.nextInMeasure.tick <= tick)
            segment = segment.nextInMeasure
        return segment
    }

    function selectedPosition(score) {
        var selection = score.selection
        if (!selection)
            return null
        if (selection.isRange && selection.startSegment)
            return { segment: selection.startSegment, staff: selection.startStaff }
        var elements = selection.elements
        if (!elements || !elements.length)
            return null
        var item = elements[0]
        var staff = item.staffIdx
        for (var i = 0; item && i < 16; i++, item = item.parent) {
            if (item.type === Element.SEGMENT)
                return { segment: item, staff: staff }
        }
        return null
    }

    function dynamicName(value) {
        var levels = ["PPPPPP", "PPPPP", "PPPP", "PPP", "PP", "P", "MP",
                      "MF", "F", "FF", "FFF", "FFFF", "FFFFF", "FFFFFF", "N"]
        for (var i = 0; i < levels.length; i++) {
            if (Number(value) === Number(DynamicType[levels[i]]))
                return levels[i].toLowerCase()
        }
        return ""
    }

    function dynamicsAt(score, measure, playback, playing) {
        try {
            var position = playing ? null : selectedPosition(score)
            var staff = position ? position.staff : -1
            var segment = position ? position.segment : playbackSegment(measure, playback)
            if (!segment && !playing && !playback.known)
                return ""
            if (!segment)
                return ""
            // Use the most recent explicit sustained level. With no staff
            // selection, choose the topmost marked staff at that position.
            while (segment) {
                var annotations = segment.annotations
                var level = ""
                var topStaff = Infinity
                for (var i = 0; i < annotations.length; i++) {
                    var item = annotations[i]
                    if (item.type !== Element.DYNAMIC || (staff >= 0 && item.staffIdx !== staff))
                        continue
                    var name = dynamicName(item.dynamicType)
                    if (name && item.staffIdx < topStaff) {
                        level = name
                        topStaff = item.staffIdx
                    }
                }
                if (level)
                    return level
                segment = segment.prev
            }
        } catch (error) {
            // Dynamics are optional when the score API cannot resolve them.
        }
        return ""
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
                    assets: { large_image: "musescore4", large_text: "MuseScore 4" },
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

        var playback = (prefs.playback || prefs.editDynamics) ? discord.playbackSnapshot() : ({ known: false })
        var playing = prefs.playback && playback.known && playback.playing
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
        var author = String(score.metaTag("arranger") || score.lyricist || score.metaTag("lyricist") || score.metaTag("author") || "").trim()
        if (["arranger", "lyricist", "author", "composer / arranger"].indexOf(author.toLowerCase()) !== -1)
            author = ""
        var filename = name.replace(/\\/g, "/").split("/").pop()
        if (!/\.mscz$/i.test(filename))
            filename = filename.replace(/\.mscx$/i, "") + ".mscz"

        // Filename sharing is opt-in, even for the primary details line.
        var displayName = prefs.title && title ? title : (prefs.filename ? filename : "")
        var details = displayName ? activityMode + " " + displayName + (playing ? "" : "...")
                                  : (playing ? "Playing a score" : "Composing...")

        var listening = playing && prefs.playProgress
        var currentMeasure = playback.known ? measureAt(score, playback.measure) : null
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
            if (prefs.editDynamics) {
                var editLevel = dynamicsAt(score, currentMeasure, playback, false)
                if (editLevel)
                    states.push("Dynamics: " + editLevel)
            }

        } else {
            var location = []
            if (prefs.playMeasure && playback.measure > 0)
                location.push("Measure " + playback.measure)
            if (prefs.playSystem) {
                var system = systemAt(score, currentMeasure)
                if (system > 0)
                    location.push("System " + system)
            }
            if (location.length)
                states.push(location.join(" · "))
            if (prefs.playTempo && playback.bpm > 0)
                states.push(playback.bpm + " BPM")
            if (prefs.playDynamics) {
                var playLevel = dynamicsAt(score, currentMeasure, playback, true)
                if (playLevel)
                    states.push("Dynamics: " + playLevel)
            }
        }

        var activity = {
            type: playing && prefs.playProgress ? 2 : 0,
            status_display_type: 0,
            details: bounded(details),
            assets: {
                large_image: "musescore4",
                large_text: "MuseScore 4"
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
        // Listening uses the music layout: title, author, rotating stats,
        // and progress. Discord renders large_text as the album line.
        if (listening) {
            var listeningTitle = bounded(displayName || "Untitled score")
            activity.name = listeningTitle
            activity.details = listeningTitle
            var rotating = activity.state || ""
            delete activity.state
            if (rotating)
                activity.assets.large_text = rotating
            else
                delete activity.assets.large_text

            // A visible subtitle can contain the arrangement credit.
            var subtitleCredit = prefs.subtitle && /\bby\b/i.test(subtitle) ? subtitle : ""
            var credit = prefs.composer ? (author || subtitleCredit || composer) : ""
            if (credit)
                activity.state = bounded(credit)
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
