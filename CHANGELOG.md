# Changelog

All notable changes to Taskbar Pull. Versions follow [Semantic Versioning](https://semver.org/).

## 1.0.0 - 2026-11-02

First public release (release candidate prepared 1 Nov 2026).

### Added
- Tray app with its own icon and menu: Enabled, Settings…, Open log folder, About, Exit; the
  tooltip shows the current state, the icon turns grey when disabled.
- First-run dialog (English or French, following the Windows display language) explaining what the
  app does, with Alt+click (on), plain click (off; all screens or chosen screens) and start with
  Windows (on). Nothing changes until the user clicks Start.
- Settings window: per-screen plain-click list (by monitor name, refreshed when screens change),
  game guard lists, arm time, logging, start with Windows, language (automatic, English, French),
  and admin mode (installer and portable versions only).
- Settings in `%APPDATA%\Taskbar Pull\settings.ini`; daily logs in `%LOCALAPPDATA%\Taskbar Pull\logs`,
  kept 14 days.
- Start with Windows through the HKCU Run key, the admin-mode scheduled task, or the MSIX startup task.
- Admin mode: a scheduled task, created after a UAC confirmation, starts Taskbar Pull elevated so it
  can move windows of apps running as administrator; switching it off removes the task.
- Game guard defaults for the standard game folders of Steam, Riot, Epic, GOG Galaxy, EA, Ubisoft,
  Xbox app, Amazon Games, Rockstar and itch.
- Packages: portable zip, per-user Inno Setup installer, MSIX for the Microsoft Store, winget
  manifest draft; PowerShell build scripts and a GitHub Actions release workflow.

### Engine (unchanged from the private helper it grew out of)
- Minimized windows, background windows, the already-active toggle, combined-button thumbnails and
  Alt+click directly on a thumbnail; maximized windows stay maximized, other windows keep a
  proportional size across DPI and end up fully on the screen.
- No key is ever sent into a full-screen window or a listed game.

### Fixed (compared with the private helper)
- Game guard race: the mask key was also sent while the taskbar had the focus, and could then
  reach a full-screen window that Windows activated a few milliseconds later (seen when Alt+clicking
  a full-screen window's own taskbar button). The key is now held back while the taskbar or other
  shell UI has the focus.
