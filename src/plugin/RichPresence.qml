import QtQuick 2.15
import MuseScore 3.0
import "DiscordIPC" as IPC

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

    IPC.DiscordClient {
        id: discord
    }

    Timer {
        id: refresh
        interval: 5000
        repeat: true
        onTriggered: root.updateActivity()
    }

    onRun: {
        // MuseScore can create another instance when the menu action is
        // invoked again. Keep the same toggle behavior as the old plugin.
        var previous = Qt.museScoreRichPresence
        if (previous && previous.enabledPresence) {
            previous.stopPresence()
            return
        }

        Qt.museScoreRichPresence = root
        enabledPresence = true
        lastScore = ""
        stateIndex = 0
        startedAt = Math.floor(Date.now() / 1000)
        discord.start("577645453429047314")
        updateActivity()
        refresh.start()
        console.log("MuseScore Rich Presence enabled")
    }

    Component.onDestruction: {
        refresh.stop()
        if (Qt.museScoreRichPresence === root)
            Qt.museScoreRichPresence = null
    }

    function stopPresence() {
        refresh.stop()
        discord.stop()
        enabledPresence = false
        if (Qt.museScoreRichPresence === root)
            Qt.museScoreRichPresence = null
        console.log("MuseScore Rich Presence disabled")
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
        if (!enabledPresence)
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
