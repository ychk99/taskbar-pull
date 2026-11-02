; Taskbar Pull - log: one file per day in %LOCALAPPDATA%\Taskbar Pull\logs
; (taskbar-pull-YYYY-MM-DD.log). A day's file that passes 5 MB is renamed to .log.1;
; files older than LogKeepDays (14 by default) are removed at start and at each new day.

global LogMaxBytes := 5 * 1024 * 1024, LogDay := ""

LogPath() => LogDir() "\taskbar-pull-" FormatTime(, "yyyy-MM-dd") ".log"

Log(kind, msg) {
    global LogDay
    if (!IsObject(S) || !S.HasOwnProp("Logging") || !S.Logging)
        return
    try {
        day := FormatTime(, "yyyy-MM-dd")
        if (day != LogDay) {
            LogDay := day
            DirCreate(LogDir())
            LogPrune()
        }
        f := LogPath()
        if (FileExist(f) && FileGetSize(f) > LogMaxBytes)
            FileMove(f, f ".1", 1)
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") "." A_MSec " [" kind "] " msg "`n", f, "UTF-8")
    }
}

LogPrune() {
    keep := S.HasOwnProp("LogKeepDays") ? S.LogKeepDays : 14
    cutoff := DateAdd(A_Now, -keep, "Days")
    loop files LogDir() "\taskbar-pull-*.log*" {
        if RegExMatch(A_LoopFileName, "^taskbar-pull-(\d{4})-(\d{2})-(\d{2})\.log", &m)
            && (m[1] m[2] m[3] "000000") < SubStr(cutoff, 1, 8) "000000"
            try FileDelete(A_LoopFileFullPath)
    }
}

LogError(e, mode) {
    Log("error", Format("{}: {} (line {}, {}) [{}]", Type(e), e.Message, e.Line, e.What, mode))
    return 1      ; never show AutoHotkey's error dialog
}
