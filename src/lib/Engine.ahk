; Taskbar Pull - engine: taskbar click detection, window placement and the game guard.
; Same engine as the original helper; settings come from the global S (see Settings.ahk).
;
; Clicking a window's button on a taskbar brings that window to the screen whose taskbar was
; clicked: minimized windows, background windows, the already-active toggle, combined-button
; thumbnails and Alt+click directly on a thumbnail. Maximized windows stay maximized, normal
; windows keep a proportional size across DPI and end up fully on the screen.
; Game guard: no key (mask key or Esc) is ever sent while the foreground window is full-screen
; or belongs to a listed game (exe name or path fragment).

global Armed := 0, Mask := 0, LastFg := 0, EngineOn := false
global ShellClasses := Map(), ShellExes := Map()
global WinEventCb := 0, Hooks := []

EngineInit() {
    for c in ["Shell_TrayWnd", "Shell_SecondaryTrayWnd", "TaskListThumbnailWnd", "XamlExplorerHostIslandWindow"
            , "Windows.UI.Core.CoreWindow", "Progman", "WorkerW", "NotifyIconOverflowWindow"
            , "TopLevelWindowForOverflowXamlIsland", "Shell_InputSwitchTopLevelWindow", "ForegroundStaging"
            , "MultitaskingViewFrame", "TaskSwitcherWnd", "#32768", "ApplicationManager_ImmersiveShellWindow"
            , "Windows.Internal.Shell.TabProxyWindow", "Xaml_WindowedPopupClass", "tooltips_class32", "SysShadow"
            , "Shell_LightDismissOverlay", "DV2ControlHost", "ControlCenterWindow", "Shell_Flyout"]
        ShellClasses[c] := 1
    for e in ["startmenuexperiencehost.exe", "shellexperiencehost.exe", "searchhost.exe", "searchapp.exe"
            , "shellhost.exe", "textinputhost.exe", "lockapp.exe", "widgets.exe", "widgetboard.exe"]
        ShellExes[e] := 1
}

; Installs the mouse hotkey and the WinEvent hooks. Nothing is hooked before this is called.
EngineStart() {
    global WinEventCb, Hooks, LastFg, EngineOn
    if EngineOn
        return
    PM()
    if !WinEventCb
        WinEventCb := CallbackCreate(OnWinEvent, , 7)
    for rng in [[3, 3], [0x14, 0x14], [0x16, 0x17]]   ; FOREGROUND, SWITCHSTART, MINIMIZESTART..END
        Hooks.Push(DllCall("SetWinEventHook", "uint", rng[1], "uint", rng[2], "ptr", 0, "ptr", WinEventCb
            , "uint", 0, "uint", 0, "uint", 2, "ptr"))     ; out of context, skip own process
    fg0 := DllCall("GetForegroundWindow", "ptr")
    LastFg := IsRealWin(fg0) ? fg0 : 0
    Hotkey("~*LButton", (*) => OnClick(), "On")
    EngineOn := true
    Log("start", Format("engine on | Alt+click: {} | plain click: {} | arm time {} s | {}"
        , S.AltClick ? "on" : "off", !S.PlainClick ? "off" : PlainDesc()
        , Round(S.ArmMs / 1000, 1), A_IsAdmin ? "elevated (admin mode)" : "not elevated"))
    Log("start", Format("game guard: no keys while the foreground is full-screen or one of: {} | paths containing: {}"
        , Join(S.GameExes), Join(S.GamePaths)))
    Log("start", "screens: " ScreensDesc())
}

EngineStop(reason := "") {
    global Hooks, EngineOn
    if !EngineOn
        return
    try Hotkey("~*LButton", "Off")
    for h in Hooks
        DllCall("UnhookWinEvent", "ptr", h)
    Hooks := []
    Disarm()
    EngineOn := false
    Log("stop", "engine off" (reason != "" ? " (" reason ")" : ""))
}

PlainDesc() {
    for scr in S.PlainScreens
        if (scr = "*")
            return "all screens"
    return S.PlainScreens.Length ? "screens " Join(S.PlainScreens) : "no screen chosen"
}

