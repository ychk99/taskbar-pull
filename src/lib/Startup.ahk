; Taskbar Pull - start with Windows and admin mode.
;   Classic build (zip / installer): HKCU Run value "Taskbar Pull", or, in admin mode, the
;   scheduled task "Taskbar Pull (admin mode)" that starts it elevated at sign-in.
;   Store build (MSIX): the package's windows.startupTask "TaskbarPullStartup" (WinRT StartupTask).

global RunKey := "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
global RunValue := "Taskbar Pull"
global AdminTaskName := "Taskbar Pull (admin mode)"
global StartupTaskId := "TaskbarPullStartup"

; Command line that starts this app: the renamed interpreter alone when it carries the script's
; name (TaskbarPull.exe + TaskbarPull.ahk), otherwise interpreter + script (development runs).
AppCommand() {
    SplitPath(A_AhkPath, , , , &exeBase)
    SplitPath(A_ScriptFullPath, , , , &scriptBase)
    if (exeBase = scriptBase && A_ScriptDir = DirOf(A_AhkPath))
        return '"' A_AhkPath '"'
    return '"' A_AhkPath '" "' A_ScriptFullPath '"'
}
; Same with arguments. AutoHotkey takes the first argument as the script file, so the script
; path always comes first when arguments are passed.
AppCommandArgs(args) => '"' A_AhkPath '" "' A_ScriptFullPath '" ' args
DirOf(p) {
    SplitPath(p, , &d)
    return d
}

; ---------------------------------------------------------------- HKCU Run
RunEntryGet() {
    try return RegRead(RunKey, RunValue)
    return ""
}
RunEntrySet(on) {
    if on {
        RegWrite(AppCommand(), "REG_SZ", RunKey, RunValue)
        Log("startup", "Run entry set: " AppCommand())
    } else if (RunEntryGet() != "") {
        RegDelete(RunKey, RunValue)
        Log("startup", "Run entry removed")
    }
}

