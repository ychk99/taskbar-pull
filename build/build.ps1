<#
.SYNOPSIS
  Builds every Taskbar Pull artifact from the source tree into dist\:
    TaskbarPull-<v>-portable.zip   portable folder (TaskbarPull.exe + TaskbarPull.ahk + lib + assets)
    TaskbarPull-<v>-setup.exe      per-user Inno Setup installer (no admin rights)
    TaskbarPull-<v>-x64.msix       Microsoft Store package (unsigned: the Store signs it)
    winget\manifests\...           winget manifest draft for the installer
    SHA256SUMS.txt
.EXAMPLE
  pwsh build\get-tools.ps1; pwsh build\build.ps1 -Version 1.0.0
.NOTES
  TaskbarPull.exe is the official AutoHotkey 2.0.31 interpreter (AutoHotkey64.exe), unchanged
  and only renamed: started without a script, it runs TaskbarPull.ahk from its own folder.
#>
[CmdletBinding()]
param(
    [string]$Version,
    [string]$RepoUrl = 'https://github.com/ychk99/taskbar-pull',
    # Store identity: fill these from Partner Center (Product identity page) before submitting
    [string]$IdentityName = 'YsIdeas.TaskbarPull',
    [string]$Publisher = 'CN=00000000-0000-0000-0000-000000000000',
    [string]$PublisherDisplayName = "Y's ideas",
    [string]$WingetId = 'YsIdeas.TaskbarPull',
    [string]$Out,
    [switch]$SkipInstaller, [switch]$SkipMsix,
    [switch]$Scan     # scan the artifacts with Microsoft Defender (MpCmdRun) and print the result
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot
if (!$Out) { $Out = Join-Path $Root 'dist' }
$Cache = Join-Path $PSScriptRoot '.cache'
$Src = Join-Path $Root 'src'
$Utf8Bom = New-Object System.Text.UTF8Encoding $true

if (!$Version) {
    $Version = [regex]::Match((Get-Content "$Src\lib\Version.ahk" -Raw), 'AppVersion := "([^"]+)"').Groups[1].Value
}
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "Version must look like 1.2.3, got '$Version'" }
Write-Host "Taskbar Pull $Version"

$ahk = Join-Path $Cache 'ahk\AutoHotkey64.exe'
if (!(Test-Path $ahk)) { & (Join-Path $PSScriptRoot 'get-tools.ps1') -SkipInno:$SkipInstaller }