; Connected screens, in left-to-right order: [{name, hwid, gdi, rect, work, scale, primary}]
ScreenList() {
    list := []
    cb := CallbackCreate((hm, hdc, prc, lp) => (list.Push(MonInfo(hm)), 1), "F", 4)
    DllCall("EnumDisplayMonitors", "ptr", 0, "ptr", 0, "ptr", cb, "ptr", 0)
    CallbackFree(cb)
    ; sort by left edge (simple insertion sort)
    loop list.Length - 1 {
        i := A_Index + 1, m := list[i], j := i - 1
        while (j >= 1 && list[j].rect.l > m.rect.l)
            list[j + 1] := list[j], j--
        list[j + 1] := m
    }
    return list
}

; ---------------------------------------------------------------- click
OnClick() {
    global Armed
    PM()
    pt := Buffer(8, 0)
    DllCall("GetCursorPos", "ptr", pt)
    x := NumGet(pt, 0, "int"), y := NumGet(pt, 4, "int")
    alt := AltDown()
    hw := DllCall("WindowFromPoint", "int64", NumGet(pt, 0, "int64"), "ptr")
    root := hw ? DllCall("GetAncestor", "ptr", hw, "uint", 2, "ptr") : 0
    cls := WinCls(root)
    zone := ClickZone(root, cls)
    if (zone = "") {
        if alt
            Log("pass", Format("Alt+click at ({},{}) on [{}] outside the taskbar: passed through, nothing done", x, y, cls))
        if IsObject(Armed)
            Disarm(Format("click at ({},{}) on [{}], not the taskbar or its flyout", x, y, cls))
        return
    }
    mon := MonAt(x, y)
    if (alt && S.AltClick) {
        StartMask()
        Arm(zone = "flyout" ? "Alt+flyout" : "Alt", x, y, mon, cls)
    } else if (!alt && S.PlainClick && PlainMatch(mon)) {
        Arm(zone = "flyout" ? "plain+flyout" : "plain", x, y, mon, cls)
    } else if IsObject(Armed) {
        Armed.until := A_TickCount + S.ArmMs
        Log("flyout", Format("plain click at ({},{}) on [{}] while armed: request kept", x, y, cls))
    } else
        Log("plain", Format("plain click at ({},{}) on [{}] on screen {}: normal Windows behaviour, nothing done"
            , x, y, cls, mon ? mon.name : "?"))
}

ClickZone(root, cls) {
    if (cls = "Shell_TrayWnd" || cls = "Shell_SecondaryTrayWnd")
        return "taskbar"
    if (cls = "TaskListThumbnailWnd" || cls = "NotifyIconOverflowWindow" || cls = "TopLevelWindowForOverflowXamlIsland")
        return "flyout"
    if (cls = "XamlExplorerHostIslandWindow" && !IsSwitcher(root))     ; thumbnail flyout host (untitled, covers the screen)
        return "flyout"
    if (cls = "Windows.UI.Core.CoreWindow" && ShellExes.Has(StrLower(ExeName(PidOf(root)))))
        return "flyout"
    return ""
}

Arm(kind, x, y, mon, cls) {
    global Armed, LastFg
    fg := DllCall("GetForegroundWindow", "ptr")
    before := IsRealWin(fg) ? fg : (DllCall("IsWindow", "ptr", LastFg) ? LastFg : 0)
    Armed := {kind: kind, x: x, y: y, mon: mon, t0: A_TickCount, until: A_TickCount + S.ArmMs, before: before
        , beforeMon: before ? MonOfWin(before) : 0, beforeIconic: before ? IsIconic(before) : 0, done: false, pending: 0}
    Log("trigger", Format("{} click at ({},{}) on [{}] -> target screen {} | active window: {}"
        , kind, x, y, cls, MonDesc(mon), before ? WinDesc(before) " on " MonName(Armed.beforeMon) : "none"))
    SetTimer(ArmTick, 100)
}