; ---------------------------------------------------------------- admin-mode task
AdminTaskExists() {
    try {
        svc := ComObject("Schedule.Service")
        svc.Connect()
        svc.GetFolder("\").GetTask(AdminTaskName)
        return true
    }
    return false
}

; Task XML: at sign-in of `user`, run this app with highest privileges, no time limit.
; The security descriptor lets the user read and run the task (to start it without UAC), but
; only administrators and SYSTEM can change or delete it.
AdminTaskXml(user, sid) {
    cmd := AppCommand()
    if RegExMatch(cmd, '^"([^"]+)"(?:\s+(.*))?$', &m)
        exe := m[1], args := m[2]
    else
        exe := cmd, args := ""
    x(s) => StrReplace(StrReplace(StrReplace(s, "&", "&amp;"), "<", "&lt;"), ">", "&gt;")
    return '<?xml version="1.0" encoding="UTF-16"?>'
    . '<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">'
    . '<RegistrationInfo><Author>Taskbar Pull</Author><Description>Starts Taskbar Pull with administrator rights at sign-in (admin mode), so it can also move windows of apps running as administrator. Remove it by switching admin mode off in Taskbar Pull settings.</Description>'
    . (sid != "" ? '<SecurityDescriptor>D:(A;;FA;;;BA)(A;;FA;;;SY)(A;;GRGX;;;' sid ')</SecurityDescriptor>' : '')
    . '</RegistrationInfo>'
    . '<Triggers><LogonTrigger><Enabled>true</Enabled><UserId>' x(user) '</UserId><Delay>PT3S</Delay></LogonTrigger></Triggers>'
    . '<Principals><Principal id="Author"><UserId>' x(user) '</UserId><LogonType>InteractiveToken</LogonType><RunLevel>HighestAvailable</RunLevel></Principal></Principals>'
    . '<Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>'
    . '<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries><AllowHardTerminate>true</AllowHardTerminate><StartWhenAvailable>false</StartWhenAvailable>'
    . '<IdleSettings><StopOnIdleEnd>false</StopOnIdleEnd><RestartOnIdle>false</RestartOnIdle></IdleSettings>'
    . '<AllowStartOnDemand>true</AllowStartOnDemand><Enabled>true</Enabled><Hidden>false</Hidden><ExecutionTimeLimit>PT0S</ExecutionTimeLimit><Priority>7</Priority>'
    . '<RestartOnFailure><Interval>PT1M</Interval><Count>3</Count></RestartOnFailure></Settings>'
    . '<Actions Context="Author"><Exec><Command>' x(exe) '</Command>' (args != "" ? '<Arguments>' x(args) '</Arguments>' : '')
    . '<WorkingDirectory>' x(A_ScriptDir) '</WorkingDirectory></Exec></Actions></Task>'
}

; Runs elevated (command line /admin-task create|delete "DOMAIN\user" SID). Exit code 0 = done.
AdminTaskCommand(action, user, sid) {
    try {
        svc := ComObject("Schedule.Service")
        svc.Connect()
        root := svc.GetFolder("\")
        if (action = "create") {
            ; 6 = TASK_CREATE_OR_UPDATE, 3 = TASK_LOGON_INTERACTIVE_TOKEN
            root.RegisterTask(AdminTaskName, AdminTaskXml(user, sid), 6, user, , 3)
            Log("admin", "admin-mode task created for " user)
        } else {
            try root.GetTask(AdminTaskName).Stop(0)
            root.DeleteTask(AdminTaskName, 0)
            Log("admin", "admin-mode task removed")
        }
        return 0
    } catch as e {
        Log("admin", "admin-mode task " action " failed: " e.Message)
        return 1
    }
}

CurrentUser() => EnvGet("USERDOMAIN") "\" A_UserName
CurrentSid() {
    ; SID of this process's user, from its token (TokenUser = 1)
    sid := "", tok := 0, n := 0
    if !DllCall("advapi32\OpenProcessToken", "ptr", DllCall("GetCurrentProcess", "ptr"), "uint", 8, "ptr*", &tok)
        return ""
    DllCall("advapi32\GetTokenInformation", "ptr", tok, "int", 1, "ptr", 0, "uint", 0, "uint*", &n)
    b := Buffer(n, 0), ps := 0
    if DllCall("advapi32\GetTokenInformation", "ptr", tok, "int", 1, "ptr", b, "uint", n, "uint*", &n)
        && DllCall("advapi32\ConvertSidToStringSidW", "ptr", NumGet(b, 0, "ptr"), "ptr*", &ps) {
        sid := StrGet(ps, "UTF-16")
        DllCall("LocalFree", "ptr", ps)
    }
    DllCall("CloseHandle", "ptr", tok)
    return sid
}

; Creates or removes the task. Uses this process when it is elevated, otherwise starts an
; elevated copy of itself (UAC prompt). Returns "" on success or the reason it failed.
AdminTaskSet(on) {
    action := on ? "create" : "delete"
    if A_IsAdmin
        return AdminTaskCommand(action, CurrentUser(), CurrentSid()) = 0 ? "" : "Task Scheduler error (see the log)"
    cmd := AppCommandArgs('/admin-task ' action ' "' CurrentUser() '" "' CurrentSid() '"')
    try {
        code := RunWait("*RunAs " cmd)
    } catch {
        return T("set.admin.cancelled")
    }
    return code = 0 ? "" : "Task Scheduler error " code " (see the log)"
}

AdminTaskRun() {
    try {
        svc := ComObject("Schedule.Service")
        svc.Connect()
        svc.GetFolder("\").GetTask(AdminTaskName).Run("")
        return true
    } catch as e {
        Log("admin", "could not start the admin-mode task: " e.Message)
        return false
    }
}

; ---------------------------------------------------------------- MSIX StartupTask (WinRT)
; Returns the task state (0 Disabled, 1 DisabledByUser, 2 Enabled, 3 DisabledByPolicy,
; 4 EnabledByPolicy) or -1 when it cannot be read.
StoreStartupState() {
    if !(t := StartupTaskGet())
        return -1
    st := -1
    try ComCall(8, t, "int*", &st)        ; IStartupTask::get_State
    ObjRelease(t)
    return st
}

; Enables or disables the package's startup task. Returns the new state, or -1 on error.
StoreStartupSet(on) {
    if !(t := StartupTaskGet())
        return -1
    st := -1
    try {
        if on {
            op := 0
            ComCall(6, t, "ptr*", &op)    ; RequestEnableAsync -> IAsyncOperation<StartupTaskState>
            if AwaitAsync(op) {
                ComCall(8, op, "int*", &st)   ; GetResults
            }
            ObjRelease(op)
        } else {
            ComCall(7, t, "int")          ; Disable
            ComCall(8, t, "int*", &st)
        }
    }
    ObjRelease(t)
    Log("startup", "Store startup task " (on ? "enable" : "disable") " -> state " st)
    return st
}

StartupTaskGet() {
    if !IsPackaged()
        return 0
    try {
        cls := "Windows.ApplicationModel.StartupTask", hs := 0, fac := 0, op := 0, task := 0
        DllCall("combase\WindowsCreateString", "wstr", cls, "uint", StrLen(cls), "ptr*", &hs)
        iid := GuidBuf("{ee5b60bd-a148-41a7-b26e-e8b88a1e62f8}")      ; IStartupTaskStatics
        hr := DllCall("combase\RoGetActivationFactory", "ptr", hs, "ptr", iid, "ptr*", &fac, "uint")
        DllCall("combase\WindowsDeleteString", "ptr", hs)
        if (hr != 0 || !fac)
            throw Error("RoGetActivationFactory " Format("0x{:08X}", hr))
        id := 0
        DllCall("combase\WindowsCreateString", "wstr", StartupTaskId, "uint", StrLen(StartupTaskId), "ptr*", &id)
        ComCall(7, fac, "ptr", id, "ptr*", &op)          ; GetAsync(taskId)
        DllCall("combase\WindowsDeleteString", "ptr", id)
        ObjRelease(fac)
        if AwaitAsync(op)
            ComCall(8, op, "ptr*", &task)                ; GetResults -> StartupTask
        ObjRelease(op)
        return task
    } catch as e {
        Log("startup", "Store startup task not available: " e.Message)
        return 0
    }
}

; Polls IAsyncInfo until the operation finishes (up to 5 s). true = completed.
AwaitAsync(op) {
    info := ComObjQuery(op, "{00000036-0000-0000-C000-000000000046}")
    st := 0
    loop 250 {
        ComCall(7, info, "int*", &st)     ; get_Status: 0 started, 1 completed, 2 canceled, 3 error
        if (st != 0)
            break
        Sleep 20
    }
    return st = 1
}

GuidBuf(s) {
    b := Buffer(16, 0)
    DllCall("ole32\CLSIDFromString", "wstr", s, "ptr", b)
    return b
}

; ---------------------------------------------------------------- apply the setting
; Puts "start with Windows" and admin mode in the state S asks for. Returns "" or an error text.
StartupApply() {
    if IsPackaged() {
        st := StoreStartupState()
        want := S.StartWithWindows
        if (st >= 0 && want != (st = 2 || st = 4)) {
            st := StoreStartupSet(want)
            if (want && st = 1)
                return T("set.store.disabledbyuser")
        }
        return ""
    }
    err := ""
    if S.AdminMode {
        if !AdminTaskExists() {
            err := AdminTaskSet(true)
            if (err != "") {
                S.AdminMode := false
                err := T("set.admin.failed", err)
            }
        }
    } else if AdminTaskExists() {
        e2 := AdminTaskSet(false)
        if (e2 != "") {
            S.AdminMode := true
            err := T("set.admin.offfailed", e2)
        }
    }
    ; the Run entry is used only outside admin mode (the task starts the app in admin mode)
    RunEntrySet(S.StartWithWindows && !S.AdminMode)
    return err
}
