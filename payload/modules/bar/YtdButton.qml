pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.components
import qs.modules.services
import qs.modules.theme

Item {
    id: root
    required property var bar
    property bool vertical: bar.orientation === "vertical"
    property bool layerEnabled: true
    property real startRadius: Styling.radius(0)
    property real endRadius: Styling.radius(0)
    readonly property bool popupOpen: popup.isOpen

    implicitWidth: 36
    implicitHeight: 36
    Layout.preferredWidth: 36
    Layout.preferredHeight: 36
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical

    Button {
        id: button
        anchors.fill: parent
        hoverEnabled: true
        onClicked: popup.toggle()
        background: StyledRect {
            variant: root.popupOpen ? "primary" : "bg"
            enableShadow: root.layerEnabled
            topLeftRadius: root.startRadius
            bottomLeftRadius: root.startRadius
            topRightRadius: root.endRadius
            bottomRightRadius: root.endRadius
            Rectangle {
                anchors.fill: parent
                color: Styling.srItem("overprimary")
                opacity: button.down ? 0.5 : (button.hovered ? 0.25 : 0)
                radius: parent.radius ?? 0
            }
        }
        contentItem: Item {
            Image { anchors.centerIn: parent; source: Qt.resolvedUrl("ytd.svg"); sourceSize: Qt.size(20, 20); smooth: true; opacity: root.popupOpen ? 1 : 0.9 }
            Text { visible: YtdService.running; anchors.right: parent.right; anchors.top: parent.top; text: Math.round(YtdService.progress) + "%"; color: root.popupOpen ? Colors.overBackground : Styling.srItem("overprimary"); font.family: Styling.defaultFont; font.pixelSize: 8 }
        }
        Accessible.name: "YTD Downloader"
    }

    StyledToolTip { show: button.hovered && !root.popupOpen; tooltipText: "YTD Downloader"; desciription: YtdService.running ? Math.round(YtdService.progress) + "%" : "Download media" }

    BarPopup {
        id: popup
        anchorItem: button
        bar: root.bar
        popupPadding: 12
        contentWidth: Math.max(360, Math.min(520, (root.bar?.screen?.width ?? 900) - 48))
        contentHeight: card.implicitHeight + popupPadding * 2

        ColumnLayout {
            id: card
            anchors.fill: parent
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                TextField {
                    id: urlField
                    Layout.fillWidth: true
                    placeholderText: "YouTube URL"
                    text: YtdService.url
                    selectByMouse: true
                    background: StyledRect { variant: urlField.activeFocus ? "focus" : "internalbg"; radius: Styling.radius(-4); enableShadow: false }
                    color: Colors.overBackground
                    onAccepted: downloadButton.clicked()
                }
                ComboBox { id: formatMenu; Layout.preferredWidth: 104; model: ["mp3", "480p", "720p", "1080p", "1440p", "2160p"]; currentIndex: 3; onActivated: YtdService.mediaFormat = currentText }
                Button {
                    id: downloadButton
                    implicitWidth: 38
                    implicitHeight: 38
                    enabled: urlField.text.trim() !== "" && !YtdService.running
                    onClicked: YtdService.start(urlField.text, formatMenu.currentText)
                    background: StyledRect { variant: downloadButton.enabled ? "primary" : "common"; radius: Styling.radius(-4); enableShadow: false }
                    contentItem: Text { text: "↓"; color: downloadButton.enabled ? Colors.background : Colors.outline; font.pixelSize: 22; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    Accessible.name: "Download"
                }
            }

            ColumnLayout {
                visible: YtdService.state !== "idle"
                Layout.fillWidth: true
                spacing: 6
                Text { Layout.fillWidth: true; text: YtdService.title !== "" ? YtdService.title : YtdService.message; color: Colors.overBackground; font.family: Styling.defaultFont; font.pixelSize: Styling.fontSize(0); font.bold: true; elide: Text.ElideMiddle }
                Text { Layout.fillWidth: true; visible: YtdService.filename !== ""; text: YtdService.filename; color: Colors.outline; font.family: Styling.defaultFont; font.pixelSize: Styling.fontSize(-1); elide: Text.ElideMiddle }
                Rectangle { Layout.fillWidth: true; height: 5; radius: 3; color: Colors.surfaceVariant; Rectangle { width: parent.width * YtdService.progress / 100; height: parent.height; radius: 3; color: Styling.srItem("overprimary") } }
                RowLayout { Layout.fillWidth: true; Text { text: Math.round(YtdService.progress) + "%"; color: Colors.overBackground; font.family: Styling.defaultFont; font.pixelSize: Styling.fontSize(-1) }; Text { Layout.fillWidth: true; text: YtdService.formatBytes(YtdService.downloaded) + " / " + (YtdService.total > 0 ? YtdService.formatBytes(YtdService.total) : "unknown"); color: Colors.outline; font.family: Styling.defaultFont; font.pixelSize: Styling.fontSize(-1); horizontalAlignment: Text.AlignRight }; Text { text: YtdService.formatSpeed(YtdService.speed); color: Colors.outline; font.family: Styling.defaultFont; font.pixelSize: Styling.fontSize(-1) } }
            }
        }
        onIsOpenChanged: if (isOpen) Qt.callLater(() => urlField.forceActiveFocus())
    }
}