ArmTick() {
    global Armed
    if !IsObject(Armed)
        SetTimer(ArmTick, 0)
    else if (!Armed.done && A_TickCount > Armed.until)
        Disarm("no window came forward within " Round(S.ArmMs / 1000, 1) " s")
}

Disarm(reason := "") {
    global Armed
    if (reason != "" && IsObject(Armed))
        Log("cancel", "request cancelled: " reason)
    Armed := 0
    SetTimer(ArmTick, 0)
}

; ---------------------------------------------------------------- menu-mode mask
; The mask key goes to whatever window is in the foreground, so every send first checks KeyBlock():
; nothing is sent to a full-screen window or a game process.
StartMask() {
    global Mask
    fg := DllCall("GetForegroundWindow", "ptr")
    Mask := {t0: A_TickCount, last: A_TickCount, fg: fg, sent: 0, skipped: 0}
    SendMask(fg, "at the click")
    SetTimer(MaskTick, 15)
}

MaskTick() {
    global Mask
    if !IsObject(Mask) {
        SetTimer(MaskTick, 0)
        return
    }
    if (AltDown() && A_TickCount - Mask.t0 < 30000) {
        fg := DllCall("GetForegroundWindow", "ptr")
        if (fg != Mask.fg) {
            Mask.fg := fg, Mask.last := A_TickCount
            SendMask(fg, "new foreground window")
        } else if (S.MaskRepeatMs > 0 && A_TickCount - Mask.last >= S.MaskRepeatMs) {
            Mask.last := A_TickCount
            SendMask(fg, "repeat")
        }
        return
    }
    SetTimer(MaskTick, 0)
    m := Mask, Mask := 0
    SetTimer(CheckMenuMode.Bind(m.sent, m.skipped), -80)
}

SendMask(fg, why) {
    global Mask
    ; Not while the taskbar or other shell UI has the focus: it does not need the key, and a key
    ; sent then can reach the window Windows activates a few ms later (a game, too). That window
    ; gets its own, checked, mask key when it comes forward.
    if IsShellUi(fg) {
        Mask.skipped += 1
        Log("menu", Format("held back mask key ({}): foreground is the taskbar or other shell UI [{}]", why, WinCls(fg)))
        return
    }
    if (r := KeyBlock(fg)) {
        Mask.skipped += 1
        Log("menu", Format("skipped mask key ({}): foreground is {}: {}", why, r, WinDesc(fg)))
        return
    }
    SendInput("{Blind}{vkE8}")
    Mask.sent += 1
}

IsShellUi(h) => h && (ShellClasses.Has(WinCls(h)) || ShellExes.Has(StrLower(ExeName(PidOf(h)))))

; "" when a key may be sent to window fg, otherwise why not ("full-screen" / "a game ...")
KeyBlock(fg) {
    if (!fg || !DllCall("IsWindow", "ptr", fg))
        return ""
    path := ExePath(PidOf(fg))
    if (path = "")
        return "a process whose image path cannot be read (treated as a game)"
    SplitPath(path, &name)
    for g in S.GameExes
        if (g != "" && name = g)
            return "a game (" name ")"
    for g in S.GamePaths
        if (g != "" && InStr(path, g))
            return "a game (" path ")"
    if IsFullScreen(fg)
        return "full-screen"
    return ""
}

; window rectangle covers its whole monitor (borderless or exclusive full-screen); shell windows
; (desktop, taskbar flyouts) and maximized windows with a caption bar do not count
IsFullScreen(h) {
    PM()
    cls := WinCls(h)
    if ShellClasses.Has(cls)
        return false
    exe := StrLower(ExeName(PidOf(h)))
    if (ShellExes.Has(exe) || exe = "explorer.exe")
        return false
    st := DllCall("GetWindowLongPtrW", "ptr", h, "int", -16, "ptr")
    if (IsZoomed(h) && (st & 0xC00000) = 0xC00000)      ; WS_CAPTION
        return false
    m := MonInfo(MonOfWin(h))
    if !m
        return false
    w := WinRect(h)
    return w.l <= m.rect.l && w.t <= m.rect.t && w.r >= m.rect.r && w.b >= m.rect.b
}

