@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: ============================================================
::  Windows System Cleanup Tool  v2.0
::  Locale-independent (Chinese / English / all Windows)
::  Modular design, two-step interactive confirmation
::  Run as Administrator to unlock all features
:: ============================================================

title Windows System Cleanup Tool

:: ---- Permission check ----
net session >nul 2>&1
if errorlevel 1 (
    echo [Warning] Not running as Administrator - some features disabled
    echo ----------------------------------------------------
    set ADMIN=0
) else (
    set ADMIN=1
)

:: ---- Dry-run mode ----
set DRY_RUN=0
if /i "%~1"=="--dry-run" set DRY_RUN=1
if /i "%~1"=="-d"        set DRY_RUN=1

:: ---- Init stats ----
set TOTAL_FREED=0
set TOTAL_SCAN=0

:: ============================================================
::  Module registry - add new cleanup items here
::  Format: call :module  "Display Name"  "Function"  "NeedAdmin"  "Path"
:: ============================================================
goto :main

:main
echo.
echo   +----------------------------------------------+
echo   ^|    Windows System Cleanup Tool  v2.0        ^|
echo   ^|    Free up your C drive space safely        ^|
if !DRY_RUN!==1 (
    echo   ^|    *** DRY-RUN MODE - scan only ***      ^|
)
echo   +----------------------------------------------+
echo.
if !DRY_RUN!==1 (
    echo   Dry-run mode: scanning only, no files will be deleted.
) else (
    echo   Scanning for cleanup targets...
)
echo ============================================================

:: ---------- Cleanup modules ----------
call :module  "NVIDIA Shader Cache - DXCache"      clean_nvidia_dxcache     0  "%LOCALAPPDATA%\NVIDIA\DXCache"
call :module  "Hibernation file - hiberfil.sys"    clean_hiberfil           1  "C:\hiberfil.sys - disables hibernation"
:: call :module  "NVIDIA Shader Cache - GLCache"      clean_nvidia_glcache     0  "%LOCALAPPDATA%\NVIDIA\GLCache"
:: call :module  "Windows Temp files"                 clean_temp               0  "%%TEMP%% + C:\Windows\Temp"
:: call :module  "Recycle Bin"                        clean_recycle            0  "All drives \$Recycle.Bin"
:: call :module  "Browser cache - Chrome / Edge"      clean_browser_cache      0  "Chrome + Edge Cache"
:: call :module  "Windows Update download cache"      clean_windows_update     1  "C:\Windows\SoftwareDistribution\Download"
:: call :module  "Windows Delivery Optimization"      clean_delivery_opt       1  "C:\Windows\SoftwareDistribution\DeliveryOptimization"
:: call :module  "Windows Error Reports - WER"        clean_wer                1  "CrashDumps + WER ReportArchive"
:: call :module  "Thumbnail cache"                    clean_thumbcache         0  "%LOCALAPPDATA%\Microsoft\Windows\Explorer"
:: call :module  "Prefetch files"                     clean_prefetch           1  "C:\Windows\Prefetch\*.pf"
:: call :module  "pip package cache"                  clean_pip_cache          0  "%LOCALAPPDATA%\pip\cache"
:: call :module  "npm package cache"                  clean_npm_cache          0  "%LOCALAPPDATA%\npm-cache"

:: ---------- Add more modules here ----------
:: call :module  "Your cleanup item"  your_function_name  1_or_0  "Description"

echo ============================================================
echo.

if !DRY_RUN!==1 (
    echo   [DRY-RUN] Scan complete. Total that COULD be freed: !TOTAL_SCAN! MB
    echo   [DRY-RUN] No files were actually deleted.
) else (
    echo   Cleanup finished! Total space freed: !TOTAL_FREED! MB
)

echo.

if !ADMIN!==0 (
    echo [Tip] Run as Administrator to unlock all cleanup features
)

echo.
pause
exit /b


:: ============================================================
::  Module dispatcher - scan first, confirm, then clean
::  %1 = Display name  %2 = Function  %3 = Admin required  %4 = Path description
:: ============================================================
:module
set "MOD_NAME=%~1"
set "MOD_FUNC=%~2"
set "MOD_ADMIN=%~3"
set "MOD_DESC=%~4"

:: Admin required but not admin -> skip
if !MOD_ADMIN!==1 if !ADMIN!==0 (
    echo   [SKIP] !MOD_NAME! - requires Administrator
    goto :eof
)

:: ---- Step 1: Scan size (dryrun=1) ----
call :!MOD_FUNC! size_mb 1
if !size_mb! lss 0 (
    echo   [!] !MOD_NAME! - scan failed, skipped
    goto :eof
)

