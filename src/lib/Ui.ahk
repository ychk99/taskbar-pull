; Taskbar Pull - tray icon, first-run dialog, settings window and About box.

global SetGui := 0, FirstGui := 0, AboutGui := 0
global UiW := 540           ; width of the text column, in dialog units at 100 %

IconFile(off := false) => A_ScriptDir "\assets\TaskbarPull" (off ? "-off" : "") ".ico"

; ---------------------------------------------------------------- tray
TrayBuild() {
    m := A_TrayMenu
    m.Delete()
    m.Add(T("tray.enabled"), (*) => ToggleEnabled())
    m.Add(T("tray.settings"), (*) => SettingsShow())
    m.Add(T("tray.logs"), (*) => OpenLogFolder())
    m.Add(T("tray.about"), (*) => AboutShow())
    m.Add()
    m.Add(T("tray.exit"), (*) => ExitApp())
    m.Default := T("tray.settings")
    m.ClickCount := 2
    TrayUpdate()
}

TrayUpdate() {
    if S.Enabled
        A_TrayMenu.Check(T("tray.enabled"))
    else
        A_TrayMenu.Uncheck(T("tray.enabled"))
    try TraySetIcon(IconFile(!S.Enabled), , true)
    tip := T("tip.off")
    if S.Enabled {
        parts := []
        if S.AltClick
            parts.Push(T("tip.alt"))
        if S.PlainClick
            parts.Push(PlainIsAll() ? T("tip.plain.all") : T("tip.plain.some", Join(S.PlainScreens)))
        if A_IsAdmin
            parts.Push(T("tip.admin"))
        tip := T("tip.on", Join(parts))
    }
    A_IconTip := SubStr(tip, 1, 127)
}

PlainIsAll() {
    for scr in S.PlainScreens
        if (scr = "*")
            return true
    return false
}

ToggleEnabled() {
    S.Enabled := !S.Enabled
    SettingsSave()
    if S.Enabled
        EngineStart()
    else
        EngineStop("disabled from the tray menu")
    Log("tray", S.Enabled ? "enabled from the tray menu" : "disabled from the tray menu")
    TrayUpdate()
    if SetGui
        try SetGui["Enabled"].Value := S.Enabled
}

OpenLogFolder() {
    try DirCreate(LogDir())
    Run('explorer.exe "' RealPath(LogDir()) '"')
}

; ---------------------------------------------------------------- shared pieces
NewDialog(title) {
    g := Gui("-MinimizeBox -MaximizeBox", title)
    g.SetFont("s9", "Segoe UI")
    g.MarginX := 16, g.MarginY := 14
    return g
}

; ListView of screens with check boxes: connected screens, plus chosen ones not connected now
AddScreenList(g, chosen, opts := "") {
    lv := g.AddListView("w" (UiW - 40) " r4 Checked -Multi NoSortHdr " opts
        , LangCode() = "fr" ? ["Écran", "Mise à l'échelle", "Position"] : ["Screen", "Scaling", "Position"])
    FillScreenList(lv, chosen)
    return lv
}

FillScreenList(lv, chosen) {
    lv.Opt("-Redraw")
    lv.Delete()
    seen := Map()
    for m in ScreenList() {
        name := m.name
        seen[name] := 1
        on := false
        for c in chosen
            if (c = name || c = m.hwid)
                on := true
        lv.Add(on ? "Check" : "", name, m.scale "%", Format("{},{} {}x{}", m.rect.l, m.rect.t, m.rect.r - m.rect.l, m.rect.b - m.rect.t))
    }
    for c in chosen
        if (c != "*" && !seen.Has(c))
            lv.Add("Check", T("opt.notconnected", c), "", "")
    lv.ModifyCol(1, 230), lv.ModifyCol(2, 110), lv.ModifyCol(3, "AutoHdr")
    lv.Opt("+Redraw")
}

; names of the checked screens (strips the "(not connected)" suffix)
CheckedScreens(lv) {
    out := [], row := 0
    while (row := lv.GetNext(row, "Checked")) {
        name := lv.GetText(row, 1)
        if (lv.GetText(row, 2) = "" && RegExMatch(name, "^(.*) \([^()]*\)$", &m))
            name := m[1]
        out.Push(name)
    }
    return out
}

