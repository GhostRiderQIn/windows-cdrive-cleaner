@echo off
setlocal enabledelayedexpansion
title Windows System Cleanup Tool

:: ============================================================
::  Permission check
:: ============================================================
net session >nul 2>&1
if errorlevel 1 (
    echo [Warning] Not running as Administrator - some features disabled
    echo ----------------------------------------------------
    set ADMIN=0
) else (
    set ADMIN=1
)

:: ============================================================
::  Dry-run mode
:: ============================================================
set DRY_RUN=0
if /i "%~1"=="--dry-run" set DRY_RUN=1
if /i "%~1"=="-d"        set DRY_RUN=1

set TOTAL_FREED=0
set TOTAL_SCAN=0

goto :main

:: ============================================================
::  MAIN
:: ============================================================
:main
echo.
echo   ===============================================
echo     Windows System Cleanup Tool v2.0
echo     Free up your C drive space safely
if !DRY_RUN!==1 echo     *** DRY-RUN MODE - scan only ***
echo   ===============================================
echo.

if !DRY_RUN!==1 (
    echo   Dry-run mode: scanning only, no files will be deleted.
) else (
    echo   Scanning for cleanup targets...
)
echo ============================================================

:: ---- Active modules ----
call :module  "NVIDIA Shader Cache - DXCache"      clean_nvidia_dxcache     0  "%LOCALAPPDATA%\NVIDIA\DXCache"
call :module  "Hibernation file - hiberfil.sys"    clean_hiberfil           1  "C:\hiberfil.sys - disables hibernation"

:: ---- Inactive modules (uncomment to enable) ----
rem call :module  "NVIDIA Shader Cache - GLCache"      clean_nvidia_glcache     0  "%LOCALAPPDATA%\NVIDIA\GLCache"
rem call :module  "Windows Temp files"                 clean_temp               0  "%%TEMP%% + C:\Windows\Temp"
rem call :module  "Recycle Bin"                        clean_recycle            0  "All drives \$Recycle.Bin"
rem call :module  "Browser cache - Chrome / Edge"      clean_browser_cache      0  "Chrome + Edge Cache"
rem call :module  "Windows Update download cache"      clean_windows_update     1  "C:\Windows\SoftwareDistribution\Download"
rem call :module  "Windows Delivery Optimization"      clean_delivery_opt       1  "C:\Windows\SoftwareDistribution\DeliveryOptimization"
rem call :module  "Windows Error Reports - WER"        clean_wer                1  "CrashDumps + WER ReportArchive"
rem call :module  "Thumbnail cache"                    clean_thumbcache         0  "%LOCALAPPDATA%\Microsoft\Windows\Explorer"
rem call :module  "Prefetch files"                     clean_prefetch           1  "C:\Windows\Prefetch\*.pf"
rem call :module  "pip package cache"                  clean_pip_cache          0  "%LOCALAPPDATA%\pip\cache"
rem call :module  "npm package cache"                  clean_npm_cache          0  "%LOCALAPPDATA%\npm-cache"

echo ============================================================
echo.

if !DRY_RUN!==1 (
    echo   [DRY-RUN] Scan complete. Could free: !TOTAL_SCAN! MB
    echo   [DRY-RUN] No files were actually deleted.
) else (
    echo   Cleanup finished! Total space freed: !TOTAL_FREED! MB
)

echo.
if !ADMIN!==0 echo [Tip] Run as Administrator to unlock all cleanup features
echo.
pause
exit /b


:: ============================================================
::  Module dispatcher
:: ============================================================
:module
set "MOD_NAME=%~1"
set "MOD_FUNC=%~2"
set "MOD_ADMIN=%~3"
set "MOD_DESC=%~4"

if !MOD_ADMIN!==1 if !ADMIN!==0 (
    echo   [SKIP] !MOD_NAME! - requires Administrator
    goto :eof
)

rem Step 1: scan size
call :!MOD_FUNC! size_mb 1
if !size_mb! lss 0 (
    echo   [!] !MOD_NAME! - scan failed, skipped
    goto :eof
)

rem Dry-run: show and skip
if !DRY_RUN!==1 (
    set /a TOTAL_SCAN+=!size_mb!
    if !size_mb! gtr 0 (echo   [SCAN] !MOD_NAME! - !size_mb! MB) else (echo   [SCAN] !MOD_NAME! - nothing to clean)
    goto :eof
)

