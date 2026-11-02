# Taskbar Pull

**Click a window's button on any screen's taskbar, and the window comes to that screen.**

Taskbar Pull is a small, free and open-source tray app for Windows 10 and 11 setups with several
screens and a taskbar on each. Windows activates a window wherever it already is, so clicking its
button on the taskbar in front of you often brings it up on a screen you are not looking at.
With Taskbar Pull, the screen whose taskbar you click is where the window appears.

![Taskbar Pull icon](docs/logo-300.png)

## What it does

Hold **Alt** and click a window's button on a taskbar (or, if you switch it on, just click), and:

| Situation | What happens |
|---|---|
| The window is minimized | It is restored on the screen whose taskbar you clicked. |
| The window is open in the background on another screen | It is brought forward and moved to that screen. |
| The window is already the active window, on another screen | Windows would minimize it; Taskbar Pull restores it on the clicked screen instead. If it is already on that screen, the normal minimize is left alone. |
| The button combines several windows | The thumbnails open; the thumbnail you pick (with or without Alt) comes to the clicked screen. |
| You Alt+click a thumbnail directly | That window comes to the screen of the taskbar the thumbnails belong to. |

Placement:

- **Maximized windows stay maximized** on the new screen.
- **Other windows keep a proportional size and position**, even between screens with different
  scaling (for example 150 % and 250 %), and always end up fully on the screen.

Triggers:

- **Alt+click** works on every screen (on by default).
- **Plain click** (off by default) works on the screens you choose: all screens, including ones
  connected later, or specific screens picked by name in the settings.

Everything else on the taskbar keeps its normal Windows behaviour.

## Screenshots

*(placeholders — pick the ones to show before publishing)*

- `docs/screenshots/first-run-en-native.png` — first-run dialog
- `docs/screenshots/settings-1-en-native.png` — settings, General tab
- `docs/screenshots/settings-2-en-native.png` — settings, Game guard tab
- `docs/screenshots/settings-3-en-native.png` — settings, Advanced tab (admin mode)
- `docs/screenshots/tray-menu-en-native.png` — tray menu
- `docs/screenshots/*-store.png` — the Microsoft Store version's dialogs (no admin mode)
- `docs/demo.gif` — a window pulled from one screen to another *(to record)*

French versions use `-fr-` instead of `-en-`; `-native` files are at 150 % scaling, `-100` files at 100 %.

## Install

Pick one:

