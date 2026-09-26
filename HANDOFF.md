# Ambxst YTD Handoff

## Status

- Mod: `mnojz.ambxstytd`
- Version: `1.4.5`
- Compatibility: Ambxst `>=1.3.0 <1.4.0`
- Tested against Ambxst `1.3.9`, base commit `3705f278f24a74718fc23772b47044e96701d53a`
- Requires the `drpezzer.tinted-icons` mod
- License: MIT

The mod adds a horizontal/vertical bar button and popup for YouTube MP3 and
video downloads. The backend emits JSON-line events, cancellation cleans up
yt-dlp/FFmpeg children, browser requests are queued, and history persists in
Ambxst state.

## Layout

- `ambxst.mod.json`: overlays, patch, dependencies, permissions, tested base.
- `patches/bar.patch`: inserts `YtdButton` in both bar orientations.
- `payload/modules/bar/YtdButton.qml`: bar button, popup, queue/progress UI,
  thumbnail fallbacks, history actions, and a measured format selector. The
  format selector and the playlist scope toggle sit side by side on one row; the
  toggle is an `Icons.list` button that is accent-filled when whole-playlist mode
  is on. Off drops `list` so only the linked video downloads; on keeps it. The
  popup uses a single page-level `ScrollView` inside a fixed 350px viewport, so
  the header, URL field, format selector, active card, and all history cards
  scroll together as one unit. There is no nested history scroller. Change
  `maximumContentHeight` to adjust the height. The YTD glyph
  uses the shared `Tinted` component, and bar progress colors use semantic style
  roles rather than fixed RGB values.

  The popup is a mod-owned `PanelWindow`, not the shell's `BarPopup`. `BarPopup`
  is a Quickshell `PopupWindow`, which is not a WlrLayerShell surface and so
  cannot take keyboard input: `WlrLayershell` fails to attach to it, and
  `PopupWindow.grabFocus` only toggles the `Qt::Popup` flag for click-outside
  dismissal, it does not request keyboard focus. The URL field therefore could
  not receive keystrokes. `PanelWindow` supports `WlrLayershell.keyboardFocus`,
  and the popup switches it to `Exclusive` while open, matching how the shell's
  own input surfaces work (`UnifiedShellPanel`, `ContextMenu`).

  Three things about this window are load-bearing. Do not undo them.

  - **It is full-screen, so it sits on top of the bar.** `PanelWindow` has no
    `x`/`y` and no `anchor.item`, so the window spans the screen and a child
    carries the real position, the same shape `ContextMenu` uses. Because the
    window covers the bar, it must not carry a `mask: Region`; the input region
    is left unrestricted and a full-screen `MouseArea` behind the popup closes
    it on any click. That is what makes the bar button usable to dismiss the
    popup even though the popup is drawn over it. A `FocusGrab` must not be
    used here either: it is Quickshell's Hyprland focus grab, and it
    redirected input away from the button.
  - **Position is computed in `reposition()`, not in a binding.** `mapToItem()`
    is a function call, so a binding over it is evaluated once at load — while
    the bar is still at its pre-layout position — and never re-evaluates. That
    stale value is what opened the popup in the wrong corner. `open()` and
    `onVisibleChanged` both call `reposition()`.
  - **The content must stay inside the styled `background`.** The `ScrollView`
    is a child of it and anchored to it. When the `ScrollView` was a sibling
    placed with absolute window coordinates it did not follow the background's
    fade, so the two visibly tore down one after another. For the same reason
    the popup is now shown and hidden outright instead of fading: a fade on a
    full-screen layer surface repaints the whole screen every frame and reads
    as lag.
- `payload/modules/services/YtdService.qml`: process lifecycle, bounded request
  queue, cancellation, history restore/persistence, clipboard, and event parsing.
- `payload/modules/services/YtdHistory.js`: pure history sanitizing/dedup/cap.
- `payload/modules/services/YtdUrl.js`: pure YouTube/YouTube Music URL
  validation, id parsing, `list` stripping, and single/playlist scoping. QML JS
  has no `URL` global, so the components are split with a regex.
- `payload/modules/services/YtdI18n.qml`: mod-local English/Russian/Spanish UI
  strings following the language resolved by core `I18n`.
