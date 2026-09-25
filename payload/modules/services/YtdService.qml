pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string helperPath: decodeURIComponent(Qt.resolvedUrl("../bar/ytd_helper.py").toString().replace("file://", ""))
    property string url: ""
    property string mediaFormat: "1080p"
    property string title: ""
    property string filename: ""
    property string message: ""
    property real progress: 0
    property real downloaded: 0
    property real total: 0
    property real speed: 0
    property int eta: 0
    property string state: "idle"
    readonly property bool running: process.running

    function reset() {
        title = ""; filename = ""; message = ""; progress = 0;
        downloaded = 0; total = 0; speed = 0; eta = 0; state = "idle";
    }

    function start(nextUrl, nextFormat) {
        var trimmed = String(nextUrl || "").trim();
        if (trimmed === "" || process.running)
            return false;
        reset();
        url = trimmed;
        mediaFormat = String(nextFormat || "1080p");
        state = "starting";
        process.command = ["python3", root.helperPath, url, mediaFormat];
        process.running = true;
        return true;
    }

    function formatBytes(value) {
        var bytes = Number(value || 0);
        if (bytes < 1024)
            return Math.round(bytes) + " B";
        var units = ["KB", "MB", "GB"];
        var index = -1;
        do { bytes /= 1024; index++; } while (bytes >= 1024 && index < units.length - 1);
        return bytes.toFixed(bytes >= 100 ? 0 : 1) + " " + units[index];
    }

    function formatSpeed(value) {
        return value > 0 ? formatBytes(value) + "/s" : "--";
    }

    Process {
        id: process
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                try {
                    var event = JSON.parse(line);
                    if (event.event === "error") {
                        root.state = "error";
                        root.message = String(event.message || "Download failed");
                    } else if (event.event === "complete") {
                        root.progress = 100;
                        root.state = "complete";
                        root.message = "Download complete";
                    } else {
                        root.state = "downloading";
                        root.title = String(event.title || root.title);
                        root.filename = String(event.filename || root.filename);
                        root.downloaded = Number(event.downloaded || 0);
                        root.total = Number(event.total || 0);
                        root.progress = Math.max(0, Math.min(100, Number(event.percent || 0)));
                        root.speed = Number(event.speed || 0);
                        root.eta = Number(event.eta || 0);
                    }
                } catch (error) {
                    console.warn("YTD: invalid helper output", line);
                }
            }
        }
        stderr: SplitParser { onRead: function(line) { console.warn("YTD:", line); } }
        onExited: function(code) {
            if (code !== 0 && root.state !== "error") {
                root.state = "error";
                root.message = "Downloader exited with code " + code;
            }
        }
    }
}