# Testing Taskbar Pull

The tests drive the real Windows desktop with simulated input (SendInput), so they only run while
nobody uses the PC: `tests\harness.ps1` waits until the user has been idle for 2 minutes and no game
or full-screen app is in front, and aborts a burst as soon as real input arrives. They use their own
test windows (renamed copies of the AutoHotkey interpreter running `tests\tpwin.ahk`, so each has its
own taskbar button, found through UI Automation) and run the app under test with `APPDATA` and
`LOCALAPPDATA` pointed at a test profile.

Run with Windows PowerShell 5.1 on a PC with at least two screens, each with its own taskbar:

```powershell
powershell -File tests\run-cases.ps1 -AppDir dist\stage\TaskbarPull            # click cases
powershell -File tests\run-ui.ps1 -AppDir dist\stage\TaskbarPull -Steps FirstRun,Settings,Shots
```

## Click cases (`run-cases.ps1`)

| Case | What it checks |
|---|---|
| 1 | Minimized window, Alt+click its button on the other screen's taskbar: restored there |
| 2 | Maximized background window: moved, still maximized |
| 3 | Normal background window on the second screen, Alt+click on the primary taskbar: moved back |
| 4a | Active window, Alt+click its button on another screen: Windows minimizes it, Taskbar Pull restores it there |
| 4b | Active window already on that screen: the normal minimize is left alone |
| 5 | Combined button, Alt+click opens the thumbnails, plain click on one: that window is moved |
| 5e | Plain click opens the thumbnails, Alt+click directly on one: that window is moved |
| 6 | Plain click with plain click off: normal Windows behaviour |
| 7 | Alt+click inside a window: nothing happens |
| 8 | Window with a classic menu bar: moved, not left in menu mode |
| P | Plain click on all screens |
| P2 | Plain click only on one chosen screen (by name) |
| G1 | Full-screen test window in front, Alt+click another button: the full-screen window receives no key |
| G2 | Alt+click the full-screen window's own button: it receives no mask key and no Esc |
| T | Tray menu: Enabled off, Alt+click does nothing; on again, it works |

The Windows 11 thumbnail flyout is not exposed to UI Automation, so case 5/5e click the thumbnail by
its layout (172 px wide items centred on the button, 104 px above it, at 100 % scaling).

## UI cases (`run-ui.ps1`)

- **FirstRun**: the consent dialog appears; before Start nothing exists (no settings file, no Run
  value, no hook); after Start the settings file and the Run value exist and the engine is on.
- **Settings**: a second launch opens the running instance's settings; plain click + one screen +
  start with Windows are saved, survive a restart and show again; start with Windows off removes the
  Run value.
- **Shots**: screenshots of the app's own windows (first-run, settings tabs, tray menu) in English and
  French, at the screen's scaling and at 100 % (`__COMPAT_LAYER=DPIUNAWARE`), into `docs\screenshots`.

## Results of the 1.0.0 release candidate (Home Desktop, Windows 11 25H2, 1 Nov 2026)

Screens: VG27A 2560x1440 at 150 % (primary) and DELL S2722QC 3840x2160 at 200 %.

- Click cases: all 15 pass on the final build (run at 17:39–17:41). An earlier run of the same
  build had 4 failures (1, 4a, 5e, T) caused by the test harness failing to bring its own test window
  to the front; the next run passed everything.
- UI cases: FirstRun, Settings, start with Windows on/off pass.
- Installer: silent per-user install with and without the startup task, and uninstall while the app
  runs: files, shortcut, Run value and uninstall key all removed; nothing written under HKLM.
- Admin mode: task created through the app's `/admin-task create` path from an elevated helper,
  hand-over from a normal launch to the elevated instance, `/quit` from a normal process reaching the
  elevated instance, task removed through `/admin-task delete`.
- MSIX: the package layout registered with `Add-AppxPackage -Register` (Developer Mode was already on),
  started with package identity, first-run dialog confirmed, settings written to the package's data
  folder, no Run value written, admin mode hidden, start with Windows switched off and on through the
  WinRT StartupTask API (state 0, then 2), package removed.
