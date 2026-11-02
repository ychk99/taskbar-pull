<#
  Taskbar Pull test harness (Windows PowerShell 5.1, dot-source it: . .\tests\harness.ps1).
  Live tests on the real desktop with simulated input, under these rules:
    - only while the user has been idle >= 2 min and no game / full-screen app is in front;
    - short bursts; the cursor is put back and focus is given back after each case;
    - only test windows created here (renamed AutoHotkey copies running tests\tpwin.ahk), their
      taskbar buttons found through UI Automation; Alt and clicks sent with SendInput.
  The app under test runs from a staged build with APPDATA / LOCALAPPDATA pointed at a test
  profile, so it never touches the real settings.
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, UIAutomationClientsideProviders, System.Drawing
# the managed UIA client needs the client-side proxies to see standard Win32 controls (buttons, list views)
try { [Windows.Automation.ClientSettings]::RegisterClientSideProviderAssembly([UIAutomationClientsideProviders.UIAutomationClientSideProviders].Assembly.GetName()) } catch { }
if (-not ('TP' -as [type])) {
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Text; using System.Drawing; using System.Drawing.Imaging;
public static class TP {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int l, t, r, b; }
  [StructLayout(LayoutKind.Sequential)] struct MOUSEINPUT { public int dx, dy, mouseData, dwFlags, time; public IntPtr extra; }
  [StructLayout(LayoutKind.Sequential)] struct KEYBDINPUT { public ushort vk, scan; public int flags, time; public IntPtr extra; }
  [StructLayout(LayoutKind.Explicit)] struct INPUT { [FieldOffset(0)] public int type; [FieldOffset(8)] public MOUSEINPUT mi; [FieldOffset(8)] public KEYBDINPUT ki; }
  [StructLayout(LayoutKind.Sequential)] struct LASTINPUTINFO { public int cb; public uint dwTime; }
  [StructLayout(LayoutKind.Sequential)] struct POINT { public int x, y; }
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] struct MONITORINFOEX { public int cb; public RECT rc, work; public int flags; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dev; }
  [DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr c);
  [DllImport("user32.dll")] static extern uint SendInput(uint n, INPUT[] i, int size);
  [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LASTINPUTINFO i);
  [DllImport("kernel32.dll")] public static extern uint GetTickCount();
  [DllImport("user32.dll")] static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int hh, uint f);
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr h, uint f);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern bool GetMonitorInfo(IntPtr m, ref MONITORINFOEX mi);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string title);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr after, string cls, string title);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
  [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool f);
  [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr h);
  [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
  // bring one of our own test windows forward (attaches to the foreground thread's input state)
  public static bool Front(IntPtr h) {
    uint pid; uint fgt = GetWindowThreadProcessId(GetForegroundWindow(), out pid), me = GetCurrentThreadId();
    bool att = fgt != me && AttachThreadInput(me, fgt, true);
    BringWindowToTop(h); bool ok = SetForegroundWindow(h);
    if (att) AttachThreadInput(me, fgt, false);
    return ok;
  }
  [DllImport("shcore.dll")] static extern int GetDpiForMonitor(IntPtr hm, int t, out uint x, out uint y);
  public static int Dpi(IntPtr hm) { uint x, y; GetDpiForMonitor(hm, 0, out x, out y); return (int)x; }
  // ---- our own dialogs' Win32 controls (the managed UIA client only sees them as panes)
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr h);
  public static IntPtr Child(IntPtr parent, string cls, string text) {
    IntPtr found = IntPtr.Zero;
    EnumChildWindows(parent, (h, l) => { if ((cls == null || Cls(h) == cls) && (text == null || Text(h).Replace("&", "") == text)) { found = h; return false; } return true; }, IntPtr.Zero);
    return found;
  }
  [DllImport("kernel32.dll")] static extern IntPtr OpenProcess(uint a, bool i, uint pid);
  [DllImport("kernel32.dll")] static extern IntPtr VirtualAllocEx(IntPtr p, IntPtr a, int n, uint t, uint pr);
  [DllImport("kernel32.dll")] static extern bool VirtualFreeEx(IntPtr p, IntPtr a, int n, uint t);
  [DllImport("kernel32.dll")] static extern bool WriteProcessMemory(IntPtr p, IntPtr a, byte[] b, int n, out IntPtr w);
  [DllImport("kernel32.dll")] static extern bool ReadProcessMemory(IntPtr p, IntPtr a, byte[] b, int n, out IntPtr r);
  [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
  public static int LvCount(IntPtr lv) { return (int)SendMessage(lv, 0x1004, IntPtr.Zero, IntPtr.Zero); }
  public static bool LvChecked(IntPtr lv, int i) { return (((int)SendMessage(lv, 0x102C, (IntPtr)i, (IntPtr)0xF000)) >> 12) == 2; }
  // LVITEMW in the list view's process: mask 0, iItem 4, iSubItem 8, state 12, stateMask 16, pszText 24, cchTextMax 32
  static string LvCall(IntPtr lv, int i, int sub, bool setCheck, bool on) {
    uint pid; GetWindowThreadProcessId(lv, out pid);
    IntPtr hp = OpenProcess(0x38, false, pid); IntPtr mem = VirtualAllocEx(hp, IntPtr.Zero, 1024, 0x3000, 4); IntPtr n;
    var it = new byte[88];
    BitConverter.GetBytes(i).CopyTo(it, 4); BitConverter.GetBytes(sub).CopyTo(it, 8);
    string res = null;
    if (setCheck) {
      BitConverter.GetBytes((on ? 2 : 1) << 12).CopyTo(it, 12); BitConverter.GetBytes(0xF000).CopyTo(it, 16);
      WriteProcessMemory(hp, mem, it, 88, out n); SendMessage(lv, 0x102B, (IntPtr)i, mem);
    } else {
      BitConverter.GetBytes(mem.ToInt64() + 128).CopyTo(it, 24); BitConverter.GetBytes(256).CopyTo(it, 32);
      WriteProcessMemory(hp, mem, it, 88, out n); SendMessage(lv, 0x1073, (IntPtr)i, mem);
      var buf = new byte[512]; ReadProcessMemory(hp, mem + 128, buf, 512, out n);
      res = Encoding.Unicode.GetString(buf); int z = res.IndexOf('\0'); if (z >= 0) res = res.Substring(0, z);
    }
    VirtualFreeEx(hp, mem, 0, 0x8000); CloseHandle(hp);
    return res;
  }
  public static string LvText(IntPtr lv, int i, int sub) { return LvCall(lv, i, sub, false, false); }
  public static void LvSetCheck(IntPtr lv, int i, bool on) { LvCall(lv, i, 0, true, on); }
  public static bool PM() { return SetProcessDpiAwarenessContext(new IntPtr(-4)); }
  public static uint LastSend;
  static void Send(INPUT[] a) { SendInput((uint)a.Length, a, Marshal.SizeOf(typeof(INPUT))); LastSend = GetTickCount(); }
  public static void Key(ushort vk, bool up) { var i = new INPUT[1]; i[0].type = 1; i[0].ki.vk = vk; i[0].ki.flags = up ? 2 : 0; Send(i); }
  public static void Click(int x, int y) { SetCursorPos(x, y); System.Threading.Thread.Sleep(40); var i = new INPUT[2]; i[0].type = 0; i[0].mi.dwFlags = 2; i[1].type = 0; i[1].mi.dwFlags = 4; Send(i); }
  public static uint IdleMs() { var i = new LASTINPUTINFO(); i.cb = Marshal.SizeOf(i); GetLastInputInfo(ref i); return GetTickCount() - i.dwTime; }
  public static uint LastInputTick() { var i = new LASTINPUTINFO(); i.cb = Marshal.SizeOf(i); GetLastInputInfo(ref i); return i.dwTime; }
  public static int[] Cursor() { POINT p; GetCursorPos(out p); return new int[] { p.x, p.y }; }
  public static int[] Rect(IntPtr h) { RECT r; GetWindowRect(h, out r); return new int[] { r.l, r.t, r.r, r.b }; }
  public static string Text(IntPtr h) { var s = new StringBuilder(512); GetWindowText(h, s, 512); return s.ToString(); }
  public static string Cls(IntPtr h) { var s = new StringBuilder(256); GetClassName(h, s, 256); return s.ToString(); }
  public static string MonDev(IntPtr hm) { var mi = new MONITORINFOEX(); mi.cb = Marshal.SizeOf(mi); GetMonitorInfo(hm, ref mi); return mi.dev; }
  public static int[] MonRect(IntPtr hm, bool work) { var mi = new MONITORINFOEX(); mi.cb = Marshal.SizeOf(mi); GetMonitorInfo(hm, ref mi); var r = work ? mi.work : mi.rc; return new int[] { r.l, r.t, r.r, r.b }; }
  public static System.Collections.Generic.List<IntPtr> Windows(string cls, string titleStart) {
    var list = new System.Collections.Generic.List<IntPtr>();
    EnumWindows((h, l) => { if ((cls == null || Cls(h) == cls) && (titleStart == null || Text(h).StartsWith(titleStart))) list.Add(h); return true; }, IntPtr.Zero);
    return list;
  }
  // PNG of one window only (PW_RENDERFULLCONTENT), never the desktop around it
  public static void Shot(IntPtr h, string path) {
    var r = Rect(h); int w = r[2] - r[0], hh = r[3] - r[1];
    using (var bmp = new Bitmap(w, hh, PixelFormat.Format32bppArgb)) {
      using (var g = Graphics.FromImage(bmp)) { var dc = g.GetHdc(); PrintWindow(h, dc, 2); g.ReleaseHdc(dc); }
      bmp.Save(path, ImageFormat.Png);
    }
  }
  // PNG of a screen rectangle (used only for the tray menu, which covers that rectangle)
  public static void ShotRect(int l, int t, int r, int b, string path) {
    using (var bmp = new Bitmap(r - l, b - t, PixelFormat.Format32bppArgb)) {
      using (var g = Graphics.FromImage(bmp)) g.CopyFromScreen(l, t, 0, 0, new Size(r - l, b - t));
      bmp.Save(path, ImageFormat.Png);
    }
  }
}
'@
}
[void][TP]::PM()

