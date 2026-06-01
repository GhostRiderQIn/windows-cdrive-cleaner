# Windows C-Drive Cleaner

> A modular, interactive batch script to safely free up space on your Windows C drive.
> Works on **Chinese, English, and all Windows locales**.

## Quick Start

1. **Right-click → Run as Administrator** on `cleanup.bat`
2. Each item is **scanned first**, then you **decide** whether to clean
3. Press `Y` to clean, `N` to skip, `Q` to quit

### Dry-Run Mode

```bash
cleanup.bat --dry-run
# or
cleanup.bat -d
```

Scans all active items and shows what *could* be freed, but **does not delete anything**.

```
  +-- NVIDIA Shader Cache (DXCache)
  |  Location: C:\Users\xxx\AppData\Local\NVIDIA\DXCache
  |  Size: 1240 MB
  +-- [Y]Clean  [N]Skip  [Q]Quit:
```

## Active Cleanup Modules

| Module | Admin | Path |
|--------|:---:|------|
| NVIDIA Shader Cache (DXCache) | | `%LOCALAPPDATA%\NVIDIA\DXCache` |
| Hibernation file (hiberfil.sys) | ⚡ | `C:\hiberfil.sys` (disables hibernation) |

⚡ = Requires Administrator privileges

## Inactive Modules (commented out)

Uncomment the `call :module` lines in `cleanup.bat` to enable:

| Module | Admin | Path |
|--------|:---:|------|
| NVIDIA Shader Cache (GLCache) | | `%LOCALAPPDATA%\NVIDIA\GLCache` |
| Windows Temp files | | `%TEMP%` + `C:\Windows\Temp` |
| Recycle Bin | | All drives `$Recycle.Bin` |
| Browser cache (Chrome / Edge) | | Chrome + Edge Cache |
| Windows Update download cache | ⚡ | `C:\Windows\SoftwareDistribution\Download` |
| Windows Delivery Optimization | ⚡ | `C:\Windows\SoftwareDistribution\DeliveryOptimization` |
| Windows Error Reports (WER) | ⚡ | CrashDumps + ReportArchive + ReportQueue |
| Thumbnail cache | | `thumbcache_*.db` + `iconcache_*.db` |
| Prefetch files | ⚡ | `C:\Windows\Prefetch\*.pf` |
| pip package cache | | `%LOCALAPPDATA%\pip\cache` |
| npm package cache | | `%LOCALAPPDATA%\npm-cache` |

## How to Add a New Cleanup Module

**Step 1:** Write a function at the end of the file:

```batch
:clean_my_feature
set "target=C:\Path\To\Clean"
call :get_size "%target%" size_before
if "%~2"=="1" (                   :: dry-run: measure only
    set "%~1=!size_before!"
    goto :eof
)
if !size_before! gtr 0 (
    del /f /s /q "%target%\*" 2>nul
)
set "%~1=!size_before!"
goto :eof
```

**Step 2:** Register in the `:main` section:

```batch
call :module  "My Cleanup Item"  clean_my_feature  1  "C:\Path\To\Clean"
```

The third parameter `1` means requires Admin (`0` for no Admin). The dispatcher handles permission checks, size scanning, user confirmation, and result aggregation automatically.

## Changelog

### v2.0
- **Fix:** Folder size calculation rewritten to use PowerShell, now works on any Windows locale (was Chinese-only)
- **Fix:** Browser cache path corrected from `Cache\Cache_Data` to `Cache`
- **Fix:** UI changed to English for cross-locale compatibility
- **Feat:** `--dry-run` / `-d` flag for scan-only mode

### v1.1
- Two-step cleanup: scan first, confirm before deleting
- 13 cleanup modules with modular architecture

## License

MIT
