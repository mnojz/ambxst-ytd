#!/usr/bin/env python3
import json
import os
import sys

import yt_dlp

FORMATS = {
    "480p": "bv*[height<=480]+ba/bv*+ba/b",
    "720p": "bv*[height<=720]+ba/bv*+ba/b",
    "1080p": "bv*[height<=1080]+ba/bv*+ba/b",
    "1440p": "bv*[height<=1440]+ba/bv*+ba/b",
    "2160p": "bv*[height<=2160]+ba/bv*+ba/b",
}


def emit(payload):
    print(json.dumps(payload), flush=True)


def download(url, media_format):
    home = os.path.expanduser("~")
    if media_format == "mp3":
        options = {
            "outtmpl": os.path.join(home, "Music", "%(title)s.%(ext)s"),
            "format": "bestaudio/best",
            "restrictfilenames": True,
            "quiet": True,
            "no_warnings": True,
            "postprocessors": [{
                "key": "FFmpegExtractAudio",
                "preferredcodec": "mp3",
                "preferredquality": "0",
            }],
        }
    else:
        options = {
            "outtmpl": os.path.join(home, "Videos", "%(title)s_%(format_id)s.%(ext)s"),
            "format": FORMATS[media_format],
            "merge_output_format": "mp4",
            "restrictfilenames": True,
            "quiet": True,
            "no_warnings": True,
        }

    def hook(data):
        info = data.get("info_dict") or {}
        total = data.get("total_bytes") or data.get("total_bytes_estimate") or 0
        downloaded = data.get("downloaded_bytes") or 0
        percent = downloaded / total * 100 if total else 0
        emit({
            "event": data.get("status", ""),
            "title": info.get("title") or os.path.basename(data.get("filename", "")),
            "filename": data.get("filename", ""),
            "downloaded": downloaded,
            "total": total,
            "speed": data.get("speed") or 0,
            "eta": data.get("eta") or 0,
            "percent": percent,
        })

    options["progress_hooks"] = [hook]
    with yt_dlp.YoutubeDL(options) as ydl:
        ydl.download([url])


def main():
    if len(sys.argv) != 3 or (sys.argv[2] not in FORMATS and sys.argv[2] != "mp3"):
        emit({"event": "error", "message": "Usage: ytd_helper.py URL FORMAT"})
        return 2
    try:
        download(sys.argv[1], sys.argv[2])
        emit({"event": "complete"})
        return 0
    except Exception as error:
        emit({"event": "error", "message": str(error)})
        return 1


if __name__ == "__main__":
    sys.exit(main())