$script:HLog = $null
function HLog([string]$m) { $line = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss.fff'), $m; Write-Host $line; if ($script:HLog) { Add-Content $script:HLog $line -Encoding UTF8 } }

# ---------------------------------------------------------------- safety
$GameExes = 'League of Legends.exe', 'VALORANT-Win64-Shipping.exe'
$GamePaths = '\steamapps\common\', '\Riot Games\', '\Epic Games\', '\XboxGames\'
function Get-ForegroundInfo {
    $h = [TP]::GetForegroundWindow(); $procId = [uint32]0; [void][TP]::GetWindowThreadProcessId($h, [ref]$procId)
    $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
    $path = try { $p.Path } catch { '' }
    $hm = [TP]::MonitorFromWindow($h, 2); $mr = [TP]::MonRect($hm, $false); $wr = [TP]::Rect($h)
    $full = $wr[0] -le $mr[0] -and $wr[1] -le $mr[1] -and $wr[2] -ge $mr[2] -and $wr[3] -ge $mr[3] -and ([TP]::Cls($h) -notin 'Progman', 'WorkerW')
    [pscustomobject]@{ Hwnd = $h; Exe = "$($p.ProcessName).exe"; Path = $path; Title = [TP]::Text($h); Full = $full }
}
function Test-SafeToTest([int]$MinIdleSec = 120) {
    $fg = Get-ForegroundInfo
    $game = ($GameExes -contains $fg.Exe) -or ($GamePaths | Where-Object { $fg.Path -and $fg.Path -like "*$_*" })
    $idle = [TP]::IdleMs() / 1000
    $why = if ($game) { "a game is in front ($($fg.Exe))" } elseif ($fg.Full -and $fg.Exe -notlike 'TPTest*') { "a full-screen window is in front ($($fg.Exe))" } elseif ($idle -lt $MinIdleSec) { "user active $([int]$idle) s ago" } else { '' }
    [pscustomobject]@{ Ok = ($why -eq ''); Why = $why; IdleSec = [int]$idle; Fg = $fg }
}
# true when nobody but the harness gave input since the last injected event
function Test-NoUserInput { ([TP]::LastInputTick() - [TP]::LastSend) -le 400 -or [TP]::LastSend -eq 0 }

# ---------------------------------------------------------------- screens and taskbars
function Get-Screens {
    $list = @()
    foreach ($tb in [TP]::Windows('Shell_TrayWnd', $null) + [TP]::Windows('Shell_SecondaryTrayWnd', $null)) {
        $hm = [TP]::MonitorFromWindow($tb, 2)
        $list += [pscustomobject]@{ Taskbar = $tb; Mon = $hm; Dev = [TP]::MonDev($hm); Rect = [TP]::MonRect($hm, $false); Work = [TP]::MonRect($hm, $true); Primary = ([TP]::Cls($tb) -eq 'Shell_TrayWnd') }
    }
    $list
}
function Get-WinScreen($h) { [TP]::MonDev([TP]::MonitorFromWindow($h, 2)) }

# Taskbar button of a test app on a given taskbar (UIA), as { Name, X, Y }
function Find-TaskbarButton($taskbar, [string]$exeLike) {
    $root = [Windows.Automation.AutomationElement]::FromHandle($taskbar)
    $cond = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ControlTypeProperty, [Windows.Automation.ControlType]::Button)
    foreach ($e in $root.FindAll([Windows.Automation.TreeScope]::Descendants, $cond)) {
        $id = $e.Current.AutomationId; $nm = $e.Current.Name
        if ($id -like "*$exeLike*" -or $nm -like "*$exeLike*") {
            $r = $e.Current.BoundingRectangle
            return [pscustomobject]@{ Name = $nm; Id = $id; X = [int]($r.X + $r.Width / 2); Y = [int]($r.Y + $r.Height / 2) }
        }
    }
    $null
}
# The thumbnail flyout: EnumWindows does not list it, but it takes the foreground when it opens
function Get-FlyoutWindows {
    $fg = [TP]::GetForegroundWindow(); $list = @()
    if ([TP]::Cls($fg) -in 'XamlExplorerHostIslandWindow', 'TaskListThumbnailWnd') { $list += $fg }
    $list += [TP]::Windows('TaskListThumbnailWnd', $null) | Where-Object { [TP]::IsWindowVisible($_) -and $_ -ne $fg }
    $list
}
# Point on thumbnail number $Index (0 = first window opened) of $Count in the flyout above a taskbar
# button. The Windows 11 flyout is not exposed to UI Automation, so this uses its layout: items
# 172 px wide (at 100 %), centred on the button, their centre 104 px above the button's centre.
function Get-ThumbPoint($Btn, $Screen, [int]$Index, [int]$Count) {
    $k = [TP]::Dpi($Screen.Mon) / 96.0
    [pscustomobject]@{ Name = "thumbnail $($Index + 1)/$Count"; X = [int]($Btn.X + ($Index - ($Count - 1) / 2) * 172 * $k); Y = [int]($Btn.Y - 104 * $k) }
}
# Thumbnail of a window in the taskbar's thumbnail flyout (UIA), as { Name, X, Y }
function Find-Thumbnail([string]$title) {
    $desk = [Windows.Automation.AutomationElement]::RootElement
    foreach ($h in Get-FlyoutWindows) {
        $root = [Windows.Automation.AutomationElement]::FromHandle($h)
        foreach ($e in $root.FindAll([Windows.Automation.TreeScope]::Descendants, [Windows.Automation.Condition]::TrueCondition)) {
            if ($e.Current.Name -like "$title*") {
                $r = $e.Current.BoundingRectangle
                if ($r.Width -gt 20) { return [pscustomobject]@{ Name = $e.Current.Name; X = [int]($r.X + $r.Width / 2); Y = [int]($r.Y + $r.Height / 2) } }
            }
        }
    }
    $null
}

