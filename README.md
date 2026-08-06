# itami assets

Data files the itami loader auto-installs into `%APPDATA%\cs2`.

## Layout

The `data/` tree maps 1:1 onto `%APPDATA%\cs2\`:

```
data/
  maps/
    de_mirage.map            -> %APPDATA%\cs2\maps\de_mirage.map
    ...
    vphys/
      de_mirage.vphys        -> %APPDATA%\cs2\maps\vphys\de_mirage.vphys
      ...
  models/
    agents/
      ctm_sas/ctm_sas.gltf   -> %APPDATA%\cs2\models\agents\ctm_sas\ctm_sas.gltf
      ctm_sas/ctm_sas.bin
      tm_phoenix/tm_phoenix.gltf
      tm_phoenix/tm_phoenix.bin
```

`manifest.json` (at repo root) tells the loader exactly what to download, the
target path, size and sha256. The loader only fetches files that are missing or
fail the checksum, so you can add/update files without breaking installs.

## Adding files

1. Drop the files into the matching folders under `data/`.
2. Run the manifest generator:

   ```powershell
   .\tools\gen_manifest.ps1
   ```

3. Commit and push. That's it - the loader picks it up automatically.

## File expectations

- `maps\*.map` - pre-generated parser cache dumps (the cheat can also generate
  these itself from a `.vphys`, but shipping them skips the in-game wait).
- `maps\vphys\*.vphys` - raw physics dump for the matching map.
- `models\agents\*` - Source 2 Viewer glTF exports: `<name>\<name>.gltf` +
  `<name>.bin` (T-pose skinned mesh), used for gpu chams.