- `payload/scripts/ytd_helper.py`: yt-dlp process and JSON event helper.
- `payload/scripts/ytd_protocol.py`: `ytd:` URL to QuickShell IPC bridge.
- `payload/assets/ytd.svg`: bar icon.
- `ytd-handler.desktop`: desktop-entry template.
- `scripts/install-desktop.sh`: installs/registers bridge, desktop entry, icon.
- `scripts/validate.sh`: complete static, unit, generation, smoke validation.
- `tests/`: Python helper/protocol tests and Node history-library tests.

## Runtime behavior

`YtdService.start()` launches:

```text
python3 <generation>/modules/bar/ytd_helper.py URL FORMAT
```

Supported formats are MP3, 480p, 720p, 1080p, 1440p, and 2160p. Audio goes to
`~/Music`; video goes to `~/Videos`. The helper:

- starts in its own session/process group;
- handles SIGTERM/SIGINT, kills child processes, and exits with 130;
- strips browser-only `format` query values from YouTube URLs;
- deduplicates per-item stream hooks;
- records playlist index/count;
- reconciles stream paths with final merged/postprocessed paths;
- emits final `complete.items` only after paths are authoritative.

The UI reads the selected format from the service, so selector and IPC formats
share one source of truth. IPC functions are void and call
`YtdService.requestDownload()`; up to five browser requests wait behind the
active process. IPC requests also open the popup.

History is stored through `StateService` under
`community.ambxstytd.history`. Records contain ID, title, source URL, final
filename, format, thumbnail, and timestamp. `YtdHistory.js` removes malformed
records, deduplicates by ID/path/URL, and caps the list at 40. The queue itself
is intentionally in-memory only.

## Browser bridge

Run:

```bash
./scripts/install-desktop.sh
```

This installs the canonical repository copy to `~/.local/bin/ytd.py`, renders
`ytd-handler.desktop` with portable paths, installs the SVG, updates the desktop
database, and registers `x-scheme-handler/ytd`.

The bridge uses `qs list -a -j`, filters actual `shell_id=ambxst` generation
shells, selects the newest running one, and invokes:

```bash
qs ipc --pid <pid> call ytd download <clean-url> <format> <scope>
```

`scope` is `single` or `playlist`. The bridge strips the `list` parameter in
single scope and rejects playlist-only links there, because they name no single
video.

Legacy aliases (`audio`, `sd`, `hd`, `fhd`, `qhd`, `uhd`) remain supported.
Failures print to stderr and use `notify-send` when available.

## Refresh procedure

New installs are disabled by Ambxst. Refresh explicitly:

```bash
ambxst mods remove mnojz.ambxstytd
ambxst mods install https://github.com/mnojz/ambxst-ytd
ambxst mods enable mnojz.ambxstytd
ambxst reload
```

Do not edit files under `~/.local/share/ambxst/mods/packages` or active
generation directories. If the bar disappears, disable the mod, reload, and
inspect the generated source.

## Validation

Run:

```bash
/home/manoj/Projects/ambxst-ytd/scripts/validate.sh
```

It checks Python/JSON/shell syntax, diff hygiene, 24 Python tests, 3 history
tests, 9 URL tests, patch applicability, repository/generated payload equality, a
generated QuickShell smoke load, and desktop registration. A healthy smoke
process is stopped by `timeout`, so status 124 is expected.

Use `AMBXST_SOURCE=/path/to/ambxst` to override the local base checkout.

The `ydl:` browser extension that drives this mod is maintained outside this
repository and is not validated here.

## Known caveats

- Core Ambxst 1.3.8 has no per-mod translation namespace; `YtdI18n.qml` uses
  core language resolution but owns its own catalog.
- Core `StyledToolTip` misspells its second property as `desciription`; the mod
  matches that API until core fixes it.
- Stock `qmltestrunner` requires a versioned module wrapper for the relative
  `.pragma library` import style Ambxst already uses. Node tests execute the
  exact `YtdHistory.js` body instead.
- Thumbnails are remote and not cached; cards fall back to the YTD icon.
- YouTube extraction can still fail due to authentication, restrictions,
  throttling, or site changes.
- Validation does not download copyrighted/user media. The cancellation test
  uses a controlled child process instead of a real FFmpeg download.
