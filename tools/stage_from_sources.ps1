# Copies the cheat's locally-generated data into this repo's staging folders.
#
# Sources (defaults):
#   maps    : %APPDATA%\cs2\maps\*.map        -> data\maps\            (< raw limit)
#   vphys   : %APPDATA%\cs2\maps\vphys\*.vphys -> data\maps\vphys\      (< raw limit)
#   agents  : %USERPROFILE%\Downloads\agents\models\{ctm_sas,tm_phoenix}
#                                                    \{name}.gltf + .bin -> data\models\agents\{name}\
#
# Files at/over RawLimitMB land in release\ instead (those go to GitHub
# Releases, not the repo). Run this, then:
#   1. gh release upload assets-v1 release\* --clobber
#   2. powershell -ExecutionPolicy Bypass -File tools\gen_manifest.ps1
#   3. commit + push
#
# Params: -MapsDir -VPhysDir -AgentsDir -RawLimitMB

param(
    [string]$MapsDir   = "$env:APPDATA\cs2\maps",
    [string]$VPhysDir  = "$env:APPDATA\cs2\maps\vphys",
    [string]$AgentsDir = "$env:USERPROFILE\Downloads\agents\models",
    [int]   $RawLimitMB = 90
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$rawLimit = $RawLimitMB * 1MB

function Copy-Partition([string]$srcDir, [string]$dataSub, [string]$releaseSub) {
    if (-not (Test-Path -LiteralPath $srcDir)) {
        Write-Warning "source missing: $srcDir"
        return @{ data = 0; release = 0 }
    }
    $counts = @{ data = 0; release = 0 }
    Get-ChildItem -LiteralPath $srcDir -File | Where-Object { $_.Name -ne '.gitkeep' } | ForEach-Object {
        if ($_.Length -ge $rawLimit) {
            $target = Join-Path $root ("release" + [IO.Path]::DirectorySeparatorChar + $releaseSub)
        } else {
            $target = Join-Path $root ("data" + [IO.Path]::DirectorySeparatorChar + $dataSub)
        }
        New-Item -ItemType Directory -Path $target -Force | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $target $_.Name) -Force
        if ($_.Length -ge $rawLimit) { $counts.release++ } else { $counts.data++ }
    }
    return $counts
}

# --- maps + vphys ---
$m  = Copy-Partition $MapsDir  "maps"   "maps"
$v  = Copy-Partition $VPhysDir "maps\vphys" "maps\vphys"

# --- agent chams (gltf + matching bin) ---
$aData = 0
if (Test-Path -LiteralPath $AgentsDir) {
    foreach ($agent in @("ctm_sas", "tm_phoenix")) {
        $src = Join-Path $AgentsDir $agent
        if (-not (Test-Path -LiteralPath $src)) { continue }
        foreach ($ext in @("gltf", "bin")) {
            $file = Join-Path $src "$agent.$ext"
            if (Test-Path -LiteralPath $file) {
                $target = Join-Path $root "data\models\agents\$agent"
                New-Item -ItemType Directory -Path $target -Force | Out-Null
                Copy-Item -LiteralPath $file -Destination $target -Force
                $aData++
            }
        }
    }
}

Write-Host ""
Write-Host "Staged:"
Write-Host "  maps  -> data\maps      : $($m.data)   release\maps      : $($m.release)"
Write-Host "  vphys -> data\maps\vphys: $($v.data)   release\maps\vphys: $($v.release)"
Write-Host "  agents-> data\models\agents: $aData"
Write-Host ""
if (($m.release + $v.release) -gt 0) {
    Write-Host "Next steps:"
    Write-Host "  gh release upload assets-v1 release\* --clobber"
    Write-Host "  powershell -ExecutionPolicy Bypass -File tools\gen_manifest.ps1"
    Write-Host "  git add -A; git commit -m 'publish data'; git push"
}
