# Runs the headless mission smoke test for all 15 missions.
param([string]$Godot = "godot", [switch]$KeepLogs)

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$dir = Join-Path $PSScriptRoot "out"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$failed = @()

for ($m = 1; $m -le 15; $m++) {
    $env:MISSION = "$m"
    $log = Join-Path $dir "mission_$m.log"
    & $Godot --headless --path $root "res://tools/test/MissionTest.tscn" *> $log
    $code = $LASTEXITCODE
    $line = (Select-String -Path $log -Pattern '\[IGI2D\]' | Select-Object -Last 1).Line
    Write-Output "M$m (exit $code): $line"
    if ($code -ne 0 -or $line -notmatch '\[IGI2D\] PASS') {
        $failed += $m
        Select-String -Path $log -Pattern 'FAIL|SCRIPT ERROR' | Select-Object -First 6 |
            ForEach-Object { Write-Output "    $($_.Line.Trim())" }
    }
    if (-not $KeepLogs) { Remove-Item $log -Force }
}
Remove-Item Env:MISSION -ErrorAction SilentlyContinue
if ($failed.Count -gt 0) { throw "Failing missions: $($failed -join ', ')" }
Write-Output "[IGI2D] ALL 15 MISSIONS PASS"