OnDisplayChange(*) {
    SetTimer(RefreshScreenLists, -1500)     ; let Windows finish setting up the new screen layout
}
RefreshScreenLists() {
    Log("screens", "screens changed: " ScreensDesc())
    for g in [FirstGui, SetGui]
        if g
            try FillScreenList(g["Screens"], CheckedScreens(g["Screens"]))
}

SyncPlainControls(g) {
    on := g["Plain"].Value
    g["PlainAll"].Enabled := on, g["PlainSome"].Enabled := on
    g["Screens"].Enabled := on && g["PlainSome"].Value
}

AddClickOptions(g, s, x0 := 8) {
    g.AddCheckbox("vAlt xm+" x0 " y+8 w" (UiW - x0) (s.AltClick ? " Checked" : ""), T("opt.alt"))
    g.AddCheckbox("vPlain xm+" x0 " y+6 w" (UiW - x0) (s.PlainClick ? " Checked" : ""), T("opt.plain"))
        .OnEvent("Click", (c, *) => SyncPlainControls(c.Gui))
    all := false
    for v in s.PlainScreens
        if (v = "*")
            all := true
    g.AddRadio("vPlainAll xm+" (x0 + 22) " y+6 Group w" (UiW - x0 - 22) (all ? " Checked" : ""), T("opt.all"))
        .OnEvent("Click", (c, *) => SyncPlainControls(c.Gui))
    g.AddRadio("vPlainSome xm+" (x0 + 22) " y+4 w" (UiW - x0 - 22) (all ? "" : " Checked"), T("opt.chosen"))
        .OnEvent("Click", (c, *) => SyncPlainControls(c.Gui))
    chosen := []
    for v in s.PlainScreens
        if (v != "*")
            chosen.Push(v)
    AddScreenList(g, chosen, "vScreens xm+" (x0 + 40) " y+4")
    SyncPlainControls(g)
}

ReadClickOptions(g, s) {
    s.AltClick := g["Alt"].Value
    s.PlainClick := g["Plain"].Value
    s.PlainScreens := g["PlainAll"].Value ? ["*"] : CheckedScreens(g["Screens"])
}

AddHeader(g, title) {
    try g.AddPicture("xm ym w40 h40 Icon1", IconFile())
    g.SetFont("s13 w600")
    g.AddText("x+12 yp+8", title)
    g.SetFont("s9 w400")
}

; ---------------------------------------------------------------- first run
; Shows the consent dialog. Nothing is changed (no hook, no settings file, no startup entry)
; until the user clicks Start. onStart is called after the settings are saved.
FirstRunShow(onStart, onCancel) {
    global FirstGui
    g := NewDialog(T("fr.title"))
    FirstGui := g
    AddHeader(g, T("fr.title"))
    g.AddText("xm y+16 w" UiW, T("fr.intro"))
    g.AddText("xm y+12 w" UiW, T("fr.choose"))
    AddClickOptions(g, S)
    ; installed by the installer without its "start with Windows" choice: start unchecked
    installedNoRun := FileExist(A_ScriptDir "\unins000.exe") && RunEntryGet() = ""
    g.AddCheckbox("vStartup xm+8 y+10 w" (UiW - 8) (installedNoRun ? "" : " Checked"), T("opt.startup"))
    g.SetFont("cGray")
    g.AddText("xm y+14 w" UiW, T("fr.note"))
    g.SetFont("cDefault")
    g.AddButton("vStart xm+" (UiW - 230) " y+16 w110 Default", T("fr.start")).OnEvent("Click", Confirm)
    g.AddButton("x+10 w110", T("fr.cancel")).OnEvent("Click", Cancel)
    g.OnEvent("Close", Cancel)
    g.OnEvent("Escape", Cancel)
    g.Show("AutoSize Center")
    Log("firstrun", "first-run dialog shown (" LangCode() ")")

    Confirm(*) {
        global FirstGui
        ReadClickOptions(g, S)
        S.StartWithWindows := g["Startup"].Value
        S.Enabled := true
        g.Destroy(), FirstGui := 0
        SettingsSave()
        Log("firstrun", Format("confirmed: Alt+click {}, plain click {}, start with Windows {}"
            , S.AltClick ? "on" : "off", S.PlainClick ? PlainDesc() : "off", S.StartWithWindows ? "on" : "off"))
        if (err := StartupApply()) != ""
            MsgBox(err, "Taskbar Pull", "Icon!")
        onStart()
    }
    Cancel(*) {
        global FirstGui
        g.Destroy(), FirstGui := 0
        onCancel()
    }
}