function Close-Flyout {
    # Esc goes to the flyout (explorer) only when it is in front
    $fg = Get-ForegroundInfo
    if ($fg.Exe -eq 'explorer.exe') { [TP]::Key(0x1B, $false); [TP]::Key(0x1B, $true); Start-Sleep -Milliseconds 300 }
}
function Dump-Flyout {
    foreach ($h in Get-FlyoutWindows) {
        HLog "flyout window $([TP]::Cls($h)) '$([TP]::Text($h))' [$([TP]::Rect($h) -join ',')]"
        $root = [Windows.Automation.AutomationElement]::FromHandle($h)
        foreach ($e in $root.FindAll([Windows.Automation.TreeScope]::Descendants, [Windows.Automation.Condition]::TrueCondition)) {
            $c = $e.Current; HLog ("   {0} | {1} | {2} | {3}" -f $c.ControlType.ProgrammaticName, $c.ClassName, $c.Name, $c.BoundingRectangle)
        }
    }
}

# ---------------------------------------------------------------- input
function Send-Click([int]$x, [int]$y, [switch]$Alt) {
    if ($Alt) { [TP]::Key(0x12, $false); Start-Sleep -Milliseconds 60 }
    [TP]::Click($x, $y)
    if ($Alt) { Start-Sleep -Milliseconds 120; [TP]::Key(0x12, $true) }
}

