import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ToolButton {
    id: button
    objectName: "musescoreRichPresenceStatus"
    Layout.preferredWidth: 32
    Layout.minimumWidth: 32
    Layout.preferredHeight: 28
    Layout.alignment: Qt.AlignVCenter

    readonly property bool active: presenceClient.enabled && presenceClient.ready
                                   && presenceClient.status === "Discord accepted activity"
    readonly property color statusColor: active ? "#5865F2"
                                        : presenceClient.enabled ? "#b88b35" : palette.buttonText

    icon.source: "qrc:/discordpresence/discord.svg"
    icon.width: 18
    icon.height: 18
    icon.color: statusColor
    opacity: presenceClient.enabled ? 1.0 : 0.55
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus

    background: Rectangle {
        radius: 4
        color: button.down || button.hovered ? button.palette.mid : "transparent"
        opacity: 0.35
    }

    Accessible.name: "Discord Rich Presence"
    Accessible.description: presenceClient.status
    ToolTip.visible: hovered
    ToolTip.delay: 350
    ToolTip.text: "Discord Rich Presence: " + presenceClient.status
                  + (presenceClient.enabled ? "\nClick to disable" : "\nClick to enable")

    onClicked: presenceClient.toggle()
}
