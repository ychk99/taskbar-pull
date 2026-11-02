/*
  Taskbar Pull - brings a window to the screen whose taskbar you click.
  https://github.com/OWNER/taskbar-pull  ·  MIT licence  ·  Copyright (c) 2026 Yasser Chkam

  Runs on AutoHotkey v2. Shipped as the official AutoHotkey interpreter renamed TaskbarPull.exe
  next to this file: started without a script, AutoHotkey runs the .ahk file named after itself.

  Command line (all optional). AutoHotkey reads the first argument as the script file, so pass
  the script before any option:  TaskbarPull.exe TaskbarPull.ahk /quit
    /settings                      open the settings window (a plain second launch does the same)
    /quit                          ask a running Taskbar Pull to exit, then exit (used by the uninstaller)
    /admin-task create|delete USER SID
                                   elevated helper for admin mode: create or remove the scheduled
                                   task "Taskbar Pull (admin mode)"; exit code 0 = done
*/
#Requires AutoHotkey v2.0
#SingleInstance Off
#NoTrayIcon
#Warn All, Off
Persistent
KeyHistory 0
ListLines false
A_MaxHotkeysPerInterval := 1000
A_MenuMaskKey := ""     ; AutoHotkey never injects its own mask key; only the guarded SendMask() does
SetWorkingDir(A_ScriptDir)

#Include lib\Version.ahk
#Include lib\Settings.ahk
#Include lib\Log.ahk
#Include lib\Lang.ahk
#Include lib\Engine.ahk
#Include lib\Startup.ahk
#Include lib\Ui.ahk

global MSG_SHOW := 0x8001, MSG_QUIT := 0x8002   ; WM_APP + 1, + 2: sent by a second launch / the uninstaller

OnError(LogError)
EngineInit()
SettingsLoad()
Main()

Main() {
    args := A_Args.Clone()
    cmd := args.Length ? StrLower(args[1]) : ""
    if (cmd = "/admin-task") {
        ExitApp(AdminTaskCommand(args.Length >= 2 ? args[2] : "", args.Length >= 3 ? args[3] : CurrentUser()
            , args.Length >= 4 ? args[4] : ""))
    }
    if (cmd = "/quit") {
        ExitApp(QuitOthers() ? 0 : 1)
    }

    ; one instance per user session: a second launch opens the running instance's settings
    others := OtherInstances()
    if others.Length {
        o := others[1]
        if (A_IsAdmin && Elevation(o.pid) = "not elevated") {
            ; the admin-mode task started while a normal instance runs: take over from it
            QuitOthers()
        } else {
            DllCall("PostMessage", "ptr", o.hwnd, "uint", MSG_SHOW, "ptr", 0, "ptr", 0)
            ExitApp(0)
        }
    }
    ; let a normal (non-elevated) launch or the uninstaller reach an elevated instance
    for m in [MSG_SHOW, MSG_QUIT]
        DllCall("ChangeWindowMessageFilterEx", "ptr", A_ScriptHwnd, "uint", m, "uint", 1, "ptr", 0)
    OnMessage(MSG_SHOW, (*) => (SetTimer(() => SettingsShow(), -1), 1))
    OnMessage(MSG_QUIT, (*) => (SetTimer(() => ExitApp(0), -1), 1))
    OnMessage(0x7E, OnDisplayChange)        ; WM_DISPLAYCHANGE: refresh the screen lists
    OnExit(OnQuit)

    if !SettingsExist() {
        FirstRunShow(Started, FirstRunCancelled)
        return
    }
    ; admin mode: a normal launch (Start menu) hands over to the elevated task
    if (S.AdminMode && !A_IsAdmin && !IsPackaged()) {
        if !AdminTaskExists()
            Log("admin", "admin mode is on but its scheduled task is missing: running without administrator rights")
        else if HandOverToAdminTask()
            return
    }
    Started()
    if (cmd = "/settings")
        SettingsShow()
}

Started() {
    pid := DllCall("GetCurrentProcessId")
    Log("start", Format("Taskbar Pull {} started: pid {}, session {}, AutoHotkey {}, {} build, {}, language {}, settings {}"
        , AppVersion, pid, SessionOf(pid), A_AhkVersion, IsPackaged() ? "Store (MSIX " PackageFamilyName() ")" : "classic"
        , A_IsAdmin ? "elevated" : "not elevated", LangCode(), RealPath(ConfigFile())))
    TrayBuild()
    A_IconHidden := false
    if S.Enabled
        EngineStart()
    else
        Log("start", "disabled: nothing is hooked until it is enabled from the tray menu")
}

FirstRunCancelled() {
    Log("firstrun", "cancelled: nothing changed")
    if IsPackaged()           ; Windows enables the package's startup task on the first launch
        StoreStartupSet(false)
    ExitApp(0)
}

; Starts the elevated admin-mode task and exits once the elevated instance is up (true).
HandOverToAdminTask() {
    if !AdminTaskRun()
        return false
    loop 50 {                 ; up to 5 s
        Sleep 100
        for o in OtherInstances()
            if (Elevation(o.pid) != "not elevated") {
                Log("admin", "handed over to the elevated instance (pid " o.pid ")")
                ExitApp(0)
            }
    }
    Log("admin", "the admin-mode task did not start an elevated instance within 5 s: staying in normal mode")
    return false
}

; Other running Taskbar Pull instances of this user session: [{hwnd, pid}]
OtherInstances() {
    out := []
    dhw := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    me := DllCall("GetCurrentProcessId"), sess := SessionOf(me)
    for h in WinGetList("ahk_class AutoHotkey") {
        try {
            pid := WinGetPID(h)
            if (pid = me || SessionOf(pid) != sess)
                continue
            if RegExMatch(WinGetTitle(h), "i)\\TaskbarPull\.ahk - AutoHotkey")
                out.Push({hwnd: h, pid: pid})
        }
    }
    DetectHiddenWindows(dhw)
    return out
}

; Asks every other instance to exit; true when none is left after 5 s.
QuitOthers() {
    for o in OtherInstances()
        DllCall("PostMessage", "ptr", o.hwnd, "uint", MSG_QUIT, "ptr", 0, "ptr", 0)
    loop 50 {
        if !OtherInstances().Length
            return true
        Sleep 100
    }
    return false
}

OnQuit(reason, code) {
    EngineStop()
    Log("stop", "Taskbar Pull stopped (" reason ")")
}