- **Installer (recommended)** — `TaskbarPull-<version>-setup.exe` from the
  [Releases](https://github.com/ychk99/taskbar-pull/releases) page. It installs for your user
  only (no administrator rights), adds a Start menu shortcut and can start Taskbar Pull with Windows.
- **winget** — `winget install YsIdeas.TaskbarPull` *(once the package is accepted)*.
- **Microsoft Store** — *(link once published)*. The Store version starts with Windows through the
  Store's own startup setting and has no admin mode (see below).
- **Portable** — unzip `TaskbarPull-<version>-portable.zip` anywhere and run `TaskbarPull.exe`.

On first start, a short dialog explains what Taskbar Pull does and lets you choose Alt+click,
plain click (all screens or chosen screens) and start with Windows. **Nothing changes until you
click Start.**

### Why the exe is called TaskbarPull.exe but says "AutoHotkey"

Taskbar Pull is written in [AutoHotkey v2](https://www.autohotkey.com/). `TaskbarPull.exe` is the
official, unmodified AutoHotkey 2.0.31 interpreter, only renamed; started without arguments it runs
`TaskbarPull.ahk` from its own folder. You can check it: its SHA-256 equals that of
`AutoHotkey64.exe` in the official AutoHotkey 2.0.31 download. Shipping the official interpreter
instead of a "compiled" script keeps antivirus false positives down and lets you read every line
that runs.

## Using it

Taskbar Pull lives in the notification area (tray). Right-click its icon for:

- **Enabled** — switch it on or off (the icon turns grey when off),
- **Settings…**, **Open log folder**, **About**, **Exit**.

Double-clicking the icon, or starting Taskbar Pull again from the Start menu, opens the settings.

## Settings

| Setting | Default | Notes |
|---|---|---|
| Enabled | on | Same as the tray menu item. |
| Alt+click | on | Alt+click on a taskbar button pulls the window. |
| Plain click | off | All screens (including screens connected later), or only the screens you tick. The list shows the connected screens by monitor name and refreshes when screens are connected or removed; ticked screens that are not connected stay in the list. |
| Start with Windows | on | Installer/portable: a `Taskbar Pull` value under `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`. Store: the package's startup task (Settings > Apps > Startup). |
| Language | automatic | English or French; automatic follows the Windows display language. |
| Game guard | see below | Editable lists of game programs and game folders. |
| Wait for the window or thumbnail pick | 8 s | How long a click waits for the window to come forward or for a thumbnail pick. |
| Write a log | on | One file per day, kept 14 days. |
| Admin mode | off | Not in the Store version; see below. |

Settings are stored in `%APPDATA%\Taskbar Pull\settings.ini` and logs in
`%LOCALAPPDATA%\Taskbar Pull\logs\` (the Store version keeps both inside its package data folder;
**Open log folder** always opens the right place).

## Game guard

To stop Windows from opening a window's menu when you release Alt after an Alt+click, Taskbar Pull
sends one harmless, unassigned key (`vkE8`) while Alt is held, and an Esc if a menu still opened.
**It never sends any key while the foreground window is full-screen or belongs to a listed game,**
and it holds the key back while the taskbar itself has the focus, so that a key cannot reach a game
that Windows activates a few milliseconds later.

Games are matched by program name or by a fragment of the program's path. Defaults:

- programs: `League of Legends.exe`, `VALORANT-Win64-Shipping.exe`
- folders: `\steamapps\common\` (every Steam library), `\Riot Games\`, `\Epic Games\`,
  `\GOG Galaxy\Games\`, `\EA Games\`, `\Ubisoft Game Launcher\games\`, `\XboxGames\`,
  `\Amazon Games\Library\`, `\Rockstar Games\`, `\itch\apps\`

Windows themselves are never blocked from moving: if you Alt+click a game's button on another
screen's taskbar, the game window moves, but no key is sent to it.

## Admin mode (installer and portable versions)

Windows does not let a normal app move the windows of apps that run as administrator (for example
an admin terminal or Task Manager). **Admin mode** (Settings > Advanced) starts Taskbar Pull with
administrator rights at sign-in through a scheduled task, `Taskbar Pull (admin mode)`, created after
a Windows confirmation (UAC). Switching admin mode off removes the task. In admin mode the task is
what starts Taskbar Pull with Windows, and starting it from the Start menu hands over to the task.
The Microsoft Store version cannot run elevated, so it has no admin mode.

## Uninstall

- **Installer version:** Settings > Apps > Installed apps > Taskbar Pull > Uninstall. The
  uninstaller stops Taskbar Pull, removes the start-with-Windows entry and, if admin mode is on, its
  scheduled task (after a UAC confirmation), and asks whether to keep your settings and logs.
- **Store version:** uninstall it like any Store app; Windows removes its data.
- **Portable version:** switch off Start with Windows and admin mode in the settings, exit, then
  delete the folder (and `%APPDATA%\Taskbar Pull`, `%LOCALAPPDATA%\Taskbar Pull` if you want).

## FAQ

**Does it work with one screen?** It does nothing useful there; it is made for several screens.

**Do I need "Show my taskbar on all displays"?** Yes. Taskbar Pull reacts to clicks on the taskbar
of the screen where you click, so each screen needs its own taskbar (Settings > Personalization >
Taskbar > Taskbar behaviours).

**Does it change Explorer or inject into other apps?** No. It watches mouse clicks with a standard
low-level mouse hook, watches window events with `SetWinEventHook`, and moves windows with
`SetWindowPos`/`SetWindowPlacement`. Nothing is injected into other processes.

**Why does the window briefly appear on its old screen first?** Windows shows it where it was
before Taskbar Pull can identify it; it is moved within about 60–200 ms.

**Is anything sent over the network?** No. Taskbar Pull has no network code and no telemetry.

**My antivirus flags it.** `TaskbarPull.exe` is the official AutoHotkey interpreter; AutoHotkey is
sometimes flagged by heuristics. Check the file's SHA-256 against the release's `SHA256SUMS.txt`
and the official AutoHotkey 2.0.31 download, and report the false positive to your antivirus vendor.

## Known limitations

- The window can show for a split second on its old screen before it moves.
- Windows of apps running as administrator can be moved only in admin mode (not in the Store version).
- Touch taps on a taskbar may arrive as touch input rather than mouse clicks and were not tested.
- An Alt+click on an empty part of a taskbar, the Start button or a tray icon waits up to the arm time
  (8 s) for a window to come forward (for example via Win+number); Alt+Tab, Task View or a click
  elsewhere cancels it.
- The thumbnail flyout is recognised by its window class and empty title; a future Windows update
  that changes it would make thumbnail picks cancel the request (the log shows `[cancel]` lines).
- Two identical monitors share the same name, so "only these screens" cannot tell them apart.
- Full-screen apps that are not games (a browser in F11, a video player) get no Esc either, so after
  an Alt+click on their own button they can be left in menu mode; a click or any key ends it.
- Third-party taskbars (StartAllBack's, DisplayFusion's, …) are not supported.

## Building

```powershell
pwsh build\get-tools.ps1          # AutoHotkey 2.0.31 (hash-checked), makeappx, Inno Setup (per user)
pwsh build\build.ps1 -Version 1.0.0 -Scan
```

Outputs in `dist\`: portable zip, per-user installer, MSIX for the Store (unsigned — the Store
signs it), winget manifest draft, `SHA256SUMS.txt`. `build\tools\make-icons.py` redraws the icons.
Pushing a tag `v1.2.3` runs `.github/workflows/release.yml`, which builds everything on
`windows-latest` and attaches it to a **draft** release.

Tests (`tests\`) drive the real desktop with simulated input and only run while you are idle; see
[docs/TESTING.md](docs/TESTING.md). Release steps (GitHub, winget, Microsoft Store) are in
[docs/RELEASING.md](docs/RELEASING.md).

## Privacy

Taskbar Pull collects nothing and never connects to the internet; settings and logs stay on your PC.
See the [privacy policy](docs/privacy.md).

## Licence

MIT — see [LICENSE](LICENSE). Copyright © 2026 Yasser Chkam.
The packages include the AutoHotkey interpreter, GPL-2.0 — see
[THIRD-PARTY-NOTICES](THIRD-PARTY-NOTICES).
