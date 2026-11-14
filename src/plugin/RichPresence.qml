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
    property string activityMode: "Viewing"
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
            root.activityMode = "Viewing"
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

    function singleLine(value) {
        // Treat CRLF as one newline; preserve consecutive line breaks.
        return String(value || "").replace(/\r\n|[\r\n\u0085\u2028\u2029]/g, " ")
    }

    function bounded(value) {
        // Discord limits details and state to 128 characters.
        var result = singleLine(value)
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
                            if (text.trim() && placeholders.indexOf(text.trim().toLowerCase()) === -1) {
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

        var fallback = singleLine(metadata)
        return fallback.trim() && placeholders.indexOf(fallback.trim().toLowerCase()) === -1 ? fallback : ""
    }

    function measureAt(score, number) {
        if (number < 1)
            return null
        var measure = score.firstMeasure
        for (var i = 1; measure && i < number; i++)
            measure = measure.nextMeasure
        return measure
    }

    function layoutAt(score, measure) {
        var result = { system: 0, page: 0 }
        if (!measure)
            return result
        try {
            var tick = measure.tick.ticks
            var systems = score.systems
            var number = 0
            for (var i = 0; i < systems.length; i++) {
                var system = systems[i]
                var first = system.firstMeasure
                var last = system.lastMeasure
                if (!first || !last)
                    continue
                number++
                if (tick < first.tick.ticks || tick >= last.tick.ticks + last.ticks.ticks)
                    continue
                result.system = number
                var pages = score.pages
                for (var p = 0; p < pages.length; p++) {
                    var pageSystems = pages[p].systems
                    for (var j = 0; j < pageSystems.length; j++) {
                        if (pageSystems[j].is(system)) {
                            result.page = pages[p].pageNumber + 1 + score.pageNumberOffset
                            return result
                        }
                    }
                }
                break
            }
        } catch (error) {
            // Logical measure information remains usable without page layout.
        }
        return result
    }

    function systemCount(score) {
        try {
            var count = 0
            var systems = score.systems
            for (var i = 0; i < systems.length; i++)
                if (systems[i].firstMeasure && systems[i].lastMeasure)
                    count++
            return count
        } catch (error) {
            return 0
        }
    }

    function playbackSegment(measure, playback) {
        if (!measure)
            return null
        var segment = measure.firstSegment
        if (!segment)
            return null
        var denominator = measure.timesigNominal.denominator
        var tick = measure.tick.ticks + Math.max(0, playback.beat - 1)
                   * division * 4 / Math.max(1, denominator)
        while (segment.nextInMeasure && segment.nextInMeasure.tick <= tick)
            segment = segment.nextInMeasure
        return segment
    }

    function hasSelection(score) {
        var selection = score.selection
        return !!(selection && (selection.isRange ||
                  (selection.elements && selection.elements.length > 0)))
    }

    function selectedPosition(score) {
        var selection = score.selection
        if (!selection)
            return null
        if (selection.isRange && selection.startSegment)
            return { segment: selection.startSegment, measure: selection.startSegment.parent,
                     track: selection.startStaff * 4, staff: selection.startStaff }
        var elements = selection.elements
        if (!elements || !elements.length)
            return null
        var item = elements[0]
        var track = item.track
        var staff = item.staffIdx
        var segment = null
        var measure = null
        for (var i = 0; item && i < 16; i++, item = item.parent) {
            if (item.type === Element.SEGMENT)
                segment = item
            if (item.type === Element.MEASURE) {
                measure = item
                break
            }
        }
        if (!segment && !measure)
            return null
        if (!segment && measure)
            segment = measure.firstSegment
        return { segment: segment, measure: measure, track: track, staff: staff }
    }

    function playbackTrack(score, segment) {
        // Transport is score-wide: use the first track with a chord at the
        // current or latest notation position in the measure; otherwise a rest.
        var rest = -1
        for (var s = segment; s; s = s.prevInMeasure) {
            for (var track = 0; track < score.ntracks; track++) {
                var item = s.elementAt(track)
                if (item && item.type === Element.CHORD)
                    return track
                if (rest < 0 && item && item.type === Element.REST)
                    rest = track
            }
        }
        return rest
    }

    function keyName(score, staff, segment) {
        if (!staff || !segment || !staff.isPitchedStaff(segment.fraction))
            return ""
        var key = Number(staff.key(segment.fraction))
        if (key < -7 || key > 7)
            return ""
        var major = ["C♭", "G♭", "D♭", "A♭", "E♭", "B♭", "F", "C",
                     "G", "D", "A", "E", "B", "F♯", "C♯"]
        var minor = ["A♭", "E♭", "B♭", "F", "C", "G", "D", "A",
                     "E", "B", "F♯", "C♯", "G♯", "D♯", "A♯"]
        var mode = -1
        for (var s = segment; s; s = s.prev) {
            var item = s.elementAt(staff.idx * 4)
            if (item && item.type === Element.KEYSIG && !item.trailer) {
                mode = Number(item.keysig_mode)
                break
            }
        }
        if (mode === 1 || mode === 8)
            return major[key + 7] + " Major"
        if (mode === 2 || mode === 7)
            return minor[key + 7] + " Minor"
        // Other modes share the same signature; derive the correctly spelled
        // tonic from its major scale rather than guessing from the notes.
        var modes = { 3: [1, "Dorian"], 4: [2, "Phrygian"], 5: [3, "Lydian"],
                      6: [4, "Mixolydian"], 9: [6, "Locrian"] }
        if (modes[mode]) {
            var letters = "CDEFGAB"
            var tonic = letters[(letters.indexOf(major[key + 7][0]) + modes[mode][0]) % 7]
            var accidentalOrder = key < 0 ? "BEADGCF" : "FCGDAEB"
            if (accidentalOrder.substring(0, Math.abs(key)).indexOf(tonic) !== -1)
                tonic += key < 0 ? "♭" : "♯"
            return tonic + " " + modes[mode][1]
        }
        // Display heuristic only when no explicit mode is available:
        // flats imply minor, sharps (and no accidentals) imply major.
        return key < 0 ? minor[key + 7] + " Minor" : major[key + 7] + " Major"
    }

    function positionInfo(score, measure, segment, track, playback, playing) {
        var info = { measure: 0, system: 0, staff: 0, page: 0,
                     dynamics: "", bpm: 0, key: "", time: "", instrument: "" }
        if (!measure)
            return info
        info.measure = playing ? playback.measure : measure.no + 1
        var layout = layoutAt(score, measure)
        info.system = layout.system
        info.page = layout.page
        var staff = null
        if (track >= 0 && track < score.ntracks) {
            staff = score.staves[Math.floor(track / 4)]
            if (staff)
                info.staff = staff.idx + 1
        }
        try {
            var signature = staff && segment ? staff.timeSig(segment.fraction) : null
            var fraction = signature ? signature.timesig : measure.timesigNominal
            if (fraction && fraction.denominator > 0)
                info.time = fraction.numerator + "/" + fraction.denominator
        } catch (error) {}
        if (!segment)
            return info
        try {
            info.dynamics = dynamicsAt(segment, staff ? staff.idx : -1)
        } catch (error) {}
        try {
            if (playing && playback.bpm > 0) {
                info.bpm = playback.bpm
            } else if (track >= 0 && track < score.ntracks) {
                var cursor = score.newCursor()
                cursor.track = track
                // Exact existing segment, independent cursor: do not change selection.
                cursor.filter = segment.segmentType
                cursor.rewindToFraction(segment.fraction)
                if (cursor.segment && cursor.tick === segment.tick)
                    info.bpm = Math.round(cursor.tempo * 60)
            }
        } catch (error) {}
        try {
            info.key = keyName(score, staff, segment)
        } catch (error) {}
        try {
            if (staff && staff.part)
                info.instrument = discord.plainScoreText(staff.part.instrumentNameAtTick(segment.fraction))
        } catch (error) {}
        return info
    }

    function pushRotation(states, fields) {
        var values = []
        for (var i = 0; i < fields.length; i++)
            if (fields[i] && String(fields[i]).trim())
                values.push(singleLine(fields[i]))
        if (values.length)
            states.push(values.join(" · "))
    }

    function dynamicName(value) {
        var levels = {
            PPPPPP: "Pianissississississimo",
            PPPPP: "Pianississississimo",
            PPPP: "Pianissississimo",
            PPP: "Pianississimo",
            PP: "Pianissimo",
            P: "Piano",
            MP: "Mezzo Piano",
            MF: "Mezzo Forte",
            F: "Forte",
            FF: "Fortissimo",
            FFF: "Fortississimo",
            FFFF: "Fortissississimo",
            FFFFF: "Fortississississimo",
            FFFFFF: "Fortissississississimo",
            N: "Niente"
        }
        for (var marking in levels) {
            if (Number(value) === Number(DynamicType[marking]))
                return levels[marking]
        }
        return ""
    }

    function dynamicsAt(segment, staff) {
        try {
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
                activityMode = "Viewing"
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
            activityMode = "Viewing"
            playbackStart = 0
            playbackEnd = 0
            refreshPlaybackText = true
        } else if (now >= nextRotation) {
            stateIndex++
            refreshPlaybackText = true
            nextRotation = now + prefs.rotation * 1000
        }

        var playback = prefs.playback ? discord.playbackSnapshot() : ({ known: false })
        var playing = prefs.playback && playback.known && playback.playing
        var mode = playing ? "Playing" : (hasSelection(score) ? "Editing" : "Viewing")
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
        var lyricist = scoreHeading(score, Tid.LYRICIST, score.lyricist || score.metaTag("lyricist"), ["lyricist"])
        var composer = scoreHeading(score, Tid.COMPOSER, score.composer || score.metaTag("composer"),
                                    ["composer / arranger", "composer", "arranger"])
        var author = singleLine(score.metaTag("arranger") || score.metaTag("author") || "").trim()
        if (["arranger", "lyricist", "author", "composer / arranger"].indexOf(author.toLowerCase()) !== -1)
            author = ""
        var filename = name.replace(/\\/g, "/").split("/").pop()
        if (!/\.mscz$/i.test(filename))
            filename = filename.replace(/\.mscx$/i, "") + ".mscz"

        // Filename sharing is opt-in, even for the primary details line.
        var displayName = prefs.title && title ? title : (prefs.filename ? filename : "")
        var details = playing ? (displayName || "Untitled score")
                              : (displayName ? mode + " " + displayName + "..." : mode + " a score...")

        var listening = playing && prefs.playProgress
        var states = []
        if (mode === "Viewing") {
            if (prefs.filename)
                pushRotation(states, [filename])
            if (prefs.subtitle)
                pushRotation(states, [subtitle])
            if (prefs.lyricist)
                pushRotation(states, [lyricist])
            if (prefs.composer)
                pushRotation(states, [composer])
            var systems = prefs.systems ? systemCount(score) : 0
            if (prefs.measures && score.nmeasures > 0)
                pushRotation(states, [score.nmeasures + (score.nmeasures === 1 ? " Measure" : " Measures")])
            if (systems > 0)
                pushRotation(states, [systems + (systems === 1 ? " System" : " Systems")])
            if (prefs.staves && score.nstaves > 0)
                pushRotation(states, [score.nstaves + (score.nstaves === 1 ? " Staff" : " Staves")])
            if (prefs.pages && score.npages > 0)
                pushRotation(states, [score.npages + (score.npages === 1 ? " Page" : " Pages")])
        } else {
            var position = playing ? null : selectedPosition(score)
            var measure = playing ? measureAt(score, playback.measure) : (position ? position.measure : null)
            var segment = playing ? playbackSegment(measure, playback) : (position ? position.segment : null)
            var track = playing ? playbackTrack(score, segment) : (position ? position.track : -1)
            var info = positionInfo(score, measure, segment, track, playback, playing)
            if (playing) {
                pushRotation(states, [prefs.playSystem && info.system > 0 ? "System " + info.system : "",
                                      prefs.currentPage && info.page > 0 ? "Page " + info.page : ""])
            } else {
                pushRotation(states, [prefs.playMeasure && info.measure > 0 ? "Measure " + info.measure : "",
                                      prefs.currentStaff && info.staff > 0 ? "Staff " + info.staff : ""])
            }
            pushRotation(states, [(playing ? prefs.playDynamics : prefs.editDynamics) ? info.dynamics : "",
                                  prefs.playTempo && info.bpm > 0 ? info.bpm + " BPM" : ""])
            pushRotation(states, [prefs.currentKey ? info.key : "", prefs.currentTime ? info.time : ""])
            pushRotation(states, [prefs.currentInstrument ? info.instrument : ""])
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
            var credit = (prefs.composer ? (author || subtitleCredit || composer) : "") ||
                         (prefs.lyricist ? lyricist : "")
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