# ---------------------------------------------------------------- test windows
function Start-TestWindow([string]$Exe, [string]$Title, [string]$Kind = 'plain', [string]$KeyLog = '') {
    $a = @("`"$TestDir\tpwin.ahk`"", "`"$Title`"", $Kind); if ($KeyLog) { $a += "`"$KeyLog`"" }
    Start-Process (Join-Path $TestDir "$Exe.exe") -ArgumentList $a | Out-Null
    for ($i = 0; $i -lt 50; $i++) { $h = [TP]::FindWindow('AutoHotkeyGUI', $Title); if ($h -ne [IntPtr]::Zero) { return $h }; Start-Sleep -Milliseconds 100 }
    throw "test window $Title did not appear"
}
function Set-TestWindow($h, $screen, [string]$State = 'normal', [int]$Width = 1100, [int]$Height = 750) {
    [void][TP]::ShowWindow($h, 9)
    $wk = $screen.Work
    [void][TP]::SetWindowPos($h, [IntPtr]::Zero, $wk[0] + 150, $wk[1] + 120, $Width, $Height, 0x14)
    Start-Sleep -Milliseconds 150
    if ($State -eq 'max') { [void][TP]::ShowWindow($h, 3) }
    if ($State -eq 'min') { [void][TP]::ShowWindow($h, 6) }
}
function Get-WinState($h) {
    $st = if ([TP]::IsIconic($h)) { 'minimized' } elseif ([TP]::IsZoomed($h)) { 'maximized' } else { 'normal' }
    $r = [TP]::Rect($h)
    [pscustomobject]@{ State = $st; Screen = (Get-WinScreen $h); Rect = ($r -join ','); Foreground = ([TP]::GetForegroundWindow() -eq $h) }
}

