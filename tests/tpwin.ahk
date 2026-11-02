; Test window for the Taskbar Pull test harness (tests\harness.ps1).
; Run through a renamed copy of AutoHotkey64.exe (TPTestA.exe ...) so each test app has its own
; taskbar button:  TPTestA.exe tpwin.ahk <title> <kind> [<keylog file>]
;   kind: plain | menu (classic menu bar) | full (borderless, covers its monitor, logs every key message)
; Prints nothing; the harness finds the window by its title and positions it.
#Requires AutoHotkey v2.0
#SingleInstance Off
#NoTrayIcon
title := A_Args.Length >= 1 ? A_Args[1] : "Taskbar Pull test"
kind := A_Args.Length >= 2 ? A_Args[2] : "plain"
keylog := A_Args.Length >= 3 ? A_Args[3] : ""

g := Gui((kind = "full" ? "-Caption -Border " : "+Resize ") , title)
g.SetFont("s14", "Segoe UI")
if (kind = "menu") {
    mb := MenuBar()
    fm := Menu()
    fm.Add("Nothing", (*) => 0)
    mb.Add("&File", fm)
    mb.Add("&Edit", fm)
    g.MenuBar := mb
}
g.BackColor := kind = "full" ? "202020" : "F4F4F4"
g.AddText("x20 y20 w600 c" (kind = "full" ? "White" : "Black"), title " - Taskbar Pull test window (" kind ")")
g.OnEvent("Close", (*) => ExitApp())
g.Show("w700 h450 NoActivate")

if (kind = "full" && keylog != "") {
    names := Map(0x100, "WM_KEYDOWN", 0x101, "WM_KEYUP", 0x104, "WM_SYSKEYDOWN", 0x105, "WM_SYSKEYUP", 0x1C, "WM_ACTIVATEAPP")
    for msg, nm in names
        OnMessage(msg, LogMsg.Bind(nm))
    LogMsg(nm, wp, lp, msg, hwnd) {
        extra := msg = 0x1C ? (wp ? "activated" : "deactivated") : Format("vk{:X}{}", wp, (lp >> 30) & 1 ? " repeat=1" : "")
        FileAppend(FormatTime(, "HH:mm:ss") "." A_MSec " " nm " " extra "`n", keylog, "UTF-8")
    }
}