:: ---- Dry-run mode: scan only, no deletion ----
if !DRY_RUN!==1 (
    set /a TOTAL_SCAN+=!size_mb!
    if !size_mb! gtr 0 (
        echo   [SCAN] !MOD_NAME! - !size_mb! MB
    ) else (
        echo   [SCAN] !MOD_NAME! - nothing to clean
    )
    goto :eof
)

:: ---- Show size, confirm ----
echo.
echo   +-- !MOD_NAME!
echo   ^|  Location: !MOD_DESC!
if !size_mb! gtr 0 (
    echo   ^|  Size: !size_mb! MB
) else if !size_mb!==0 (
    echo   ^|  Status: nothing to clean
    echo   +-- [SKIP] !MOD_NAME!
    goto :eof
)

choice /c ynq /n /m "  +-- [Y]Clean  [N]Skip  [Q]Quit: "
set "USER_CHOICE=!errorlevel!"

if !USER_CHOICE!==1 (
    :: Y - execute cleanup
) else if !USER_CHOICE!==2 (
    :: N - skip
    echo   [SKIP] !MOD_NAME! - canceled by user
    goto :eof
) else (
    :: Q - quit
    echo.
    echo   User quit. Total freed so far: !TOTAL_FREED! MB
    echo.
    pause
    exit /b
)

:: ---- Step 2: Execute cleanup (dryrun=0) ----
call :!MOD_FUNC! freed 0
if !freed! gtr 0 (
    set /a TOTAL_FREED+=!freed!
    echo   [OK] !MOD_NAME! - freed !freed! MB
) else if !freed!==0 (
    echo   [OK] !MOD_NAME! - nothing to clean
) else (
    echo   [!] !MOD_NAME! - cleanup failed
)
goto :eof