CheckMenuMode(n, skipped) {
    fg := DllCall("GetForegroundWindow", "ptr")
    tid := DllCall("GetWindowThreadProcessId", "ptr", fg, "ptr", 0, "uint")
    gti := Buffer(72, 0), NumPut("uint", 72, gti)
    ok := DllCall("GetGUIThreadInfo", "uint", tid, "ptr", gti)
    fl := ok ? NumGet(gti, 4, "uint") : 0
    inMenu := ok && (fl & 0x1C)     ; GUI_INMENUMODE | GUI_SYSTEMMENUMODE | GUI_POPUPMENUMODE
    msg := Format("Alt released; mask key sent {} time(s), skipped {} time(s); foreground {} menu mode: {}"
        , n, skipped, WinDesc(fg), !ok ? "unknown" : inMenu ? "YES (flags " fl ")" : "no")
    if inMenu {
        if (r := KeyBlock(fg))
            msg .= " -> Esc skipped: foreground is " r
        else {
            SendInput("{Esc}")
            msg .= " -> sent Esc to leave it"
        }
    }
    Log("menu", msg)
}

; ---------------------------------------------------------------- window events
OnWinEvent(hHook, event, hwnd, idObject, idChild, thread, time) {
    global Armed, LastFg
    if (idObject != 0)
        return
    PM()
    if (event = 3) {
        real := IsRealWin(hwnd)
        if real
            LastFg := hwnd
        if (!IsObject(Armed) || Armed.done)
            return
        if IsSwitcher(hwnd) {
            Disarm("Alt+Tab / Task View opened")
            return
        }
        if !real {
            Log("armed", Format("foreground went to shell UI [{}] `"{}`"", WinCls(hwnd), WinTitle(hwnd)))
            return
        }
        if (hwnd = Armed.before)
            return
        Armed.pending := hwnd
        SetTimer(DecideFg, -120)
    } else if (event = 0x14) {
        if (IsObject(Armed) && !Armed.done)
            Disarm("Alt+Tab switcher started")
    } else if (event = 0x16) {
        if (IsObject(Armed) && !Armed.done && hwnd = Armed.before && !Armed.beforeIconic)
            Toggled(hwnd)
    } else if (event = 0x17) {
        if (IsObject(Armed) && !Armed.done && IsRealWin(hwnd)) {
            a := Armed, a.done := true
            Pull(a, hwnd, "restored from minimized")
        }
    }
}

DecideFg() {
    global Armed
    if (!IsObject(Armed) || Armed.done || !Armed.pending)
        return
    a := Armed
    if (a.before && !a.beforeIconic && IsIconic(a.before)) {
        Toggled(a.before)
        return
    }
    a.done := true
    Pull(a, a.pending, "brought forward")
}

Toggled(w) {
    global Armed
    a := Armed, a.done := true
    Disarm()
    if (a.beforeMon = a.mon.h) {
        Log("decide", "click minimized the active window, which was on the target screen: left minimized | " WinDesc(w))
        return
    }
    Log("decide", "click minimized the active window on another screen: restoring it on the target screen | " WinDesc(w))
    SetTimer(() => MoveWin(w, a, "active window (toggle)", true), -30)
}

Pull(a, h, why) {
    Disarm()
    if !DllCall("IsWindow", "ptr", h)
        return
    own := DllCall("GetAncestor", "ptr", h, "uint", 3, "ptr")
    if (own && own != h && IsRealWin(own) && !IsIconic(own) && MonOfWin(own) = MonOfWin(h))
        MoveWin(own, a, why " (owner)", false)
    MoveWin(h, a, why, false)
}

; ---------------------------------------------------------------- move
MoveWin(h, a, why, activate) {
    PM()
    t0 := A_TickCount
    tgt := MonInfo(a.mon.h)
    if !tgt
        tgt := a.mon
    desc := WinDesc(h)
    srcH := MonOfWin(h)
    before := PlacementDesc(h)
    if (srcH = tgt.h) {
        Log("move", Format("{} | {} | already on target screen {}: not moved | {}", why, desc, tgt.name, before))
        return
    }
    wp := GetWP(h)
    iconic := IsIconic(h), zoomed := IsZoomed(h)
    maxed := zoomed || (iconic && (wp.flags & 2))
    src := MonInfo(DllCall("MonitorFromRect", "ptr", RectBuf(wp.n), "uint", 2, "ptr"))
    if !src
        src := MonInfo(srcH)
    nr := MapRect(wp.n, src.work, tgt.work)
    errs := ""
    if maxed {
        if !SetWP(h, 0, 3, nr)        ; restore rectangle on the target screen, show maximized
            errs .= "SetWindowPlacement error " A_LastError "; "
        if (MonOfWin(h) != tgt.h && IsZoomed(h)) {
            ; still maximized on the old screen: move the maximized window straight onto the target work area
            ; (same overhang as now, scaled to the target DPI), without restoring it first
            cur := MonInfo(srcH), w := WinRect(h), k := tgt.scale / cur.scale
            ol := Round((cur.work.l - w.l) * k), ot := Round((cur.work.t - w.t) * k)
            orr := Round((w.r - cur.work.r) * k), ob := Round((w.b - cur.work.b) * k)
            mr := {l: tgt.work.l - ol, t: tgt.work.t - ot, r: tgt.work.r + orr, b: tgt.work.b + ob}
            errs .= SetPos(h, mr)
            Sleep 40
            if !RectEq(WinRect(h), mr)
                errs .= SetPos(h, mr)
            if (MonOfWin(h) = tgt.h && IsZoomed(h))
                errs .= "(moved while maximized) "
        }
        if (MonOfWin(h) != tgt.h || !IsZoomed(h)) {
            DllCall("ShowWindow", "ptr", h, "int", 9)
            errs .= SetPos(h, nr)
            Sleep 30
            errs .= SetPos(h, nr)
            DllCall("ShowWindow", "ptr", h, "int", 3)
            errs .= "(used restore/move/maximize fallback) "
        }
    } else {
        if iconic {
            if !SetWP(h, 0, 9, nr)
                errs .= "SetWindowPlacement error " A_LastError "; "
        } else
            errs .= SetPos(h, nr)
        errs .= Settle(h, nr, tgt.work)
    }
    if activate
        DllCall("SetForegroundWindow", "ptr", h)
    ok := Inside(FrameRect(h), maxed ? tgt.rect : tgt.work) && MonOfWin(h) = tgt.h && !IsIconic(h)
    Log("move", Format("{} | {} | {} -> {} | before: {} | after: {} | {} ms | result: {}{}"
        , why, desc, src.name, MonDesc(tgt), before, PlacementDesc(h), A_TickCount - t0
        , ok ? "OK, fully on target screen" : "FAILED, not fully on target screen", errs != "" ? " | " errs : ""))
}

; apply the final rectangle after the window crossed to the new DPI, then fit it into the work area
Settle(h, r, work) {
    errs := ""
    loop 4 {
        Sleep 40
        if RectEq(WinRect(h), r)
            break
        errs .= SetPos(h, r)
    }
    f := FrameRect(h), w := WinRect(h)
    ml := f.l - w.l, mt := f.t - w.t, mr := w.r - f.r, mb := w.b - f.b
    fw := Min(f.r - f.l, work.r - work.l), fh := Min(f.b - f.t, work.b - work.t)
    fl := Max(work.l, Min(f.l, work.r - fw)), ft := Max(work.t, Min(f.t, work.b - fh))
    if (fl != f.l || ft != f.t || fw != f.r - f.l || fh != f.b - f.t)
        errs .= SetPos(h, {l: fl - ml, t: ft - mt, r: fl + fw + mr, b: ft + fh + mb})
    return errs
}

; (AutoHotkey names are case-insensitive: keep local names distinct from the parameters)
MapRect(r, srcWork, tgtWork) {
    sWid := srcWork.r - srcWork.l, sHgt := srcWork.b - srcWork.t, tWid := tgtWork.r - tgtWork.l, tHgt := tgtWork.b - tgtWork.t
    k := Min(tWid / sWid, tHgt / sHgt)
    nw := Min(Round((r.r - r.l) * k), tWid), nh := Min(Round((r.b - r.t) * k), tHgt)
    cx := tgtWork.l + ((r.l + r.r) / 2 - srcWork.l) * tWid / sWid
    cy := tgtWork.t + ((r.t + r.b) / 2 - srcWork.t) * tHgt / sHgt
    nl := Max(tgtWork.l, Min(Round(cx - nw / 2), tgtWork.r - nw)), nt := Max(tgtWork.t, Min(Round(cy - nh / 2), tgtWork.b - nh))
    return {l: nl, t: nt, r: nl + nw, b: nt + nh}
}

SetPos(h, r) {
    if DllCall("SetWindowPos", "ptr", h, "ptr", 0, "int", r.l, "int", r.t, "int", r.r - r.l, "int", r.b - r.t, "uint", 0x14)
        return ""
    return "SetWindowPos error " A_LastError (A_LastError = 5 ? " (access denied: elevated window?)" : "") "; "
}

; WINDOWPLACEMENT; rcNormalPosition is in workspace coordinates (offset by the primary work area)
GetWP(h) {
    wp := Buffer(44, 0), NumPut("uint", 44, wp)
    DllCall("GetWindowPlacement", "ptr", h, "ptr", wp)
    o := WsOffset()
    return {flags: NumGet(wp, 4, "uint"), show: NumGet(wp, 8, "uint")
        , n: {l: NumGet(wp, 28, "int") + o.x, t: NumGet(wp, 32, "int") + o.y, r: NumGet(wp, 36, "int") + o.x, b: NumGet(wp, 40, "int") + o.y}}
}

SetWP(h, flags, show, r) {
    wp := Buffer(44, 0), NumPut("uint", 44, wp)
    DllCall("GetWindowPlacement", "ptr", h, "ptr", wp)
    o := WsOffset()
    NumPut("uint", flags, "uint", show, wp, 4)
    NumPut("int", r.l - o.x, "int", r.t - o.y, "int", r.r - o.x, "int", r.b - o.y, wp, 28)
    return DllCall("SetWindowPlacement", "ptr", h, "ptr", wp)
}

WsOffset() {
    m := MonInfo(DllCall("MonitorFromPoint", "int64", 0, "uint", 1, "ptr"))
    return m ? {x: m.work.l - m.rect.l, y: m.work.t - m.rect.t} : {x: 0, y: 0}
}

PlacementDesc(h) {
    if !DllCall("IsWindow", "ptr", h)
        return "(window gone)"
    st := IsIconic(h) ? "minimized" : IsZoomed(h) ? "maximized" : "normal"
    w := FrameRect(h), wp := GetWP(h)
    return Format("{} frame[{},{},{},{} {}x{}] restore[{},{},{},{}] on {}", st, w.l, w.t, w.r, w.b, w.r - w.l, w.b - w.t
        , wp.n.l, wp.n.t, wp.n.r, wp.n.b, MonName(MonOfWin(h)))
}

; ---------------------------------------------------------------- monitors
MonAt(x, y) => MonInfo(DllCall("MonitorFromPoint", "int64", (y << 32) | (x & 0xFFFFFFFF), "uint", 2, "ptr"))
MonOfWin(h) => DllCall("MonitorFromWindow", "ptr", h, "uint", 2, "ptr")
MonName(hm) => (m := MonInfo(hm)) ? m.name : "?"

MonInfo(hm) {
    if !hm
        return 0
    mi := Buffer(104, 0), NumPut("uint", 104, mi)
    if !DllCall("GetMonitorInfoW", "ptr", hm, "ptr", mi)
        return 0
    dx := 96, dy := 96
    DllCall("shcore\GetDpiForMonitor", "ptr", hm, "int", 0, "uint*", &dx, "uint*", &dy)
    gdi := StrGet(mi.Ptr + 40, 32, "UTF-16")
    names := DisplayNames()
    n := names.Has(gdi) ? names[gdi] : {name: "", path: ""}
    hwid := RegExMatch(n.path, "i)DISPLAY#([^#]+)#", &mm) ? mm[1] : ""
    return {h: hm, gdi: gdi, name: n.name != "" ? n.name : gdi, path: n.path, hwid: hwid
        , rect: RectAt(mi, 4), work: RectAt(mi, 20), scale: Round(dx * 100 / 96)}
}

; GDI device name -> monitor friendly name and device path (QueryDisplayConfig, read live every time)
DisplayNames() {
    m := Map()
    np := 0, nm := 0
    if DllCall("GetDisplayConfigBufferSizes", "uint", 2, "uint*", &np, "uint*", &nm)
        return m
    paths := Buffer(72 * np, 0), modes := Buffer(64 * nm, 0)
    if DllCall("QueryDisplayConfig", "uint", 2, "uint*", &np, "ptr", paths, "uint*", &nm, "ptr", modes, "ptr", 0)
        return m
    loop np {
        p := (A_Index - 1) * 72
        src := Buffer(84, 0)
        NumPut("int", 1, "uint", 84, "int64", NumGet(paths, p, "int64"), "uint", NumGet(paths, p + 8, "uint"), src, 0)
        if DllCall("DisplayConfigGetDeviceInfo", "ptr", src)
            continue
        tg := Buffer(420, 0)
        NumPut("int", 2, "uint", 420, "int64", NumGet(paths, p + 20, "int64"), "uint", NumGet(paths, p + 28, "uint"), tg, 0)
        if DllCall("DisplayConfigGetDeviceInfo", "ptr", tg)
            continue
        m[StrGet(src.Ptr + 20, 32, "UTF-16")] := {name: StrGet(tg.Ptr + 36, 64, "UTF-16"), path: StrGet(tg.Ptr + 164, 128, "UTF-16")}
    }
    return m
}

PlainMatch(mon) {
    if !mon
        return false
    for scr in S.PlainScreens      ; (AutoHotkey names ignore case: never call a local "s")
        if (scr = "*" || (scr != "" && (mon.name = scr || mon.hwid = scr || InStr(mon.path, scr))))
            return true
    return false
}

MonDesc(m) => m ? Format("`"{}`" ({}, {}) [{},{},{},{}] {}%", m.name, m.hwid, m.gdi, m.rect.l, m.rect.t, m.rect.r, m.rect.b, m.scale) : "?"

ScreensDesc() {
    list := []
    cb := CallbackCreate((hm, hdc, prc, lp) => (list.Push(MonDesc(MonInfo(hm))), 1), "F", 4)
    DllCall("EnumDisplayMonitors", "ptr", 0, "ptr", 0, "ptr", cb, "ptr", 0)
    CallbackFree(cb)
    return Join(list, " | ")
}

; ---------------------------------------------------------------- window helpers
IsRealWin(h) {
    if (!h || !DllCall("IsWindow", "ptr", h) || !DllCall("IsWindowVisible", "ptr", h))
        return false
    if (DllCall("GetAncestor", "ptr", h, "uint", 2, "ptr") != h)
        return false
    if ShellClasses.Has(WinCls(h))
        return false
    ex := DllCall("GetWindowLongPtrW", "ptr", h, "int", -20, "ptr")
    if ((ex & 0x80) || (ex & 0x08000000)) && !(ex & 0x40000)     ; tool / no-activate window without APPWINDOW
        return false
    if Cloaked(h)
        return false
    return !ShellExes.Has(StrLower(ExeName(PidOf(h))))
}

IsSwitcher(h) {
    c := WinCls(h)
    if (c = "MultitaskingViewFrame" || c = "TaskSwitcherWnd")
        return true
    if (c = "XamlExplorerHostIslandWindow") {
        t := WinTitle(h)     ; Alt+Tab and Task View are titled; the taskbar thumbnail flyout is not
        return (t = "Task Switching" || t = "Task View" || InStr(t, "tâche") || InStr(t, "Task"))
    }
    return false
}

Cloaked(h) {
    v := 0
    DllCall("dwmapi\DwmGetWindowAttribute", "ptr", h, "uint", 14, "uint*", &v, "uint", 4)
    return v
}

WinDesc(h) {
    if (!h || !DllCall("IsWindow", "ptr", h))
        return "(none)"
    pid := PidOf(h)
    return Format("`"{}`" [{}] {} pid {} {}", WinTitle(h), WinCls(h), ExeName(pid), pid, Elevation(pid))
}

WinTitle(h) {
    b := Buffer(1024, 0)
    DllCall("GetWindowTextW", "ptr", h, "ptr", b, "int", 512)
    return StrGet(b, "UTF-16")
}
WinCls(h) {
    if !h
        return ""
    b := Buffer(512, 0)
    DllCall("GetClassNameW", "ptr", h, "ptr", b, "int", 256)
    return StrGet(b, "UTF-16")
}
PidOf(h) {
    pid := 0
    DllCall("GetWindowThreadProcessId", "ptr", h, "uint*", &pid)
    return pid
}
ExeName(pid) {
    if ((p := ExePath(pid)) = "")
        return "?"
    SplitPath(p, &name)
    return name
}
ExePath(pid) {
    hp := DllCall("OpenProcess", "uint", 0x1000, "int", 0, "uint", pid, "ptr")
    if !hp
        return ""
    b := Buffer(2048, 0), n := 1024
    ok := DllCall("QueryFullProcessImageNameW", "ptr", hp, "uint", 0, "ptr", b, "uint*", &n)
    DllCall("CloseHandle", "ptr", hp)
    return ok ? StrGet(b, "UTF-16") : ""
}
Elevation(pid) {
    hp := DllCall("OpenProcess", "uint", 0x1000, "int", 0, "uint", pid, "ptr")
    if !hp
        return "elevation unknown"
    tok := 0, el := 0, ret := 0, res := "elevation unknown"
    if DllCall("advapi32\OpenProcessToken", "ptr", hp, "uint", 8, "ptr*", &tok) {
        if DllCall("advapi32\GetTokenInformation", "ptr", tok, "int", 20, "uint*", &el, "uint", 4, "uint*", &ret)
            res := el ? "elevated" : "not elevated"
        DllCall("CloseHandle", "ptr", tok)
    }
    DllCall("CloseHandle", "ptr", hp)
    return res
}
SessionOf(pid) {
    s := -1
    DllCall("ProcessIdToSessionId", "uint", pid, "uint*", &s)
    return s
}
IsIconic(h) => DllCall("IsIconic", "ptr", h)
IsZoomed(h) => DllCall("IsZoomed", "ptr", h)
AltDown() => DllCall("GetAsyncKeyState", "int", 0x12, "short") < 0
PM() => DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

WinRect(h) {
    b := Buffer(16, 0)
    DllCall("GetWindowRect", "ptr", h, "ptr", b)
    return RectAt(b, 0)
}
FrameRect(h) {
    b := Buffer(16, 0)
    if DllCall("dwmapi\DwmGetWindowAttribute", "ptr", h, "uint", 9, "ptr", b, "uint", 16)
        return WinRect(h)
    return RectAt(b, 0)
}
RectAt(b, o) => {l: NumGet(b, o, "int"), t: NumGet(b, o + 4, "int"), r: NumGet(b, o + 8, "int"), b: NumGet(b, o + 12, "int")}
RectBuf(r) {
    b := Buffer(16, 0)
    NumPut("int", r.l, "int", r.t, "int", r.r, "int", r.b, b)
    return b
}
RectEq(a, b) => a.l = b.l && a.t = b.t && a.r = b.r && a.b = b.b
Inside(r, a) => r.l >= a.l && r.t >= a.t && r.r <= a.r && r.b <= a.b

Join(arr, sep := ", ") {
    s := ""
    for v in arr
        s .= (A_Index > 1 ? sep : "") v
    return s
}

