<#
  UI, settings, startup and screenshot tests:
    powershell -File tests\run-ui.ps1 -AppDir dist\stage\TaskbarPull -Steps FirstRun,Settings,Shots -Shots docs\screenshots
  Uses a test profile (APPDATA / LOCALAPPDATA redirected) except where a step says otherwise.
  Screenshots are taken with PrintWindow of Taskbar Pull's own windows only (the tray menu: its
  own rectangle), never the desktop.
#>
param(
    [Parameter(Mandatory)] [string]$AppDir,
    [string[]]$Steps = @('FirstRun', 'Settings', 'Startup', 'Shots'),
    [string]$Shots,
    [string]$Out,
    [int]$WaitMin = 90
)
$Steps = @($Steps -split ',' | Where-Object { $_ })
$TestDir = Join-Path $env:TEMP 'tp-tests'
if (!$Out) { $Out = Join-Path $PSScriptRoot '..\dist\test-ui.txt' }
if (!$Shots) { $Shots = Join-Path $PSScriptRoot '..\docs\screenshots' }
. "$PSScriptRoot\harness.ps1"
$AppDir = (Resolve-Path $AppDir).Path
$script:HLog = $Out
New-Item -ItemType Directory -Force $TestDir, $Shots | Out-Null
$RunKeyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
function RunValue { (Get-ItemProperty $RunKeyPath -Name 'Taskbar Pull' -ErrorAction SilentlyContinue).'Taskbar Pull' }
function RunValueRestore($v) {
    if ($v) { Set-ItemProperty $RunKeyPath -Name 'Taskbar Pull' -Value $v } else { Remove-ItemProperty $RunKeyPath -Name 'Taskbar Pull' -ErrorAction SilentlyContinue }
}
function Result($case, [bool]$pass, [string]$detail) { HLog "RESULT $case $(if ($pass) {'PASS'} else {'FAIL'}) $detail" }

