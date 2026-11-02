# Releasing Taskbar Pull

1. Update `CHANGELOG.md` and `src/lib/Version.ahk` (`AppVersion`).
2. Build and check locally:
   `pwsh build\get-tools.ps1; pwsh build\build.ps1 -Version X.Y.Z -RepoUrl https://github.com/<owner>/taskbar-pull -Scan`
3. Run the live tests while nobody uses the PC (`tests\run-cases.ps1`, `tests\run-ui.ps1`).
4. Commit, tag `vX.Y.Z`, push the tag. The `release` workflow builds everything on
   `windows-latest` and creates a **draft** release with the installer, portable zip, MSIX and
   `SHA256SUMS.txt`. Review it and click *Publish release*.
5. winget: copy `dist\winget\manifests\...\X.Y.Z\` (the workflow artifact has it) into a fork of
   `microsoft/winget-pkgs` under `manifests/y/YsIdeas/TaskbarPull/X.Y.Z/`, check that
   `InstallerUrl` points at the published release asset and `InstallerSha256` matches, run
   `winget validate --manifest <folder>` and `winget install --manifest <folder>` in a sandbox,
   then open the pull request. (Or `wingetcreate update YsIdeas.TaskbarPull -v X.Y.Z -u <url> --submit`
   after the first version is accepted.)
6. Microsoft Store: build the MSIX with the identity from Partner Center
   (`-IdentityName`, `-Publisher`, `-PublisherDisplayName` from *Product management > Product
   identity*), upload `TaskbarPull-X.Y.Z-x64.msix` in a new submission. The version must be higher
   than the last one submitted (the fourth part stays 0).

## MSIX notes

- Full-trust desktop app (`runFullTrust`), no elevation. Certification notes should say: "Win32
  desktop app (AutoHotkey interpreter + script). Uses a low-level mouse hook and SetWinEventHook to
  notice clicks on taskbar buttons, and SetWindowPos to move the clicked window to the screen of that
  taskbar. Sends one unassigned key (vkE8) while Alt is held after an Alt+click so the window does
  not enter menu mode; never into full-screen windows or games. The behaviour is explained and
  opt-in on first run (policy 10.2.8)."
- `windows.startupTask` `TaskbarPullStartup` is enabled in the manifest; Windows activates it after
  the first launch. The app reads and changes it through the WinRT `StartupTask` API.
- Settings and logs go to the virtualised AppData inside the package
  (`%LOCALAPPDATA%\Packages\<PackageFamilyName>\LocalCache\...`).
