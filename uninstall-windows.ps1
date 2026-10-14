$ErrorActionPreference = "Continue"
$SupportDir = Join-Path $env:LOCALAPPDATA "XiaomeiSignal"
$Purge = $args -contains "--purge"

if ($Purge) {
    Write-Host "==> Removing $SupportDir"
    Remove-Item -Recurse -Force $SupportDir -ErrorAction SilentlyContinue
} else {
    Write-Host "==> Removing scripts, keeping status.json"
    @(
        "xiaomei_signal.py",
        "set-status.py",
        "set-status.cmd",
        "show-status.py",
        "tray.py",
        "desktop_light.py",
        "xiaomei-light.cmd"
    ) | ForEach-Object {
        Remove-Item -Force (Join-Path $SupportDir $_) -ErrorAction SilentlyContinue
    }
    Write-Host "Kept $SupportDir (run with -Args '--purge' to delete it)."
}
Write-Host "==> Done."