# ---------------------------------------------------------------- app under test
function Start-App([string]$Profile, [string[]]$AppArgs = @(), [hashtable]$ExtraEnv = @{}) {
    $env:APPDATA = "$Profile\Roaming"; $env:LOCALAPPDATA = "$Profile\Local"
    foreach ($k in $ExtraEnv.Keys) { Set-Item "env:$k" $ExtraEnv[$k] }
    New-Item -ItemType Directory -Force $env:APPDATA, $env:LOCALAPPDATA | Out-Null
    $p = if ($AppArgs.Count) { Start-Process "$AppDir\TaskbarPull.exe" -ArgumentList $AppArgs -PassThru } else { Start-Process "$AppDir\TaskbarPull.exe" -PassThru }
    $env:APPDATA = $RealAppData; $env:LOCALAPPDATA = $RealLocalAppData
    foreach ($k in $ExtraEnv.Keys) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    $p
}
function Stop-App {
    Get-Process TaskbarPull -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$AppDir*" } | ForEach-Object {
        Start-Process "$AppDir\TaskbarPull.exe" -ArgumentList "`"$AppDir\TaskbarPull.ahk`"", '/quit' -Wait
    }
}
function Get-AppLog([string]$Profile) {
    $f = Get-ChildItem "$Profile\Local\Taskbar Pull\logs\taskbar-pull-*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
    if ($f) { Get-Content $f.FullName -Encoding UTF8 } else { @() }
}
function Write-Settings([string]$Profile, [hashtable]$General = @{}, [hashtable]$Guard = @{}) {
    $d = "$Profile\Roaming\Taskbar Pull"; New-Item -ItemType Directory -Force $d | Out-Null
    $g = [ordered]@{ FirstRunDone = 1; Enabled = 1; AltClick = 1; PlainClick = 0; PlainScreens = '*'; ArmSeconds = 8; Logging = 1; StartWithWindows = 0; Language = 'en'; AdminMode = 0 }
    foreach ($k in $General.Keys) { $g[$k] = $General[$k] }
    $lines = @('[General]') + ($g.Keys | ForEach-Object { "$_=$($g[$_])" })
    if ($Guard.Count) { $lines += '[GameGuard]'; $lines += $Guard.Keys | ForEach-Object { "$_=$($Guard[$_])" } }
    Set-Content "$d\settings.ini" $lines -Encoding Unicode
}

# ---------------------------------------------------------------- his own instance
function Stop-HisInstance { try { Stop-ScheduledTask -TaskName 'Taskbar Pull' -ErrorAction Stop; HLog 'his "Taskbar Pull" task stopped' } catch { HLog "could not stop his task: $_" } }
function Start-HisInstance { try { Start-ScheduledTask -TaskName 'Taskbar Pull' -ErrorAction Stop; HLog 'his "Taskbar Pull" task started' } catch { HLog "could not start his task: $_" } }

$RealAppData = $env:APPDATA; $RealLocalAppData = $env:LOCALAPPDATA