if (Test-Path $Out) {
    # keep old builds out of the way instead of deleting them
    $old = Join-Path (Split-Path $Out) ("dist-old\" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -ItemType Directory -Force (Split-Path $old) | Out-Null
    Move-Item $Out $old
}
New-Item -ItemType Directory -Force $Out | Out-Null

# ---------------------------------------------------------------- stage
$stage = Join-Path $Out 'stage\TaskbarPull'
New-Item -ItemType Directory -Force "$stage\lib", "$stage\assets", "$stage\licenses" | Out-Null
Copy-Item $ahk "$stage\TaskbarPull.exe"
foreach ($f in @(Get-Item "$Src\TaskbarPull.ahk") + @(Get-ChildItem "$Src\lib\*.ahk")) {
    $rel = $f.FullName.Substring($Src.Length + 1)
    $text = [IO.File]::ReadAllText($f.FullName)
    if ($f.Name -eq 'Version.ahk') {
        $text = $text -replace 'AppVersion := "[^"]*"', "AppVersion := `"$Version`"" -replace 'ProjectUrl := "[^"]*"', "ProjectUrl := `"$RepoUrl`""
    }
    [IO.File]::WriteAllText((Join-Path $stage $rel), $text, $Utf8Bom)
}
Copy-Item "$Src\assets\*.ico" "$stage\assets"
Copy-Item "$Root\LICENSE" "$stage\LICENSE.txt"
Copy-Item "$Root\THIRD-PARTY-NOTICES" "$stage\THIRD-PARTY-NOTICES.txt"
Copy-Item (Join-Path $Cache 'ahk\license.txt') "$stage\licenses\AutoHotkey-license.txt"

# syntax check with the shipped interpreter
$p = Start-Process "$stage\TaskbarPull.exe" -ArgumentList '/ErrorStdOut', '/Validate', "`"$stage\TaskbarPull.ahk`"" `
    -RedirectStandardError "$Out\validate.txt" -PassThru -Wait -WindowStyle Hidden
if ($p.ExitCode) { Get-Content "$Out\validate.txt"; throw "TaskbarPull.ahk does not validate ($($p.ExitCode))" }
Write-Host 'script validated'

$artifacts = @()

# ---------------------------------------------------------------- portable zip
$zip = Join-Path $Out "TaskbarPull-$Version-portable.zip"
Compress-Archive -Path $stage -DestinationPath $zip -CompressionLevel Optimal
$artifacts += $zip

# ---------------------------------------------------------------- installer (Inno Setup, per user)
if (!$SkipInstaller) {
    $iscc = @("${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (!$iscc) { throw 'ISCC.exe not found: run build\get-tools.ps1' }
    & $iscc /Q "/DAppVersion=$Version" "/DStageDir=$stage" "/DOutDir=$Out" "/DRepoUrl=$RepoUrl" `
        (Join-Path $Root 'packaging\inno\TaskbarPull.iss')
    if ($LASTEXITCODE) { throw "ISCC failed ($LASTEXITCODE)" }
    $artifacts += Join-Path $Out "TaskbarPull-$Version-setup.exe"
}

# ---------------------------------------------------------------- MSIX
if (!$SkipMsix) {
    $bt = Join-Path $Cache 'buildtools'
    $makeappx = (Get-ChildItem $bt -Recurse -Filter makeappx.exe | Where-Object FullName -match '\\x64\\' | Select-Object -First 1).FullName
    $makepri = (Get-ChildItem $bt -Recurse -Filter makepri.exe | Where-Object FullName -match '\\x64\\' | Select-Object -First 1).FullName
    $layout = Join-Path $Out 'msix-layout'
    Copy-Item $stage $layout -Recurse
    $man = [IO.File]::ReadAllText((Join-Path $Root 'packaging\msix\AppxManifest.xml'))
    $man = $man.Replace('{{VERSION}}', "$Version.0").Replace('{{IDENTITY_NAME}}', $IdentityName).
        Replace('{{PUBLISHER}}', [Security.SecurityElement]::Escape($Publisher)).
        Replace('{{PUBLISHER_DISPLAY_NAME}}', [Security.SecurityElement]::Escape($PublisherDisplayName))
    [IO.File]::WriteAllText("$layout\AppxManifest.xml", $man, (New-Object System.Text.UTF8Encoding $false))
    New-Item -ItemType Directory -Force "$layout\Assets" | Out-Null
    # qualified logos only (scale-*/targetsize-*); resources.pri maps the manifest names to them
    Copy-Item "$Root\packaging\msix\Assets\*.*-*.png" "$layout\Assets"
    if ($makepri) {
        Push-Location $Out
        try {
            & $makepri createconfig /cf "$Out\priconfig.xml" /dq en-US /pv 10.0.0 /o | Out-Null
            # one resources.pri for this single package (no per-scale resource packs)
            $cfg = [IO.File]::ReadAllText("$Out\priconfig.xml") -replace '(?s)<packaging>.*?</packaging>', ''
            [IO.File]::WriteAllText("$Out\priconfig.xml", $cfg)
            & $makepri new /pr $layout /cf "$Out\priconfig.xml" /mn "$layout\AppxManifest.xml" /of "$layout\resources.pri" /o | Out-Null
            if ($LASTEXITCODE) { throw "makepri failed ($LASTEXITCODE)" }
        } finally { Pop-Location }
    } else {
        Copy-Item "$Root\packaging\msix\Assets\*.png" "$layout\Assets"
    }
    $msix = Join-Path $Out "TaskbarPull-$Version-x64.msix"
    & $makeappx pack /d $layout /p $msix /o | Tee-Object -FilePath "$Out\makeappx.txt" | Out-Null
    if ($LASTEXITCODE) { Get-Content "$Out\makeappx.txt"; throw "makeappx failed ($LASTEXITCODE)" }
    Write-Host 'MSIX packed and validated by makeappx'
    $artifacts += $msix
}

# ---------------------------------------------------------------- winget manifest draft
if (!$SkipInstaller) {
    $setup = Join-Path $Out "TaskbarPull-$Version-setup.exe"
    $sha = (Get-FileHash $setup -Algorithm SHA256).Hash
    $wdir = Join-Path $Out "winget\manifests\$($WingetId.Substring(0,1).ToLower())\$($WingetId.Replace('.', '\'))\$Version"
    New-Item -ItemType Directory -Force $wdir | Out-Null
    foreach ($t in Get-ChildItem "$Root\packaging\winget\*.yaml") {
        $y = [IO.File]::ReadAllText($t.FullName).Replace('{{VERSION}}', $Version).Replace('{{SHA256}}', $sha).
            Replace('{{REPO_URL}}', $RepoUrl).Replace('{{PACKAGE_ID}}', $WingetId).
            Replace('{{RELEASE_DATE}}', (Get-Date -Format 'yyyy-MM-dd'))
        $name = $t.Name.Replace('PACKAGE_ID', $WingetId)
        [IO.File]::WriteAllText((Join-Path $wdir $name), $y, (New-Object System.Text.UTF8Encoding $false))
    }
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $v = winget validate --manifest $wdir --disable-interactivity 2>&1 | Out-String
        Write-Host "winget validate: $($v.Trim())"
    }
}

# ---------------------------------------------------------------- checksums
$sums = foreach ($a in $artifacts) { "{0}  {1}" -f (Get-FileHash $a -Algorithm SHA256).Hash.ToLower(), (Split-Path $a -Leaf) }
$sums | Set-Content (Join-Path $Out 'SHA256SUMS.txt') -Encoding ascii
$artifacts | ForEach-Object { '{0,-40} {1,10:N0} bytes' -f (Split-Path $_ -Leaf), (Get-Item $_).Length } | Write-Host

if ($Scan) {
    $mp = "$env:ProgramFiles\Windows Defender\MpCmdRun.exe"
    foreach ($a in @("$stage\TaskbarPull.exe") + $artifacts) {
        $r = & $mp -Scan -ScanType 3 -File $a -DisableRemediation 2>&1 | Out-String
        Write-Host ("Defender {0}: exit {1} | {2}" -f (Split-Path $a -Leaf), $LASTEXITCODE, ($r -replace '\s+', ' ').Trim())
    }
}