rem Show size, ask user
echo.
echo   --- !MOD_NAME!
echo       Location: !MOD_DESC!
if !size_mb! gtr 0 (
    echo       Size: !size_mb! MB
) else if !size_mb!==0 (
    echo       Status: nothing to clean
    echo   --- [SKIP] !MOD_NAME!
    goto :eof
)

choice /c ynq /n /m "  --- [Y]Clean  [N]Skip  [Q]Quit: "
set "USER_CHOICE=!errorlevel!"

if !USER_CHOICE!==2 (
    echo   [SKIP] !MOD_NAME! - canceled by user
    goto :eof
)
if !USER_CHOICE!==3 (
    echo.
    echo   User quit. Total freed so far: !TOTAL_FREED! MB
    echo.
    pause
    exit /b
)

rem Step 2: execute cleanup (USER_CHOICE=1 falls through)
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
::  Helper - get folder/file size in MB (PowerShell, locale-independent)
::  Single-line PowerShell call, no ^ continuation, no pipe inside batch ()
:: ============================================================
:get_size
set "target=%~1"
if not exist "!target!" (
    set "%~2=0"
    goto :eof
)
set "size_str=0"
for /f %%a in ('powershell -NoProfile -Command "(Get-ChildItem -Path '!target!' -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum" 2^>nul') do set "size_str=%%a"
if "!size_str!"=="" set "size_str=0"
set /a "mb=!size_str! / 1048576" 2>nul
if errorlevel 1 set /a "mb=0"
set "%~2=!mb!"
goto :eof


:: ============================================================
::  Cleanup functions
:: ============================================================

:clean_nvidia_dxcache
set "target=%LOCALAPPDATA%\NVIDIA\DXCache"
call :get_size "%target%" size_before
if "%~2"=="1" (set "%~1=!size_before!" & goto :eof)
if !size_before! gtr 0 (rmdir /s /q "%target%" 2>nul & mkdir "%target%" 2>nul)
set "%~1=!size_before!"
goto :eof


:clean_nvidia_glcache
set "target=%LOCALAPPDATA%\NVIDIA\GLCache"
call :get_size "%target%" size_before
if "%~2"=="1" (set "%~1=!size_before!" & goto :eof)
if !size_before! gtr 0 (rmdir /s /q "%target%" 2>nul & mkdir "%target%" 2>nul)
set "%~1=!size_before!"
goto :eof


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


:clean_browser_cache
set "size_before=0"
call :get_size "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache" s1
call :get_size "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Cache" s2
set /a size_before=!s1!+!s2!
if "%~2"=="1" (set "%~1=!size_before!" & goto :eof)
if !size_before! gtr 0 (
    rmdir /s /q "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache" 2>nul
    rmdir /s /q "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Cache" 2>nul
)
set "%~1=!size_before!"
goto :eof


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


:clean_delivery_opt
set "target=C:\Windows\SoftwareDistribution\DeliveryOptimization"
call :get_size "%target%" size_before
if "%~2"=="1" (set "%~1=!size_before!" & goto :eof)
if !size_before! gtr 0 (del /f /s /q "%target%\*" 2>nul)
set "%~1=!size_before!"
goto :eof


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


:clean_prefetch
set "target=C:\Windows\Prefetch"
call :get_size "%target%" size_before
if "%~2"=="1" (set "%~1=!size_before!" & goto :eof)
if !size_before! gtr 0 (del /f /s /q "%target%\*.pf" 2>nul)
set "%~1=!size_before!"
goto :eof


:clean_pip_cache
set "target=%LOCALAPPDATA%\pip\cache"
call :get_size "%target%" size_before
if "%~2"=="1" (set "%~1=!size_before!" & goto :eof)
if !size_before! gtr 0 (rmdir /s /q "%target%" 2>nul)
set "%~1=!size_before!"
goto :eof


:clean_npm_cache
set "target=%LOCALAPPDATA%\npm-cache"
call :get_size "%target%" size_before
if "%~2"=="1" (set "%~1=!size_before!" & goto :eof)
if !size_before! gtr 0 (rmdir /s /q "%target%" 2>nul)
set "%~1=!size_before!"
goto :eof
