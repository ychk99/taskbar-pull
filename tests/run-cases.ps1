<#
  Runs the live click tests:  powershell -File tests\run-cases.ps1 -AppDir dist\stage\TaskbarPull -Cases 1,2,3
  Writes a transcript to -Out. Waits (up to -WaitMin minutes) for the user to be idle >= 2 min with no
  game or full-screen app in front, stops the user's own "Taskbar Pull" task for the burst and starts
  it again afterwards. Aborts at once if the user touches mouse/keyboard during a burst.
#>
param(
    [Parameter(Mandatory)] [string]$AppDir,
    [string[]]$Cases = @('1', '2', '3', '4a', '4b', '5', '5e', '6', '7', '8', 'P', 'P2', 'G1', 'G2', 'T'),
    [string]$Out,
    [int]$WaitMin = 90,
    [switch]$NoHisTask
)
$Cases = @($Cases -split ',' | Where-Object { $_ })
$TestDir = Join-Path $env:TEMP 'tp-tests'
if (!$Out) { $Out = Join-Path $PSScriptRoot '..\dist\test-results.txt' }
. "$PSScriptRoot\harness.ps1"
$AppDir = (Resolve-Path $AppDir).Path
$script:HLog = $Out
New-Item -ItemType Directory -Force $TestDir | Out-Null
Copy-Item "$PSScriptRoot\tpwin.ahk" $TestDir -Force
foreach ($n in 'TPTestA', 'TPTestB', 'TPTestM', 'TPTestF') { Copy-Item "$AppDir\TaskbarPull.exe" "$TestDir\$n.exe" -Force }
$Profile = Join-Path $TestDir 'profile'

