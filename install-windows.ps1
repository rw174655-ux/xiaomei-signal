# Install CLI (+ optional tray) for Windows. Does not touch the macOS Swift app.
$ErrorActionPreference = "Stop"
$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SupportDir = Join-Path $env:LOCALAPPDATA "XiaomeiSignal"

if (-not (Get-Command python -ErrorAction SilentlyContinue) -and -not (Get-Command python3 -ErrorAction SilentlyContinue)) {
    Write-Error "python not found on PATH. Install Python 3 from https://www.python.org/ and re-run."
}

$Py = if (Get-Command python -ErrorAction SilentlyContinue) { "python" } else { "python3" }

Write-Host "==> Installing into: $SupportDir"
New-Item -ItemType Directory -Force -Path $SupportDir | Out-Null
$files = @(
    "xiaomei_signal.py",
    "set-status.py",
    "set-status.cmd",
    "show-status.py",
    "tray.py"
)
foreach ($f in $files) {
    Copy-Item -Force (Join-Path $RepoDir $f) (Join-Path $SupportDir $f)
}

$statusPath = Join-Path $SupportDir "status.json"
if (-not (Test-Path $statusPath)) {
    & $Py (Join-Path $SupportDir "set-status.py") green "已安装 (Windows)" | Out-Null
}

Write-Host "==> Done."
Write-Host "Data dir: $SupportDir"
Write-Host "Set status:  & `"$SupportDir\set-status.cmd`" yellow `"等你`" `"小梅`""
Write-Host "         or: $Py `"$SupportDir\set-status.py`" green `"推进中`" `"小梅`""
Write-Host "Watch CLI:   $Py `"$SupportDir\show-status.py`" -w"
Write-Host "Tray (opt):  $Py -m pip install --user pystray pillow"
Write-Host "             $Py `"$SupportDir\tray.py`""
Write-Host "Tip: add $SupportDir to User PATH to run set-status.cmd from anywhere."
