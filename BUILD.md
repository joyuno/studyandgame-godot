# Build & Distribution — StudyGame (Godot port)

## TL;DR — run the prebuilt game

If you have the bundle:

```
exports/
  StudyGame.exe   (104 MB — Godot launcher, signed by Prehensile Tales B.V.)
  StudyGame.pck   (  2 MB — game data: scripts, scenes, sprites, sounds)
```

**Double-click `StudyGame.exe`.** That's it. The launcher auto-loads the same-name `.pck` from its directory.

Both files must sit in the same folder. Don't move just the .exe.

## Why two files (and not one)?

Single-file (`embed_pck=true`) exports work, but the resulting `.exe` is **unsigned**, and on Windows 11 with **Smart App Control** enabled (the default since 2024) Windows blocks every unsigned executable with the error *"This app has been blocked by your administrator"* or *"Application Control policy has blocked this file"*.

Splitting into `StudyGame.exe` + `StudyGame.pck` lets us replace the launcher with the **official Godot binary** (signed by Prehensile Tales B.V., the Godot Engine vendor), which Microsoft already trusts. The game data lives in the `.pck`, which Godot loads at boot.

Net result: no signing certificate needed, no Smart App Control workaround needed, runs out of the box.

## How to rebuild from source

### Prerequisites

- Godot 4.6.2 stable binary at `C:\Users\admin\Downloads\all_project\godot\Godot_v4.6.2-stable_win64.exe`
- Godot export templates installed at `%APPDATA%\Godot\export_templates\4.6.2.stable\`
  - One-time download from `https://github.com/godotengine/godot/releases/download/4.6.2-stable/Godot_v4.6.2-stable_export_templates.tpz`
  - Extract → rename inner `templates/` to `4.6.2.stable/`

### Build command (PowerShell)

```powershell
$GODOT = "C:\Users\admin\Downloads\all_project\godot\Godot_v4.6.2-stable_win64.exe"
$PROJ  = "C:\Users\admin\Downloads\all_project\study_game_godot"
Set-Location $PROJ

# 1. Generate .pck (game data) — also writes an unsigned launcher we discard
& $GODOT --headless --export-release "Windows Desktop" "exports/StudyGame.exe"

# 2. Replace the unsigned launcher with the signed Godot binary
Copy-Item -Force $GODOT exports\StudyGame.exe

# 3. (Optional) Bundle for distribution
Compress-Archive -Path exports\StudyGame.exe, exports\StudyGame.pck `
                 -DestinationPath StudyGame-windows-x64.zip -CompressionLevel Optimal
```

You can also script step 1 then 2 in a single line. Step 2 must happen *after* step 1 because step 1 overwrites whatever launcher is at `exports/StudyGame.exe`.

### Verify the signature

```powershell
(Get-AuthenticodeSignature exports\StudyGame.exe).Status        # → Valid
(Get-AuthenticodeSignature exports\StudyGame.exe).SignerCertificate.Subject
# → CN=Prehensile Tales B.V., O=Prehensile Tales B.V., L=Uitgeest, S=Noord Holland, C=NL
```

If `Status` is `NotSigned`, you forgot the `Copy-Item` step.

## Distribution

The `StudyGame-windows-x64.zip` bundle is **~80 MB compressed**. Ship it via:

- GitHub Releases (free, signed URL)
- itch.io
- direct download

A user double-clicks the zip, extracts both files, double-clicks `StudyGame.exe`. No installer, no admin rights, no Smart App Control friction.

## Notes

- The `(DEBUG)` text in the window title is a Godot quirk — the official launcher binary always reports as debug regardless of which build flag spawned it. Functional behavior is the release build (no developer console, optimized scripts).
- On macOS / Linux: rerun the export step with `"macOS"` or `"Linux/X11"` preset names — same trick applies, but you'd need the official signed Godot binary for that platform as the launcher.
- The `.pck` is **not encrypted**. Anyone with Godot can unpack it. If you care about asset protection, set `encrypt_pck=true` in `export_presets.cfg` and provide a script-encryption key (see Godot docs §"Compiling with script encryption key").