# ---- wait until it is safe
$deadline = (Get-Date).AddMinutes($WaitMin)
while ($true) {
    $s = Test-SafeToTest
    if ($s.Ok) { break }
    if ((Get-Date) -gt $deadline) { HLog "ABORT: not safe to test within $WaitMin min ($($s.Why))"; exit 2 }
    HLog "waiting: $($s.Why)"; Start-Sleep 30
}
$screens = Get-Screens
$prim = $screens | Where-Object Primary | Select-Object -First 1
$other = $screens | Where-Object { -not $_.Primary } | Sort-Object { $_.Rect[0] } | Select-Object -First 1
HLog ("screens: " + (($screens | ForEach-Object { "$($_.Dev) [$($_.Rect -join ',')]$(if ($_.Primary) {' primary'})" }) -join ' | '))
if (-not $other) { HLog 'ABORT: needs a second screen with a taskbar'; exit 2 }
$cursor0 = [TP]::Cursor(); $fg0 = [TP]::GetForegroundWindow()
HLog "user idle $($s.IdleSec) s; foreground before: $($s.Fg.Exe) `"$($s.Fg.Title)`""

$results = [ordered]@{}
function Result($case, [bool]$pass, [string]$detail) { $results[$case] = "$(if ($pass) {'PASS'} else {'FAIL'}) $detail"; HLog "RESULT $case $(if ($pass) {'PASS'} else {'FAIL'}) $detail" }
function LogSince([datetime]$t) { $k = $t.AddSeconds(-1).ToString('yyyy-MM-dd HH:mm:ss'); Get-AppLog $Profile | ForEach-Object { $_.TrimStart([char]0xFEFF) } | Where-Object { $_ -match '^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d' -and $_.Substring(0, 19) -ge $k } }
function Btn($scr, $exe) { $b = Find-TaskbarButton $scr.Taskbar $exe; if (-not $b) { throw "no taskbar button for $exe on $($scr.Dev)" }; $b }
function Settle([int]$ms = 900) { Start-Sleep -Milliseconds $ms }
function Restart-App([hashtable]$General = @{}, [hashtable]$Guard = @{}) {
    Stop-App; Write-Settings $Profile $General $Guard; [void](Start-App $Profile); Start-Sleep -Milliseconds 1500
}

if (-not $NoHisTask) { Stop-HisInstance }
$wins = @{}
try {
    Restart-App
    $wins.A = Start-TestWindow 'TPTestA' 'Taskbar Pull test A'
    $wins.M = Start-TestWindow 'TPTestM' 'Taskbar Pull test M' 'menu'
    $wins.B1 = Start-TestWindow 'TPTestB' 'Taskbar Pull test B1'
    $wins.B2 = Start-TestWindow 'TPTestB' 'Taskbar Pull test B2'
    foreach ($k in 'M', 'B1', 'B2') { Set-TestWindow $wins[$k] $prim }
    Set-TestWindow $wins.A $prim
    Start-Sleep 1
    foreach ($c in $Cases) {
        if (-not (Test-NoUserInput)) { HLog 'ABORT: user input detected during the burst'; break }
        $fgNow = Get-ForegroundInfo
        if (($GameExes -contains $fgNow.Exe) -or ($fgNow.Full -and $fgNow.Exe -notlike 'TPTest*' -and $fgNow.Exe -ne 'explorer.exe')) { HLog "ABORT: $($fgNow.Exe) full-screen/game in front"; break }
        $t = Get-Date
        try {
            switch ($c) {
                '1' {   # minimized window -> Alt+click its button on the other screen's taskbar
                    Set-TestWindow $wins.A $prim 'min'; Settle 400
                    $b = Btn $other 'TPTestA'; Send-Click $b.X $b.Y -Alt; Settle
                    $st = Get-WinState $wins.A
                    Result $c ($st.State -eq 'normal' -and $st.Screen -eq $other.Dev) "A: $($st.State) on $($st.Screen) [$($st.Rect)] fg=$($st.Foreground)"
                }
                '2' {   # maximized background window -> other screen, stays maximized
                    Set-TestWindow $wins.A $prim 'max'; [void][TP]::Front($wins.M); Settle 400
                    $b = Btn $other 'TPTestA'; Send-Click $b.X $b.Y -Alt; Settle
                    $st = Get-WinState $wins.A
                    Result $c ($st.State -eq 'maximized' -and $st.Screen -eq $other.Dev) "A: $($st.State) on $($st.Screen) [$($st.Rect)] fg=$($st.Foreground)"
                }
                '3' {   # normal background window on the other screen -> primary screen
                    Set-TestWindow $wins.A $other 'normal'; [void][TP]::Front($wins.M); Settle 400
                    $b = Btn $prim 'TPTestA'; Send-Click $b.X $b.Y -Alt; Settle
                    $st = Get-WinState $wins.A
                    Result $c ($st.State -eq 'normal' -and $st.Screen -eq $prim.Dev) "A: $($st.State) on $($st.Screen) [$($st.Rect)] fg=$($st.Foreground)"
                }
                '4a' {  # active window on the primary screen, Alt+click its button on the other taskbar
                    Set-TestWindow $wins.A $prim 'normal'; [void][TP]::Front($wins.A); Settle 400
                    $b = Btn $other 'TPTestA'; Send-Click $b.X $b.Y -Alt; Settle 1100
                    $st = Get-WinState $wins.A
                    Result $c ($st.State -eq 'normal' -and $st.Screen -eq $other.Dev) "A: $($st.State) on $($st.Screen) [$($st.Rect)] fg=$($st.Foreground)"
                }
                '4b' {  # active window already on the clicked screen: the normal minimize stays
                    Set-TestWindow $wins.A $other 'normal'; [void][TP]::Front($wins.A); Settle 400
                    $b = Btn $other 'TPTestA'; Send-Click $b.X $b.Y -Alt; Settle
                    $st = Get-WinState $wins.A
                    Result $c ($st.State -eq 'minimized') "A: $($st.State) on $($st.Screen)"
                }
                '5' {   # combined button: Alt+click opens the flyout, plain click on B2's thumbnail
                    Set-TestWindow $wins.B1 $prim; Set-TestWindow $wins.B2 $prim; [void][TP]::Front($wins.M); Settle 400
                    $b = Btn $other 'TPTestB'; Send-Click $b.X $b.Y -Alt; Settle 1200
                    $th = Find-Thumbnail 'Taskbar Pull test B2'
                    if (-not $th) { $th = Get-ThumbPoint $b $other 1 2 }
                    Send-Click $th.X $th.Y; Settle
                    $st = Get-WinState $wins.B2
                    Result $c ($st.Screen -eq $other.Dev -and $st.State -ne 'minimized') "B2: $($st.State) on $($st.Screen) fg=$($st.Foreground) (thumbnail at $($th.X),$($th.Y))"
                }
                '5e' {  # plain click opens the flyout, then Alt+click directly on B1's thumbnail
                    Set-TestWindow $wins.B1 $prim; Set-TestWindow $wins.B2 $prim; [void][TP]::Front($wins.M); Settle 400
                    $b = Btn $other 'TPTestB'; Send-Click $b.X $b.Y; Settle 1200
                    $th = Find-Thumbnail 'Taskbar Pull test B1'
                    if (-not $th) { $th = Get-ThumbPoint $b $other 0 2 }
                    Send-Click $th.X $th.Y -Alt; Settle
                    $st = Get-WinState $wins.B1
                    Result $c ($st.Screen -eq $other.Dev -and $st.State -ne 'minimized') "B1: $($st.State) on $($st.Screen) fg=$($st.Foreground)"
                }
                '6' {   # plain click with plain click off: normal Windows behaviour
                    Set-TestWindow $wins.A $prim 'min'; Settle 400
                    $b = Btn $other 'TPTestA'; Send-Click $b.X $b.Y; Settle
                    $st = Get-WinState $wins.A
                    Result $c ($st.State -eq 'normal' -and $st.Screen -eq $prim.Dev) "A: $($st.State) on $($st.Screen) (not moved)"
                }
                '7' {   # Alt+click inside a window: passed through, nothing moves
                    Set-TestWindow $wins.A $prim 'normal'; [void][TP]::Front($wins.A); Settle 400
                    $r = [TP]::Rect($wins.A); $before = Get-WinState $wins.A
                    Send-Click ($r[0] + 300) ($r[1] + 300) -Alt; Settle
                    $st = Get-WinState $wins.A
                    Result $c ($st.Rect -eq $before.Rect -and $st.Screen -eq $prim.Dev) "A stayed at [$($st.Rect)]"
                }
                '8' {   # window with a classic menu bar: moved, and not left in menu mode
                    Set-TestWindow $wins.M $prim 'normal'; [void][TP]::Front($wins.A); Settle 400
                    $b = Btn $other 'TPTestM'; Send-Click $b.X $b.Y -Alt; Settle 1200
                    $st = Get-WinState $wins.M
                    $menu = (LogSince $t | Where-Object { $_ -like '*`[menu`] Alt released*' } | Select-Object -Last 1)
                    Result $c ($st.Screen -eq $other.Dev -and $menu -like '*menu mode: no*') "M on $($st.Screen); $menu"
                }
                'P' {   # plain click on every screen
                    Restart-App @{ PlainClick = 1; PlainScreens = '*' }
                    Set-TestWindow $wins.A $prim 'min'; Settle 400
                    $b = Btn $other 'TPTestA'; Send-Click $b.X $b.Y; Settle
                    $st = Get-WinState $wins.A
                    Result $c ($st.State -eq 'normal' -and $st.Screen -eq $other.Dev) "A: $($st.State) on $($st.Screen)"
                }
                'P2' {  # plain click only on the primary screen (chosen by name)
                    $line = (Get-AppLog $Profile | Where-Object { $_ -like '*] screens:*' } | Select-Object -Last 1)
                    $name = ([regex]::Matches($line, '"([^"]+)" \(([^,]*), ([^)]+)\)') | Where-Object { $_.Groups[3].Value -eq $prim.Dev } | Select-Object -First 1).Groups[1].Value
                    Restart-App @{ PlainClick = 1; PlainScreens = $name }
                    Set-TestWindow $wins.A $prim 'min'; Settle 400
                    $b = Btn $other 'TPTestA'; Send-Click $b.X $b.Y; Settle
                    $st1 = Get-WinState $wins.A
                    Set-TestWindow $wins.A $other 'min'; Settle 400
                    $b = Btn $prim 'TPTestA'; Send-Click $b.X $b.Y; Settle
                    $st2 = Get-WinState $wins.A
                    Result $c ($st1.Screen -eq $prim.Dev -and $st2.Screen -eq $prim.Dev) "PlainScreens=$name; click on other taskbar -> A on $($st1.Screen) (not pulled); A on other screen + click on primary taskbar -> A on $($st2.Screen) (pulled)"
                    Restart-App
                }
                'G1' {  # full-screen test window in front, Alt+click another window's button
                    $kl = Join-Path $TestDir 'F-keys.txt'; Remove-Item $kl -ErrorAction SilentlyContinue
                    if (-not $wins.F) { $wins.F = Start-TestWindow 'TPTestF' 'Taskbar Pull test F' 'full' $kl }
                    $r = $prim.Rect; [void][TP]::SetWindowPos($wins.F, [IntPtr]::Zero, $r[0], $r[1], $r[2] - $r[0], $r[3] - $r[1], 0x14)
                    Set-TestWindow $wins.A $prim 'min'; [void][TP]::Front($wins.F); Settle 600
                    Add-Content $kl "--- G1 burst"
                    $b = Btn $other 'TPTestA'; Send-Click $b.X $b.Y -Alt; Settle 1200
                    $keys = Get-Content $kl | Where-Object { $_ -match 'vkE8|vk1B' }
                    $st = Get-WinState $wins.A
                    Result $c (-not $keys -and $st.Screen -eq $other.Dev) "F received vkE8/Esc: $(if ($keys) { $keys -join '; ' } else { 'none' }); A moved to $($st.Screen); F log: $((Get-Content $kl) -join ' / ')"
                }
                'G2' {  # A in front, Alt+click the full-screen window's own button
                    $kl = Join-Path $TestDir 'F-keys.txt'
                    Set-TestWindow $wins.A $prim 'normal'; [void][TP]::Front($wins.A); Settle 500
                    Add-Content $kl "--- G2 burst"
                    $b = Btn $prim 'TPTestF'; Send-Click $b.X $b.Y -Alt; Settle 1200
                    $since = (Get-Content $kl) -join "`n"; $since = $since.Substring($since.LastIndexOf('--- G2'))
                    $bad = $since -split "`n" | Where-Object { $_ -match 'vkE8|vk1B' }
                    $skip = LogSince $t | Where-Object { $_ -like '*skipped mask key*' -or $_ -like '*Esc skipped*' } | Select-Object -First 2
                    Result $c (-not $bad) "F received vkE8/Esc: $(if ($bad) { $bad -join '; ' } else { 'none' }); app: $($skip -join ' | ')"
                    [void][TP]::PostMessage($wins.F, 0x10, [IntPtr]::Zero, [IntPtr]::Zero); $wins.Remove('F')
                }
                'T' {   # tray menu: Enabled off -> Alt+click does nothing; on again -> works
                    $main = [TP]::Windows('AutoHotkey', $null) | Where-Object { [TP]::Text($_) -like "*\TaskbarPull.ahk - AutoHotkey*" } | Where-Object { $p = [uint32]0; [void][TP]::GetWindowThreadProcessId($_, [ref]$p); (Get-Process -Id $p).Path -like "$AppDir*" } | Select-Object -First 1
                    function Toggle-Tray {
                        [TP]::SetCursorPos($cursor0[0], $cursor0[1]) | Out-Null
                        [void][TP]::PostMessage($main, 0x404, [IntPtr]0x404, [IntPtr]0x205); Start-Sleep -Milliseconds 700   # AHK_NOTIFYICON, WM_RBUTTONUP
                        # the menu is open and in front: its "&Enabled" item answers to the E key
                        $menu = [TP]::Windows('#32768', $null) | Where-Object { [TP]::IsWindowVisible($_) } | Select-Object -First 1
                        if (-not $menu) { throw 'tray menu did not open' }
                        [TP]::Key(0x45, $false); [TP]::Key(0x45, $true); Start-Sleep -Milliseconds 500
                    }
                    Toggle-Tray
                    Set-TestWindow $wins.A $prim 'min'; Settle 300
                    $b = Btn $other 'TPTestA'; Send-Click $b.X $b.Y -Alt; Settle
                    $off = Get-WinState $wins.A
                    Toggle-Tray
                    Set-TestWindow $wins.A $prim 'min'; Settle 300
                    $b = Btn $other 'TPTestA'; Send-Click $b.X $b.Y -Alt; Settle
                    $on = Get-WinState $wins.A
                    $tl = LogSince $t | Where-Object { $_ -like '*`[tray`]*' }
                    Result $c ($off.Screen -eq $prim.Dev -and $on.Screen -eq $other.Dev) "disabled: A restored on $($off.Screen) (not moved); enabled again: A on $($on.Screen); $($tl -join ' | ')"
                }
            }
        } catch { Result $c $false "error: $_" }
        HLog ("app log: " + ((LogSince $t | Where-Object { $_ -match '\[(trigger|move|decide|plain|pass|menu|flyout|cancel|tray|error)\]' }) -join "`n    "))
        [TP]::SetCursorPos($cursor0[0], $cursor0[1]) | Out-Null
    }
} finally {
    foreach ($h in $wins.Values) { [void][TP]::PostMessage($h, 0x10, [IntPtr]::Zero, [IntPtr]::Zero) }
    Start-Sleep 1; Get-Process TPTest* -ErrorAction SilentlyContinue | Stop-Process   # test windows that ignored WM_CLOSE
    Stop-App
    [TP]::SetCursorPos($cursor0[0], $cursor0[1]) | Out-Null
    [void][TP]::Front($fg0)
    if (-not $NoHisTask) { Start-HisInstance }
    HLog ("SUMMARY " + (($results.Keys | ForEach-Object { "$_=$($results[$_].Split(' ')[0])" }) -join ' '))
}
