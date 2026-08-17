# Regenerates manifest.json from the data/ tree.
#
# Two sources:
#   data/    -> small files committed in the repo, downloaded via raw.githubusercontent.com
#   release/ -> BIG binaries that GitHub won't accept in a repo (>100MB).
#               Published as GitHub Release assets and downloaded via
#               https://github.com/<user>/<repo>/releases/download/<tag>/<name>
#
# data/ maps 1:1 onto %APPDATA%\cs2\ (the manifest "dest"). Example:
#   data/maps/de_mirage.map                 -> %APPDATA%\cs2\maps\de_mirage.map
#   data/maps/vphys/de_mirage.vphys         -> %APPDATA%\cs2\maps\vphys\de_mirage.vphys
#   data/models/agents/ctm_sas/ctm_sas.gltf -> %APPDATA%\cs2\models\agents\ctm_sas\ctm_sas.gltf
#
# release/ dest is derived from the filename:
#   <map>.map   -> maps\<map>.map
#   <map>.vphys -> maps\vphys\<map>.vphys
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tools\gen_manifest.ps1 [-Tag assets-v1]
# Params:
#   -Tag         release tag big files are uploaded under (default assets-v1)
#   -User -Repo  override GitHub owner/repo (else read from origin remote)
#   -RawLimitMB  files >= this size must live in release/ (default 90)

param(
    [string]$Tag        = "assets-v1",
    [string]$User       = "",
    [string]$Repo       = "",
    [int]   $RawLimitMB = 90
)

$ErrorActionPreference = "Stop"

$root         = Split-Path -Parent $PSScriptRoot
$data         = Join-Path $root "data"
$releaseDir   = Join-Path $root "release"
$manifestPath = Join-Path $root "manifest.json"

if (-not $User -or -not $Repo) {
    $remote = git -C $root remote get-url origin 2>$null
    if ($remote -match "github\.com[:/]([^/]+)/([^/]+?)(\.git)?$") {
        if (-not $User) { $User = $matches[1] }
        if (-not $Repo) { $Repo = $matches[2] }
    }
}
if (-not $User -or -not $Repo) {
    Write-Error "Could not determine GitHub user/repo. Pass -User and -Repo."
    exit 1
}
if (-not (Test-Path -LiteralPath $data)) {
    Write-Error "data folder not found: $data"
    exit 1
}
if (-not (Test-Path -LiteralPath $releaseDir)) {
    New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
}

$rawLimitMB = $RawLimitMB
$rawLimit   = $rawLimitMB * 1MB

function New-Entry([string]$rel, [string]$fullPath, [string]$dest, [string]$url) {
    $hash = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash.ToLowerInvariant()
    [ordered]@{
        path   = $rel
        dest   = $dest
        size   = (Get-Item -LiteralPath $fullPath).Length
        sha256 = $hash
        url    = $url
    }
}

function Map-ReleaseDest([string]$name) {
    if ($name -match '\.vphys$') { return "maps/vphys/$name" }
    if ($name -match '\.map$')   { return "maps/$name" }
    return $name
}

# dest for a release asset: keep the relative subpath under release/ (so
# models land in %APPDATA%\cs2\models\... exactly like the data/ layout),
# while the download URL uses the flat asset filename (GitHub releases are
# flat by name).
function Release-Dest([string]$relPath, [string]$relRoot) {
    $rel = $relPath.Substring($relRoot.Length + 1).Replace('\', '/')
    return $rel
}

$entries = @()
$releaseFiles = @()
$warnings = @()

# --- small files, hosted in the repo tree (raw.githubusercontent) ------------
Get-ChildItem -LiteralPath $data -Recurse -File | Where-Object { $_.Name -ne '.gitkeep' } | ForEach-Object {
    $rel  = $_.FullName.Substring($data.Length + 1).Replace('\', '/')
    if ($_.Length -ge $rawLimit) {
        $warnings += "TOO BIG for repo: data/$rel ($([math]::Round($_.Length/1MB))MB) - move it to release\"
        return
    }
    $url = "https://raw.githubusercontent.com/$User/$Repo/main/data/$rel"
    $entries += New-Entry "data/$rel" $_.FullName $rel $url
}

# --- big files, published as release assets --------------------------------
# release/ may be nested (e.g. release\maps, release\models\agents\...); scan
# recursively. dest keeps the relative subpath so models install to
# %APPDATA%\cs2\models\...; the URL uses the flat asset filename.
Get-ChildItem -LiteralPath $releaseDir -Recurse -File | Where-Object { $_.Name -ne '.gitkeep' } | ForEach-Object {
    $rel  = $_.FullName.Substring($releaseDir.Length + 1).Replace('\', '/')
    $dest = Release-Dest $_.FullName $releaseDir
    $url  = "https://github.com/$User/$Repo/releases/download/$Tag/$([uri]::EscapeDataString($_.Name))"
    $entries += New-Entry "release/$rel" $_.FullName $dest $url
    $releaseFiles += $_.FullName
}

$manifest = [ordered]@{ version = 1; files = $entries }
$json = $manifest | ConvertTo-Json -Depth 4
[System.IO.File]::WriteAllText($manifestPath, $json, (New-Object System.Text.UTF8Encoding($false)))

Write-Host ""
Write-Host "manifest.json written: $manifestPath  (user=$User repo=$Repo tag=$Tag)"
Write-Host "  raw entries:     $($entries.Count - $releaseFiles.Count)"
Write-Host "  release entries: $($releaseFiles.Count)"

foreach ($w in $warnings) { Write-Warning $w }

if ($releaseFiles.Count -gt 0) {
    $files = ($releaseFiles | ForEach-Object { '"' + $_ + '"' }) -join ' '
    Write-Host ""
    Write-Host "Big files are NOT committed to git. Publish them as release assets:"
    Write-Host ""
    Write-Host "  gh release create $Tag $files"
    Write-Host "  gh release upload $Tag $files --clobber"
    Write-Host ""
    Write-Host "Then commit + push manifest.json."
}
