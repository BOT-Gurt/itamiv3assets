# Regenerates manifest.json from the data/ tree.
# Run from repo root (or anywhere):  .\tools\gen_manifest.ps1

$root = Split-Path -Parent $PSScriptRoot
$data = Join-Path $root "data"
$manifestPath = Join-Path $root "manifest.json"

if (-not (Test-Path -LiteralPath $data)) {
    Write-Error "data folder not found: $data"
    exit 1
}

$entries = @(
    Get-ChildItem -LiteralPath $data -Recurse -File | Where-Object { $_.Name -ne '.gitkeep' } | ForEach-Object {
        $rel = $_.FullName.Substring($data.Length + 1).Replace('\', '/')
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        [ordered]@{
            path   = "data/$rel"
            dest   = $rel
            size   = $_.Length
            sha256 = $hash
        }
    }
)

$manifest = [ordered]@{
    version = 1
    files   = $entries
}

$json = $manifest | ConvertTo-Json -Depth 4
Set-Content -LiteralPath $manifestPath -Value $json -Encoding UTF8

$count = $entries.Count
Write-Host "manifest.json written ($count file(s)) -> $manifestPath"