; ---------------------------------------------------------------- settings
SettingsShow(tab := 1) {
    global SetGui
    if SetGui {
        SetGui.Show()
        return
    }
    g := NewDialog(T("set.title"))
    SetGui := g
    tabs := g.AddTab3("vTabs xm ym w" (UiW + 24) " h440", StrSplit(T("set.tabs"), "|"))

    ; -- General
    tabs.UseTab(1)
    g.AddCheckbox("vEnabled xm+12 y+12 w" UiW (S.Enabled ? " Checked" : ""), T("opt.enabled"))
    AddClickOptions(g, S, 12)
    pk := IsPackaged()
    g.AddCheckbox("vStartup xm+12 y+12 w" (UiW - 12), T("opt.startup"))
    if pk {
        st := StoreStartupState()
        g["Startup"].Value := st = 2 || st = 4
        g.SetFont("cGray")
        g.AddText("xm+34 y+4 w" (UiW - 34), T("set.startup.store"))
        g.SetFont("cDefault")
        g.AddButton("xm+34 y+4", T("set.startup.open")).OnEvent("Click", (*) => Run("ms-settings:startupapps"))
    } else
        g["Startup"].Value := S.StartWithWindows || S.AdminMode
    g.AddText("xm+12 y+16", T("opt.lang"))
    langs := [T("opt.lang.auto"), "English", "Français"]
    g.AddDropDownList("vLang x+8 yp-3 w220 Choose" (S.Language = "en" ? 2 : S.Language = "fr" ? 3 : 1), langs)

    ; -- Game guard
    tabs.UseTab(2)
    g.AddText("xm+12 y+12 w" UiW, T("set.guard.intro"))
    g.AddText("xm+12 y+12 w" UiW, T("set.guard.exes"))
    g.AddEdit("vGameExes xm+12 y+4 w" UiW " r6 -Wrap HScroll", Join(S.GameExes, "`n"))
    g.AddText("xm+12 y+10 w" UiW, T("set.guard.paths"))
    g.AddEdit("vGamePaths xm+12 y+4 w" UiW " r8 -Wrap HScroll", Join(S.GamePaths, "`n"))
    g.AddButton("xm+12 y+8", T("set.guard.reset")).OnEvent("Click", ResetGuard)

    ; -- Advanced
    tabs.UseTab(3)
    g.AddText("xm+12 y+14", T("opt.arm"))
    g.AddEdit("vArm x+8 yp-3 w60 Number", Round(S.ArmMs / 1000))
    g.AddUpDown("Range2-30", Round(S.ArmMs / 1000))
    g.AddCheckbox("vLogging xm+12 y+14 w" UiW (S.Logging ? " Checked" : ""), T("opt.logging", S.LogKeepDays))
    g.AddButton("xm+30 y+6", T("set.logs")).OnEvent("Click", (*) => OpenLogFolder())
    if !pk {
        g.AddCheckbox("vAdmin xm+12 y+18 w" UiW (S.AdminMode ? " Checked" : ""), T("set.admin"))
            .OnEvent("Click", (c, *) => SyncAdmin(c.Gui))
        g.SetFont("cGray")
        g.AddText("xm+30 y+4 w" (UiW - 18), T("set.admin.note"))
        g.SetFont("cDefault")
        SyncAdmin(g)
    } else {
        g.SetFont("cGray")
        g.AddText("xm+12 y+18 w" UiW, T("set.admin.store"))
        g.SetFont("cDefault")
    }

    tabs.UseTab()
    tabs.GetPos(, &tabY, , &tabH)          ; buttons go below the tab control, whichever tab was filled last
    g.AddButton("vOk xm+" (UiW - 324) " y" (tabY + tabH + 12) " w110 Default", T("set.ok")).OnEvent("Click", (*) => Apply(true))
    g.AddButton("x+8 w110", T("set.cancel")).OnEvent("Click", Close)
    g.AddButton("vApply x+8 w110", T("set.apply")).OnEvent("Click", (*) => Apply(false))
    g.OnEvent("Close", Close)
    g.OnEvent("Escape", Close)
    tabs.Choose(tab)
    g.Show("AutoSize Center")

    ResetGuard(*) {
        g["GameExes"].Value := Join(DefaultGameExes, "`n")
        g["GamePaths"].Value := Join(DefaultGamePaths, "`n")
    }
    Close(*) {
        global SetGui
        g.Destroy(), SetGui := 0
    }
    Apply(close) {
        global SetGui
        oldLang := LangCode(), wasOn := S.Enabled
        S.Enabled := g["Enabled"].Value
        ReadClickOptions(g, S)
        S.StartWithWindows := g["Startup"].Value
        S.Language := ["auto", "en", "fr"][g["Lang"].Value]
        S.GameExes := SplitList(g["GameExes"].Value)
        S.GamePaths := SplitList(g["GamePaths"].Value)
        S.ArmMs := Clamp(Number0(g["Arm"].Value), 2, 30) * 1000
        S.Logging := g["Logging"].Value
        if !pk
            S.AdminMode := g["Admin"].Value
        SettingsSave()
        err := StartupApply()      ; may show a UAC prompt for admin mode
        SettingsSave()             ; StartupApply may have reverted admin mode
        Log("settings", Format("saved: enabled {}, Alt+click {}, plain click {}, start with Windows {}, admin mode {}, language {}, logging {}, arm {} s"
            , S.Enabled, S.AltClick, S.PlainClick ? PlainDesc() : "off", S.StartWithWindows, S.AdminMode, S.Language, S.Logging, S.ArmMs // 1000))
        EngineStop("settings changed")
        if S.Enabled
            EngineStart()
        if !pk
            try g["Admin"].Value := S.AdminMode
        if (oldLang != LangCode())
            TrayBuild()
        else
            TrayUpdate()
        if (err != "")
            MsgBox(err, "Taskbar Pull", "Icon! Owner" g.Hwnd)
        ; admin mode just switched on from a normal instance: hand over to the elevated one
        if (!pk && S.AdminMode && !A_IsAdmin && err = "")
            SetTimer(HandOverToAdminTask, -200)
        if (close || oldLang != LangCode()) {
            g.Destroy(), SetGui := 0
            if (!close)
                SettingsShow(3)
        }
    }
}

SyncAdmin(g) {
    ; in admin mode the task starts the app with Windows, so "start with Windows" is implied
    if g["Admin"].Value
        g["Startup"].Value := 1
    g["Startup"].Enabled := !g["Admin"].Value
}

; ---------------------------------------------------------------- about
AboutShow() {
    global AboutGui
    if AboutGui {
        AboutGui.Show()
        return
    }
    g := NewDialog(T("about.title"))
    AboutGui := g
    AddHeader(g, "Taskbar Pull")
    g.AddText("xm y+16 w380", T("about.text", AppVersion, IsPackaged() ? T("about.store") : "", A_AhkVersion))
    g.AddText("xm y+12", T("about.site"))
    g.AddLink("xm y+4", '<a href="' ProjectUrl '">' ProjectUrl '</a>')
    g.AddButton("xm+270 y+16 w110 Default", "OK").OnEvent("Click", AboutClose)
    g.OnEvent("Close", AboutClose)
    g.OnEvent("Escape", AboutClose)
    g.Show("AutoSize Center")
}
AboutClose(*) {
    global AboutGui
    if AboutGui
        AboutGui.Destroy()
    AboutGui := 0
}