:: ============================================================
::  Helper - Locale-independent folder/file size calculation
::  Uses PowerShell, works on all Windows locales
::  Usage: call :get_size  <path>  <return_var>
:: ============================================================
:get_size
set "target=%~1"
if not exist "!target!" (
    set "%~2=0"
    goto :eof
)
set "size_str=0"
for /f "delims=" %%a in ('powershell -NoProfile -Command ^
    "$p='!target!'; if (Test-Path $p -PathType Container) {" ^
    "  $s=(Get-ChildItem -Path $p -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum;" ^
    "  if ($s) {[math]::Round($s/1048576)} else {0}" ^
    "} else {" ^
    "  $s=(Get-Item -Path $p -ErrorAction SilentlyContinue).Length;" ^
    "  if ($s) {[math]::Round($s/1048576)} else {0}" ^
    "}" 2^>nul') do set "size_str=%%a"
for /f "tokens=1 delims= " %%b in ("!size_str!") do set "size_str=%%b"
if "!size_str!"=="" set "size_str=0"
set /a "mb=!size_str!" 2>nul
if errorlevel 1 set /a "mb=0"
set "%~2=!mb!"
goto :eof


:: ============================================================
::  Cleanup functions
::  Signature: :func_name  <return_var>  <dryrun>
::    dryrun=1: measure only, no deletion
::    dryrun=0: delete and return freed MB
::  Return: set "%~1=MB" (0=nothing to clean, -1=failed)
:: ============================================================

:: ======== NVIDIA DXCache ========
:clean_nvidia_dxcache
set "target=%LOCALAPPDATA%\NVIDIA\DXCache"
call :get_size "%target%" size_before
if "%~2"=="1" (set "%~1=!size_before!" & goto :eof)
if !size_before! gtr 0 (rmdir /s /q "%target%" 2>nul & mkdir "%target%" 2>nul)
set "%~1=!size_before!"
goto :eof


:: ======== NVIDIA GLCache ========
:clean_nvidia_glcache
set "target=%LOCALAPPDATA%\NVIDIA\GLCache"
call :get_size "%target%" size_before
if "%~2"=="1" (set "%~1=!size_before!" & goto :eof)
if !size_before! gtr 0 (rmdir /s /q "%target%" 2>nul & mkdir "%target%" 2>nul)
set "%~1=!size_before!"
goto :eof


:: ======== Hibernation file ========
:clean_hiberfil
set "target=C:\hiberfil.sys"
if exist "%target%" (
    for %%A in ("%target%") do set /a "size_before=%%~zA / 1048576"
) else (
    set "size_before=0"
)
if "%~2"=="1" (set "%~1=!size_before!" & goto :eof)
if !size_before! gtr 0 (
    powercfg -h off >nul 2>&1
    if not exist "%target%" (set "%~1=!size_before!") else (set "%~1=-1")
) else (
    set "%~1=0"
)
goto :eof


:: ======== Windows Temp files ========
:clean_temp
set "size_before=0"
call :get_size "%TEMP%" s1
call :get_size "C:\Windows\Temp" s2
set /a size_before=!s1!+!s2!
if "%~2"=="1" (set "%~1=!size_before!" & goto :eof)
if !size_before! gtr 0 (
    del /f /s /q "%TEMP%\*" 2>nul
    del /f /s /q "C:\Windows\Temp\*" 2>nul
)
set "%~1=!size_before!"
goto :eof


:: ======== Recycle Bin ========
:clean_recycle
set "size_before=0"
for %%d in (C D E F G H) do (
    call :get_size "%%d:\$Recycle.Bin" rb
    set /a size_before+=!rb!
)
if "%~2"=="1" (set "%~1=!size_before!" & goto :eof)
if !size_before! gtr 0 (
    for %%d in (C D E F G H) do rd /s /q "%%d:\$Recycle.Bin" 2>nul
)
set "%~1=!size_before!"
goto :eof


:: ======== Browser cache (Chrome + Edge) ========
:: Fixed: Cache (not Cache\Cache_Data)
:clean_browser_cache
set "size_before=0"
call :get_size "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache" c1
call :get_size "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Cache" c2
set /a size_before=!c1!+!c2!
if "%~2"=="1" (set "%~1=!size_before!" & goto :eof)
if !size_before! gtr 0 (
    rmdir /s /q "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache" 2>nul
    rmdir /s /q "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Cache" 2>nul
)
set "%~1=!size_before!"
goto :eof


:: ======== Windows Update download cache ========
:clean_windows_update
set "target=C:\Windows\SoftwareDistribution\Download"
call :get_size "%target%" size_before
if "%~2"=="1" (set "%~1=!size_before!" & goto :eof)
if !size_before! gtr 0 (
    net stop wuauserv >nul 2>&1
    del /f /s /q "%target%\*" 2>nul
    net start wuauserv >nul 2>&1
)
set "%~1=!size_before!"
goto :eof


:: ======== Windows Delivery Optimization ========
:clean_delivery_opt
set "target=C:\Windows\SoftwareDistribution\DeliveryOptimization"
call :get_size "%target%" size_before
if "%~2"=="1" (set "%~1=!size_before!" & goto :eof)
if !size_before! gtr 0 (
    del /f /s /q "%target%\*" 2>nul
)
set "%~1=!size_before!"
goto :eof


:: ======== Windows Error Reports ========
:clean_wer
set "size_before=0"
call :get_size "%LOCALAPPDATA%\CrashDumps" s1
call :get_size "C:\ProgramData\Microsoft\Windows\WER\ReportArchive" s2
call :get_size "C:\ProgramData\Microsoft\Windows\WER\ReportQueue" s3
set /a size_before=!s1!+!s2!+!s3!
if "%~2"=="1" (set "%~1=!size_before!" & goto :eof)
if !size_before! gtr 0 (
    del /f /s /q "%LOCALAPPDATA%\CrashDumps\*" 2>nul
    del /f /s /q "C:\ProgramData\Microsoft\Windows\WER\ReportArchive\*" 2>nul
    del /f /s /q "C:\ProgramData\Microsoft\Windows\WER\ReportQueue\*" 2>nul
)
set "%~1=!size_before!"
goto :eof


:: ======== Thumbnail cache ========
:clean_thumbcache
set "target=%LOCALAPPDATA%\Microsoft\Windows\Explorer"
call :get_size "%target%" size_before
if "%~2"=="1" (set "%~1=!size_before!" & goto :eof)
if !size_before! gtr 0 (
    del /f /s /q "%target%\thumbcache_*.db" 2>nul
    del /f /s /q "%target%\iconcache_*.db" 2>nul
)
set "%~1=!size_before!"
goto :eof


:: ======== Prefetch files ========
:clean_prefetch
set "target=C:\Windows\Prefetch"
call :get_size "%target%" size_before
if "%~2"=="1" (set "%~1=!size_before!" & goto :eof)
if !size_before! gtr 0 (
    del /f /s /q "%target%\*.pf" 2>nul
)
set "%~1=!size_before!"
goto :eof


:: ======== pip package cache ========
:clean_pip_cache
set "target=%LOCALAPPDATA%\pip\cache"
call :get_size "%target%" size_before
if "%~2"=="1" (set "%~1=!size_before!" & goto :eof)
if !size_before! gtr 0 (rmdir /s /q "%target%" 2>nul)
set "%~1=!size_before!"
goto :eof


:: ======== npm package cache ========
:clean_npm_cache
set "target=%LOCALAPPDATA%\npm-cache"
call :get_size "%target%" size_before
if "%~2"=="1" (set "%~1=!size_before!" & goto :eof)
if !size_before! gtr 0 (rmdir /s /q "%target%" 2>nul)
set "%~1=!size_before!"
goto :eof
