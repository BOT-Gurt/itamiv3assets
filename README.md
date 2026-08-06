# itami assets

Data files the itami loader auto-installs into `%APPDATA%\cs2`.

## How the loader gets files

Two kinds of files:

- **Raw repo files** (`data/`) - small files committed to git, downloaded from
  `raw.githubusercontent.com`.
- **GitHub Release assets** (`release/`) - anything GitHub refuses to store in a
  repo (>100 MB per file, e.g. the big `.vphys` dumps). These are published as
  release assets and downloaded from `releases/download/<tag>/<name>`.

`manifest.json` (repo root) tells the loader the target path, size and sha256 for
every file, plus the exact download URL. The loader only fetches files that are
missing or fail the checksum, so updates don't redownload everything.

## Layout

`data/` maps 1:1 onto `%APPDATA%\cs2\`:

```
data/
  maps/
    de_mirage.map            -> %APPDATA%\cs2\maps\de_mirage.map
    vphys/
      de_mirage.vphys        -> %APPDATA%\cs2\maps\vphys\de_mirage.vphys
  models/
    agents/
      ctm_sas/ctm_sas.gltf   -> %APPDATA%\cs2\models\agents\ctm_sas\ctm_sas.gltf
      ctm_sas/ctm_sas.bin
      tm_phoenix/tm_phoenix.gltf
      tm_phoenix/tm_phoenix.bin
```

`release/` (gitignored, never committed) holds the >90 MB files. The dest there
is derived from the filename: `<map>.map` -> `maps\`, `<map>.vphys` ->
`maps\vphys\`.

## Adding / updating files

1. Drop small files into the matching folder under `data/`.
2. Drop big files (`.vphys` dumps, giant `.map`) into `release/`.
3. Publish the big files as release assets once:

   ```powershell
   gh release create assets-v1 release\*
   # later updates:
   gh release upload assets-v1 release\* --clobber
   ```

   (Install `gh` and run `gh auth login` first. No `gh`? Use the GitHub web UI:
   Releases -> Draft new release -> tag `assets-v1` -> attach the files.)

4. Regenerate the manifest:

   ```powershell
   powershell -ExecutionPolicy Bypass -File tools\gen_manifest.ps1
   ```

5. Commit and push `manifest.json` (and the small `data/` files).

The loader picks it all up automatically on next launch.

## File expectations

- `maps\*.map` - pre-generated parser cache dumps (the cheat can also generate
  these from a `.vphys`, but shipping them skips the in-game wait).
- `maps\vphys\*.vphys` - raw physics dump for the matching map.
- `models\agents\*` - Source 2 Viewer glTF exports: `<name>\<name>.gltf` +
  `<name>.bin` (T-pose skinned mesh), used for gpu chams.
