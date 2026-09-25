# Ambxst YTD

An Ambxst bar mod that downloads YouTube audio or video with `yt-dlp` and
`ffmpeg`. It provides a popup, live progress, cancellation, a bounded
request queue, persistent history, and browser `ytd:` links.

## Requirements

- Ambxst `>=1.3.0 <1.4.0`
- Python 3 with the `yt_dlp` module
- `yt-dlp`, `ffmpeg`, `wl-paste`, `xdg-open`, and QuickShell (`qs`)
- A Wayland Ambxst session

The mod manifest is the authoritative dependency declaration. Ambxst refuses
composition when a declared command is unavailable.

## Install the mod

```bash
ambxst mods remove community.ambxstytd
ambxst mods install /path/to/ambxst-ytd
ambxst mods enable community.ambxstytd
ambxst reload
```

New installs are disabled by default, so keep the explicit `enable` step.
Removing an already-disabled mod may report that it was removed; the subsequent
install and enable are still required for a clean refresh.

## Browser integration

Install or refresh the desktop protocol handler from the repository root:

```bash
./scripts/install-desktop.sh
```

The script installs:

- `~/.local/bin/ytd.py`
- `~/.local/share/applications/ytd-handler.desktop`
- `~/.local/share/icons/ytd.svg`

It refreshes the desktop database and registers `ytd-handler.desktop` for
`x-scheme-handler/ytd` when `xdg-mime` is available.

Supported links include:

```text
ytd:https://www.youtube.com/watch?v=VIDEO_ID&format=hd
ytd:https://youtu.be/VIDEO_ID?format=mp3
ytd:https://www.youtube.com/watch?v=VIDEO_ID&list=LIST_ID&playlist=1
```

Legacy format aliases are accepted: `audio`, `sd`, `hd`, `fhd`, `qhd`, and
`uhd`. The `format`, `scope`, and `playlist` parameters are removed before the
URL reaches `yt-dlp`. By default the `list` parameter is also removed, so only
the single video is downloaded; add `&playlist=1` (or `&scope=playlist`) to
download the whole playlist.

Invalid or non-YouTube links are refused by the bridge before Ambxst is
contacted, and the desktop reports the reason.

## Downloads

- Only YouTube and YouTube Music links are accepted. `watch`, `youtu.be`,
  `/shorts/`, `/live/`, `/embed/`, and `/playlist` URLs are supported; anything
  else is reported as an invalid URL before any download starts.
- The **Single video** / **Whole playlist** selector sits under the format
  selector. Single drops the `list` parameter so a shared link downloads just
  the current video; Whole playlist keeps it.
- A playlist-only link (`/playlist?list=...`) is rejected in Single mode
  because it names no single video; switch to Whole playlist to download it.
- Audio is saved as MP3 under `~/Music`.
- Video is saved as MP4 under `~/Videos`.
- Playlist items are recorded separately after their final output path exists.
- History is persisted by Ambxst under `community.ambxstytd.history`, capped at
  40 entries, and restored on shell startup.
- Browser requests open the popup and are queued behind an active download.
- Cancelling terminates the helper and its FFmpeg process group.

YouTube extraction can still fail because of authentication, age/location
restrictions, client throttling, or upstream site changes.

## Validate

Run the repository checks:

```bash
./scripts/validate.sh
```

The validator checks Python syntax and unit tests, the Ambxst patch against the
local source checkout, manifest structure, and—when an installed active
generation is available—the generated QuickShell shell. A healthy foreground
smoke test reaches `Configuration Loaded` and is stopped by `timeout`, so exit
status `124` is expected in that mode.
