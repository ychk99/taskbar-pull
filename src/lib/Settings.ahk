; Taskbar Pull - settings (%APPDATA%\Taskbar Pull\settings.ini) and per-user paths.
; In the Store (MSIX) build Windows redirects these AppData paths into the package's own
; folder; RealPath() gives the redirected location for Explorer.

global S := {}
global DefaultGameExes := ["League of Legends.exe", "VALORANT-Win64-Shipping.exe"]
; standard game folders of the common launchers (fragments of the game's image path)
global DefaultGamePaths := ["\steamapps\common\", "\Riot Games\", "\Epic Games\", "\GOG Galaxy\Games\"
    , "\EA Games\", "\Ubisoft Game Launcher\games\", "\XboxGames\", "\Amazon Games\Library\"
    , "\Rockstar Games\", "\itch\apps\"]

ConfigDir() => EnvGet("APPDATA") "\Taskbar Pull"
ConfigFile() => ConfigDir() "\settings.ini"
LogDir() => EnvGet("LOCALAPPDATA") "\Taskbar Pull\logs"

SettingsDefaults() {
    return {Enabled: true, AltClick: true, PlainClick: false, PlainScreens: ["*"], ArmMs: 8000
        , Logging: true, StartWithWindows: true, Language: "auto", AdminMode: false, MaskRepeatMs: 0
        , GameExes: DefaultGameExes.Clone(), GamePaths: DefaultGamePaths.Clone(), LogKeepDays: 14}
}

SettingsExist() => FileExist(ConfigFile()) && IniRead(ConfigFile(), "General", "FirstRunDone", "0") = "1"

SettingsLoad() {
    global S
    S := SettingsDefaults()
    f := ConfigFile()
    if !FileExist(f)
        return S
    rb(k, d) => (v := IniRead(f, "General", k, d ? "1" : "0")) = "1" || v = "true" || v = "yes"
    S.Enabled := rb("Enabled", S.Enabled)
    S.AltClick := rb("AltClick", S.AltClick)
    S.PlainClick := rb("PlainClick", S.PlainClick)
    S.PlainScreens := SplitList(IniRead(f, "General", "PlainScreens", "*"))
    S.ArmMs := Clamp(Round(Number0(IniRead(f, "General", "ArmSeconds", "8")) * 1000), 2000, 30000)
    S.Logging := rb("Logging", S.Logging)
    S.StartWithWindows := rb("StartWithWindows", S.StartWithWindows)
    lang := StrLower(IniRead(f, "General", "Language", "auto"))
    S.Language := (lang = "en" || lang = "fr") ? lang : "auto"
    S.AdminMode := rb("AdminMode", S.AdminMode)
    S.MaskRepeatMs := Clamp(Number0(IniRead(f, "Advanced", "MaskRepeatMs", "0")), 0, 5000)
    S.LogKeepDays := Clamp(Number0(IniRead(f, "Advanced", "LogKeepDays", "14")), 1, 365)
    S.GameExes := SplitList(IniRead(f, "GameGuard", "GameExes", Join(DefaultGameExes, "|")))
    S.GamePaths := SplitList(IniRead(f, "GameGuard", "GamePaths", Join(DefaultGamePaths, "|")))
    return S
}

SettingsSave() {
    DirCreate(ConfigDir())
    f := ConfigFile()
    b(v) => v ? "1" : "0"
    IniWrite("1", f, "General", "FirstRunDone")
    IniWrite(AppVersion, f, "General", "Version")
    IniWrite(b(S.Enabled), f, "General", "Enabled")
    IniWrite(b(S.AltClick), f, "General", "AltClick")
    IniWrite(b(S.PlainClick), f, "General", "PlainClick")
    IniWrite(Join(S.PlainScreens, "|"), f, "General", "PlainScreens")
    IniWrite(Round(S.ArmMs / 1000, 1), f, "General", "ArmSeconds")
    IniWrite(b(S.Logging), f, "General", "Logging")
    IniWrite(b(S.StartWithWindows), f, "General", "StartWithWindows")
    IniWrite(S.Language, f, "General", "Language")
    IniWrite(b(S.AdminMode), f, "General", "AdminMode")
    IniWrite(Join(S.GameExes, "|"), f, "GameGuard", "GameExes")
    IniWrite(Join(S.GamePaths, "|"), f, "GameGuard", "GamePaths")
    IniWrite(S.MaskRepeatMs, f, "Advanced", "MaskRepeatMs")
    IniWrite(S.LogKeepDays, f, "Advanced", "LogKeepDays")
}

SplitList(s) {
    out := []
    for v in StrSplit(s, ["|", "`n"], " `t`r")
        if (v != "")
            out.Push(v)
    return out
}

Number0(v) => IsNumber(v) ? v + 0 : 0
Clamp(v, lo, hi) => Max(lo, Min(hi, v))

; ---------------------------------------------------------------- MSIX detection
; true when the app runs as an MSIX package (the Store build)
IsPackaged() {
    static r := ""
    if (r = "") {
        n := 0
        r := DllCall("GetCurrentPackageFullName", "uint*", &n, "ptr", 0) != 15700   ; APPMODEL_ERROR_NO_PACKAGE
    }
    return r
}

PackageFamilyName() {
    n := 0
    DllCall("GetCurrentPackageFamilyName", "uint*", &n, "ptr", 0)
    if !n
        return ""
    b := Buffer(n * 2, 0)
    return DllCall("GetCurrentPackageFamilyName", "uint*", &n, "ptr", b) ? "" : StrGet(b, "UTF-16")
}

; Where a per-user AppData path really is (MSIX redirects AppData writes into LocalCache)
RealPath(p) {
    if !IsPackaged()
        return p
    pfn := PackageFamilyName(), la := EnvGet("LOCALAPPDATA"), ra := EnvGet("APPDATA")
    base := la "\Packages\" pfn "\LocalCache"
    if (SubStr(p, 1, StrLen(la)) = la && DirExist(base "\Local" SubStr(p, StrLen(la) + 1)))
        return base "\Local" SubStr(p, StrLen(la) + 1)
    if (SubStr(p, 1, StrLen(ra)) = ra && DirExist(base "\Roaming" SubStr(p, StrLen(ra) + 1)))
        return base "\Roaming" SubStr(p, StrLen(ra) + 1)
    return p
}
