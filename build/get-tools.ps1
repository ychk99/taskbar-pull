<#
.SYNOPSIS
  Downloads the build inputs into build\.cache and checks them:
    - AutoHotkey 2.0.31 (official zip from AutoHotkey's GitHub releases, SHA-256 pinned below)
    - makeappx.exe / makepri.exe from Microsoft's Microsoft.Windows.SDK.BuildTools NuGet package
    - Inno Setup 6 (official, Authenticode-checked), installed per user when ISCC.exe is not found
  Nothing here needs administrator rights.
#>
[CmdletBinding()]
param(
    [string]$Cache,
    [switch]$SkipInno
)
$ErrorActionPreference = 'Stop'
if (!$Cache) { $Cache = Join-Path $PSScriptRoot '.cache' }
$ProgressPreference = 'SilentlyContinue'

# ---- pinned inputs (update together)
$AhkVersion = '2.0.31'
# GitHub release, not autohotkey.com: its Cloudflare check answers CI runners with a challenge page (same file, same hash)
$AhkZipUrl = "https://github.com/AutoHotkey/AutoHotkey/releases/download/v$AhkVersion/AutoHotkey_$AhkVersion.zip"
$AhkZipSha256 = 'CA1A595ACA4528755D8D4CD7FED23D497A37BD9A0B6892072612D68DEE1BD00A'
$BuildToolsVersion = '10.0.28000.2957'
$BuildToolsUrl = "https://api.nuget.org/v3-flatcontainer/microsoft.windows.sdk.buildtools/$BuildToolsVersion/microsoft.windows.sdk.buildtools.$BuildToolsVersion.nupkg"
$InnoUrl = 'https://github.com/jrsoftware/issrc/releases/download/is-6_7_4/innosetup-6.7.4.exe'

New-Item -ItemType Directory -Force $Cache | Out-Null

function Get-File($url, $path) {
    if (!(Test-Path $path)) {
        Write-Host "download $url"
        Invoke-WebRequest $url -OutFile $path -UseBasicParsing
    }
}

# ---- AutoHotkey
$ahkZip = Join-Path $Cache "AutoHotkey_$AhkVersion.zip"
Get-File $AhkZipUrl $ahkZip
$h = (Get-FileHash $ahkZip -Algorithm SHA256).Hash
if ($h -ne $AhkZipSha256) { throw "AutoHotkey zip hash mismatch: $h (expected $AhkZipSha256)" }
$ahkDir = Join-Path $Cache 'ahk'
if (!(Test-Path "$ahkDir\AutoHotkey64.exe")) { Expand-Archive $ahkZip $ahkDir -Force }
Write-Host "AutoHotkey $AhkVersion OK ($h)"

# ---- makeappx / makepri (Windows SDK build tools, NuGet)
$bt = Join-Path $Cache 'buildtools'
if (!(Get-ChildItem $bt -Recurse -Filter makeappx.exe -ErrorAction SilentlyContinue)) {
    $nupkg = Join-Path $Cache "buildtools.$BuildToolsVersion.zip"
    Get-File $BuildToolsUrl $nupkg
    Expand-Archive $nupkg $bt -Force
}
$makeappx = Get-ChildItem $bt -Recurse -Filter makeappx.exe | Where-Object FullName -match '\\x64\\' | Select-Object -First 1
if (!$makeappx) { throw 'makeappx.exe not found in the build tools package' }
Write-Host "makeappx: $($makeappx.FullName)"

# ---- Inno Setup
if (!$SkipInno) {
    $iscc = @("${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (!$iscc) {
        $inst = Join-Path $Cache 'innosetup-6.7.4.exe'
        Get-File $InnoUrl $inst
        $sig = Get-AuthenticodeSignature $inst
        if ($sig.Status -ne 'Valid') { throw "Inno Setup installer signature: $($sig.Status)" }
        Write-Host "installing Inno Setup per user (signed by $($sig.SignerCertificate.Subject))"
        $p = Start-Process $inst -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CURRENTUSER', '/NOICONS' -PassThru -Wait
        if ($p.ExitCode) { throw "Inno Setup install failed: $($p.ExitCode)" }
        $iscc = "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
    }
    Write-Host "ISCC: $iscc"
}
