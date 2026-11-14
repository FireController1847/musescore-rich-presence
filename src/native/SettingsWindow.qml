import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

ApplicationWindow {
    id: root
    title: "Discord Rich Presence Settings"
    width: 440
    height: 570
    minimumWidth: 360
    minimumHeight: 370
    flags: Qt.Dialog
    modality: Qt.NonModal

    component PreferenceCheck: CheckBox {
        required property string preferenceKey
        checked: Boolean(presenceClient.preferences[preferenceKey])
        onToggled: presenceClient.setPreference(preferenceKey, checked)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        TabBar {
            id: tabs
            Layout.fillWidth: true
            TabButton { text: "Activity" }
            TabButton { text: "Score info" }
            TabButton { text: "Position" }
            TabButton { text: "Behavior" }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabs.currentIndex

            ColumnLayout {
                spacing: 4
                Label {
                    text: "Choose how your activity is displayed."
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
                PreferenceCheck { text: "Show playback state"; preferenceKey: "playback" }
                PreferenceCheck { text: "Show elapsed time"; preferenceKey: "elapsed" }
                PreferenceCheck { text: "Show playback progress bar"; preferenceKey: "playProgress" }
                Label {
                    text: "Playing scores use a separate activity. When stopped, any selection means Editing; no selection means Viewing."
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    opacity: 0.7
                }
                Item { Layout.fillHeight: true }
            }

            ColumnLayout {
                spacing: 2
                PreferenceCheck { text: "Score title"; preferenceKey: "title" }
                PreferenceCheck { text: "Score filename (.mscz)"; preferenceKey: "filename" }
                PreferenceCheck { text: "Subtitle"; preferenceKey: "subtitle" }
                PreferenceCheck { text: "Lyricist"; preferenceKey: "lyricist" }
                PreferenceCheck { text: "Composer / author"; preferenceKey: "composer" }
                PreferenceCheck { text: "Measure count"; preferenceKey: "measures" }
                PreferenceCheck { text: "System count"; preferenceKey: "systems" }
                PreferenceCheck { text: "Track count"; preferenceKey: "tracks" }
                PreferenceCheck { text: "Page count"; preferenceKey: "pages" }
                Label {
                    text: "Title is preferred. Filename is shared only when enabled, including as a fallback for untitled scores."
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    opacity: 0.7
                }
                Item { Layout.fillHeight: true }
            }

            ColumnLayout {
                spacing: 4
                PreferenceCheck { text: "Current measure (editing)"; preferenceKey: "playMeasure" }
                PreferenceCheck { text: "Current track (editing)"; preferenceKey: "currentTrack" }
                PreferenceCheck { text: "Current system (playback)"; preferenceKey: "playSystem" }
                PreferenceCheck { text: "Current page (playback)"; preferenceKey: "currentPage" }
                PreferenceCheck { text: "Dynamics while editing"; preferenceKey: "editDynamics" }
                PreferenceCheck { text: "Dynamics while playing"; preferenceKey: "playDynamics" }
                PreferenceCheck { text: "Current tempo (BPM)"; preferenceKey: "playTempo" }
                PreferenceCheck { text: "Current key"; preferenceKey: "currentKey" }
                PreferenceCheck { text: "Current time signature"; preferenceKey: "currentTime" }
                PreferenceCheck { text: "Current instrument"; preferenceKey: "currentInstrument" }
                Label {
                    text: "Position information rotates while editing or playing. Listening retains the title, author and progress bar."
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    opacity: 0.7
                }
                Item { Layout.fillHeight: true }
            }

            ColumnLayout {
                spacing: 8
                PreferenceCheck { text: "Hide activity when no score is open"; preferenceKey: "hideWithoutScore" }
                RowLayout {
                    Label { text: "Rotate score information every" }
                    SpinBox {
                        from: 5
                        to: 60
                        stepSize: 5
                        value: Number(presenceClient.preferences.rotation)
                        onValueModified: presenceClient.setPreference("rotation", value)
                    }
                    Label { text: "sec" }
                }
                Item { Layout.fillHeight: true }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "Changes are saved automatically."
                opacity: 0.7
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
            Button { text: "Close"; onClicked: root.close() }
        }
    }
}