# ---- helpers for our own dialogs (Win32 messages to their controls)
function Wait-Window([string]$title, [int]$sec = 8) {
    for ($i = 0; $i -lt $sec * 10; $i++) { $h = [TP]::FindWindow('AutoHotkeyGUI', $title); if ($h -ne [IntPtr]::Zero -and [TP]::IsWindowVisible($h)) { return $h }; Start-Sleep -Milliseconds 100 }
    throw "window '$title' did not appear"
}
function Find-El($h, [string]$name, [string]$cls = 'Button') { $c = [TP]::Child($h, $cls, $name); if ($c -eq [IntPtr]::Zero) { throw "control '$name' not found" }; $c }
function Invoke-El($h, [string]$name) { [void][TP]::SendMessage((Find-El $h $name), 0xF5, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 400 }   # BM_CLICK
function Get-Check($h, [string]$name) { [int][TP]::SendMessage((Find-El $h $name), 0xF0, [IntPtr]::Zero, [IntPtr]::Zero) -eq 1 }                    # BM_GETCHECK
function Set-Check($h, [string]$name, [bool]$on) { if ((Get-Check $h $name) -ne $on) { [void][TP]::SendMessage((Find-El $h $name), 0xF5, [IntPtr]::Zero, [IntPtr]::Zero) }; Start-Sleep -Milliseconds 150 }
function Select-El($h, [string]$name) { [void][TP]::SendMessage((Find-El $h $name), 0xF5, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 300 }  # radio button
function Select-Tab($h, [int]$index) { $t = [TP]::Child($h, 'SysTabControl32', $null); [void][TP]::SendMessage($t, 0x1330, [IntPtr]$index, [IntPtr]::Zero); Start-Sleep -Milliseconds 400 }  # TCM_SETCURFOCUS
function Get-ListChecks($h) {
    $lv = [TP]::Child($h, 'SysListView32', $null)
    for ($i = 0; $i -lt [TP]::LvCount($lv); $i++) { [pscustomobject]@{ Index = $i; Name = [TP]::LvText($lv, $i, 0); On = [TP]::LvChecked($lv, $i); Lv = $lv } }
}
function Read-Ini([string]$Profile) { $f = "$Profile\Roaming\Taskbar Pull\settings.ini"; if (Test-Path $f) { Get-Content $f } else { @() } }
function Shot($h, [string]$name) { $p = Join-Path $Shots $name; [TP]::Shot($h, $p); HLog "screenshot $name ($((Get-Item $p).Length) bytes)" }
function Main-Hwnd { [TP]::Windows('AutoHotkey', $null) | Where-Object { [TP]::Text($_) -like "*\TaskbarPull.ahk - AutoHotkey*" } | Select-Object -First 1 }
function Show-TrayMenu {
    [void][TP]::PostMessage((Main-Hwnd), 0x404, [IntPtr]0x404, [IntPtr]0x205); Start-Sleep -Milliseconds 700
    [TP]::Windows('#32768', $null) | Where-Object { [TP]::IsWindowVisible($_) } | Select-Object -First 1
}
function Close-TrayMenu { [TP]::Key(0x1B, $false); [TP]::Key(0x1B, $true); Start-Sleep -Milliseconds 300 }

# ---- wait until it is safe
$deadline = (Get-Date).AddMinutes($WaitMin)
while ($true) { $s = Test-SafeToTest; if ($s.Ok) { break }; if ((Get-Date) -gt $deadline) { HLog "ABORT: not safe within $WaitMin min ($($s.Why))"; exit 2 }; HLog "waiting: $($s.Why)"; Start-Sleep 30 }
$cursor0 = [TP]::Cursor(); $fg0 = [TP]::GetForegroundWindow()
HLog "user idle $($s.IdleSec) s; run value before: '$(RunValue)'"
$runBefore = RunValue
Stop-HisInstance

try {
    foreach ($step in $Steps) {
        if (-not (Test-NoUserInput)) { HLog 'ABORT: user input detected'; break }
        Stop-App
        try {
            switch ($step) {
                'FirstRun' {
                    $P = Join-Path $TestDir 'profile-firstrun'; if (Test-Path $P) { Move-Item $P "$P-old-$(Get-Date -Format HHmmss)" }
                    [void](Start-App $P)
                    $h = Wait-Window 'Welcome to Taskbar Pull'
                    Start-Sleep -Milliseconds 800
                    $iniBefore = Test-Path "$P\Roaming\Taskbar Pull\settings.ini"; $runB = RunValue
                    $engineBefore = (Get-AppLog $P) -match '\[start\] engine on'
                    $defaults = "Alt=$(Get-Check $h 'Alt+click on a taskbar button pulls the window to that screen') Plain=$(Get-Check $h 'Plain click (without Alt) also pulls the window') Startup=$(Get-Check $h 'Start with Windows')"
                    Result 'FR-before' (-not $iniBefore -and -not $runB -and -not $engineBefore) "dialog shown; before confirming: settings.ini exists=$iniBefore, Run value='$runB', engine started=$([bool]$engineBefore); defaults $defaults"
                    Invoke-El $h 'Start'; Start-Sleep 1
                    $ini = Read-Ini $P
                    Result 'FR-after' (($ini -contains 'FirstRunDone=1') -and (RunValue) -and ((Get-AppLog $P) -match '\[start\] engine on')) "after Start: $($ini -join ' ') | Run value='$(RunValue)'"
                    Stop-App
                    RunValueRestore $runBefore
                }
                'Settings' {
                    $P = Join-Path $TestDir 'profile-settings'; Write-Settings $P
                    [void](Start-App $P); Start-Sleep 1.5
                    [void](Start-App $P)          # second launch opens the running instance's settings
                    $h = Wait-Window 'Taskbar Pull settings'
                    Set-Check $h 'Plain click (without Alt) also pulls the window' $true
                    Select-El $h 'only on the taskbars of these screens:'
                    $rows = @(Get-ListChecks $h); $first = $rows[0]
                    [TP]::LvSetCheck($first.Lv, $first.Index, $true)
                    Set-Check $h 'Start with Windows' $true
                    Invoke-El $h 'OK'; Start-Sleep 1
                    $ini = Read-Ini $P; $run1 = RunValue
                    Result 'S-save' (($ini -contains 'PlainClick=1') -and ($ini -contains "PlainScreens=$($first.Name)") -and ($ini -contains 'StartWithWindows=1') -and $run1) "saved: $(($ini | Select-String 'PlainClick|PlainScreens|StartWithWindows') -join ' ') | Run value='$run1'"
                    Stop-App; [void](Start-App $P); Start-Sleep 1.5; [void](Start-App $P)
                    $h = Wait-Window 'Taskbar Pull settings'
                    $rows = @(Get-ListChecks $h)
                    $re = "Plain=$(Get-Check $h 'Plain click (without Alt) also pulls the window') Chosen=$(Get-Check $h 'only on the taskbars of these screens:') Rows=$(($rows | ForEach-Object { "$($_.Name):$($_.On)" }) -join ',') Startup=$(Get-Check $h 'Start with Windows')"
                    Result 'S-reload' ($re -like "Plain=True Chosen=True Rows=$($first.Name):True*Startup=True") "after restart the window shows: $re"
                    Set-Check $h 'Start with Windows' $false
                    Invoke-El $h 'OK'; Start-Sleep 1
                    $run2 = RunValue
                    Result 'W-onoff' ($run1 -and -not $run2) "Start with Windows on -> Run value '$run1'; off -> Run value '$run2'"
                    Stop-App
                    RunValueRestore $runBefore
                }
                'Shots' {
                    foreach ($lang in 'en', 'fr') {
                        foreach ($scale in 'native', '100') {
                            $envx = if ($scale -eq '100') { @{ '__COMPAT_LAYER' = 'DPIUNAWARE' } } else { @{} }
                            $tag = "$lang-$scale"
                            # first-run dialog (a settings file without FirstRunDone, only to pick the language)
                            $P = Join-Path $TestDir "profile-shots-$tag"; if (Test-Path $P) { Move-Item $P "$P-old-$(Get-Date -Format HHmmss)" }
                            New-Item -ItemType Directory -Force "$P\Roaming\Taskbar Pull" | Out-Null
                            Set-Content "$P\Roaming\Taskbar Pull\settings.ini" "[General]`r`nLanguage=$lang" -Encoding Unicode
                            [void](Start-App $P @() $envx)
                            $t = if ($lang -eq 'fr') { 'Bienvenue dans Taskbar Pull' } else { 'Welcome to Taskbar Pull' }
                            $h = Wait-Window $t; Start-Sleep 1; Shot $h "first-run-$tag.png"
                            [void][TP]::PostMessage($h, 0x10, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep 1   # Cancel: nothing changes
                            Stop-App
                            # settings window, 3 tabs
                            Write-Settings $P @{ Language = $lang; PlainClick = 1 }
                            [void](Start-App $P @() $envx); Start-Sleep 1.5; [void](Start-App $P @() $envx)
                            $t = if ($lang -eq 'fr') { 'Paramètres de Taskbar Pull' } else { 'Taskbar Pull settings' }
                            $h = Wait-Window $t; Start-Sleep 0.8
                            $tabs = if ($lang -eq 'fr') { 'Général', 'Protection des jeux', 'Avancé' } else { 'General', 'Game guard', 'Advanced' }
                            $i = 0
                            foreach ($tb in $tabs) { Select-Tab $h $i; $i++; Start-Sleep 0.4; Shot $h "settings-$i-$tag.png" }
                            [void][TP]::PostMessage($h, 0x10, [IntPtr]::Zero, [IntPtr]::Zero)
                            # tray menu
                            $m = Show-TrayMenu
                            if ($m) { $r = [TP]::Rect($m); [TP]::ShotRect($r[0], $r[1], $r[2], $r[3], (Join-Path $Shots "tray-menu-$tag.png")); HLog "screenshot tray-menu-$tag.png"; Close-TrayMenu }
                            Stop-App
                        }
                    }
                }
            }
        } catch { Result $step $false "error: $_" }
        [TP]::SetCursorPos($cursor0[0], $cursor0[1]) | Out-Null
    }
} finally {
    Stop-App
    [TP]::SetCursorPos($cursor0[0], $cursor0[1]) | Out-Null
    [void][TP]::Front($fg0)
    HLog "run value at the end: '$(RunValue)' (before: '$runBefore')"
    Start-HisInstance
}
