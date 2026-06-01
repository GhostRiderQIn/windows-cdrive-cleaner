@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: ============================================================
::  Windows 系统清理工具 - Windows System Cleanup Tool
::  以管理员权限运行可解锁全部功能
::  模块化设计，方便扩展新的清理项
:: ============================================================

title Windows 系统清理工具

:: ---- 权限检查 ----
net session >nul 2>&1
if errorlevel 1 (
    echo [警告] 未以管理员身份运行，部分功能不可用
    echo ----------------------------------------------------
    set ADMIN=0
) else (
    set ADMIN=1
)

:: ---- 初始化统计 ----
set TOTAL_FREED=0

:: ============================================================
::  模块注册表 - 添加新清理模块只需在下面加一行 call
::  格式: call :module  "显示名称"  "函数名"  "需要管理员? (1/0)"  "说明文本"
:: ============================================================
goto :main

:main
echo.
echo   ╔══════════════════════════════════════════════╗
echo   ║       Windows 系统清理工具  v1.1           ║
echo   ║       节省你的 C 盘空间                     ║
echo   ╚══════════════════════════════════════════════╝
echo.
echo   正在扫描可清理项目...
echo ============================================================

:: ---------- 调用所有清理模块 ----------
call :module  "NVIDIA 着色器缓存 (DXCache)"     clean_nvidia_dxcache     0  "%LOCALAPPDATA%\NVIDIA\DXCache"
call :module  "NVIDIA 着色器缓存 (GLCache)"     clean_nvidia_glcache     0  "%LOCALAPPDATA%\NVIDIA\GLCache"
call :module  "休眠文件 (hiberfil.sys)"          clean_hiberfil           1  "C:\hiberfil.sys (关闭休眠功能)"
call :module  "Windows 临时文件"                 clean_temp               0  "%TEMP% 及 C:\Windows\Temp"
call :module  "回收站"                           clean_recycle            0  "各盘符 \$Recycle.Bin"
call :module  "浏览器缓存 (Chrome/Edge)"         clean_browser_cache      0  "Chrome + Edge 缓存目录"
call :module  "Windows Update 下载缓存"          clean_windows_update     1  "C:\Windows\SoftwareDistribution\Download"
call :module  "Windows 传递优化文件"             clean_delivery_opt       1  "C:\Windows\SoftwareDistribution\DeliveryOptimization"
call :module  "Windows 错误报告 (WER)"           clean_wer                1  "CrashDumps + WER 报告存档"
call :module  "缩略图缓存 (thumbcache)"          clean_thumbcache         0  "Windows 缩略图及图标缓存"
call :module  "Prefetch 预读取文件"              clean_prefetch           1  "C:\Windows\Prefetch\*.pf"
call :module  "pip 包缓存"                       clean_pip_cache          0  "%LOCALAPPDATA%\pip\cache"
call :module  "npm 包缓存"                       clean_npm_cache          0  "%LOCALAPPDATA%\npm-cache"

:: ---------- 此处添加更多模块 ----------
:: call :module  "你的新清理项"  your_function_name  1_or_0  "描述文本"

echo ============================================================
echo.
echo   清理完毕！总共释放了 !TOTAL_FREED! MB 空间
echo.

:: 提示管理员权限
if !ADMIN!==0 (
    echo [提示] 右键以管理员身份运行此脚本可解锁全部功能
)

echo.
pause
exit /b


:: ============================================================
::  模块调度器 - 两步式：先扫描大小 → 用户确认 → 再执行清理
::  %1 = 显示名称  %2 = 函数名  %3 = 管理员要求  %4 = 路径说明
:: ============================================================
:module
set "MOD_NAME=%~1"
set "MOD_FUNC=%~2"
set "MOD_ADMIN=%~3"
set "MOD_DESC=%~4"

:: 需要管理员但没管理员 → 跳过
if !MOD_ADMIN!==1 if !ADMIN!==0 (
    echo   [跳过] !MOD_NAME! ^(需要管理员权限^)
    goto :eof
)

:: ---- 第一步: 扫描大小 (dryrun=1) ----
call :!MOD_FUNC! size_mb 1
if !size_mb! lss 0 (
    echo   [!] !MOD_NAME! = 扫描失败，跳过
    goto :eof
)

:: ---- 显示大小，用户确认 ----
echo.
echo   ┌─ !MOD_NAME!
echo   │  位置: !MOD_DESC!
if !size_mb! gtr 0 (
    echo   │  预计释放: !size_mb! MB
    set "SIZE_DISPLAY=!size_mb! MB"
) else if !size_mb!==0 (
    echo   │  状态: 无需清理
    choice /c nq /n /m "  └─ [N]跳过  [Q]退出: "
    set "USER_CHOICE=!errorlevel!"
    if !USER_CHOICE!==2 (
        echo.
        echo   用户退出脚本。已释放 !TOTAL_FREED! MB 空间
        echo.
        pause
        exit /b
    )
    echo   [跳过] !MOD_NAME! - 无需清理
    goto :eof
)

choice /c ynq /n /m "  └─ [Y]清理  [N]跳过  [Q]退出: "
set "USER_CHOICE=!errorlevel!"

if !USER_CHOICE!==1 (
    :: Y - 执行清理
) else if !USER_CHOICE!==2 (
    :: N - 跳过
    echo   [跳过] !MOD_NAME! - 用户取消
    goto :eof
) else (
    :: Q - 退出
    echo.
    echo   用户退出脚本。已释放 !TOTAL_FREED! MB 空间
    echo.
    pause
    exit /b
)

:: ---- 第二步: 执行清理 (dryrun=0) ----
call :!MOD_FUNC! freed 0
if !freed! gtr 0 (
    set /a TOTAL_FREED+=!freed!
    echo   [√] !MOD_NAME! = 释放了 !freed! MB
) else if !freed!==0 (
    echo   [√] !MOD_NAME! = 已处理，无额外释放
) else (
    echo   [!] !MOD_NAME! = 清理失败
)
goto :eof


:: ============================================================
::  清理模块区 - 每个函数支持两种模式
::  签名: :func_name  <return_var>  <dryrun>
::    dryrun=1: 仅计算大小，不删除
::    dryrun=0: 执行删除，返回释放的 MB 数
::  约定: set "%~1=MB数"  (0=无需清理, -1=失败)
:: ============================================================

:: ---------- 文件夹大小计算 ----------
:get_folder_size_mb  <path> <return_var>
set "fp=%~1"
set "size=0"
if not exist "!fp!" (
    set "%~2=0"
    goto :eof
)
for /f "tokens=3" %%a in ('dir "!fp!" /s /a-d 2^>nul ^| findstr "个文件"') do (
    set "size=%%a"
    set "size=!size:,=!"
)
if "!size!"=="" set "size=0"
set /a "mb=!size! / 1048576"
set "%~2=!mb!"
goto :eof


:: ======== NVIDIA DXCache ========
:clean_nvidia_dxcache
set "dxcache=%LOCALAPPDATA%\NVIDIA\DXCache"
call :get_folder_size_mb "!dxcache!" size_before
if "%~2"=="1" (
    set "%~1=!size_before!"
    goto :eof
)
if !size_before! gtr 0 (
    rmdir /s /q "!dxcache!" 2>nul
    mkdir "!dxcache!" 2>nul
)
set "%~1=!size_before!"
goto :eof


:: ======== NVIDIA GLCache ========
:clean_nvidia_glcache
set "glcache=%LOCALAPPDATA%\NVIDIA\GLCache"
call :get_folder_size_mb "!glcache!" size_before
if "%~2"=="1" (
    set "%~1=!size_before!"
    goto :eof
)
if !size_before! gtr 0 (
    rmdir /s /q "!glcache!" 2>nul
    mkdir "!glcache!" 2>nul
)
set "%~1=!size_before!"
goto :eof


:: ======== 休眠文件 ========
:clean_hiberfil
set "hiberfile=C:\hiberfil.sys"
set "size_before=0"
if exist "!hiberfile!" (
    for %%A in ("!hiberfile!") do set /a "size_before=%%~zA / 1048576"
)
if "%~2"=="1" (
    set "%~1=!size_before!"
    goto :eof
)
if !size_before! gtr 0 (
    powercfg -h off >nul 2>&1
    if not exist "!hiberfile!" (
        set "%~1=!size_before!"
    ) else (
        set "%~1=-1"
    )
) else (
    set "%~1=0"
)
goto :eof


:: ======== Windows 临时文件 ========
:clean_temp
set "size_before=0"
call :get_folder_size_mb "%TEMP%" ut
call :get_folder_size_mb "C:\Windows\Temp" st
set /a size_before=!ut!+!st!
if "%~2"=="1" (
    set "%~1=!size_before!"
    goto :eof
)
if !size_before! gtr 0 (
    del /f /s /q "%TEMP%\*" 2>nul
    del /f /s /q "C:\Windows\Temp\*" 2>nul
)
set "%~1=!size_before!"
goto :eof


:: ======== 回收站 ========
:clean_recycle
set "size_before=0"
for %%d in (C D E F G H) do (
    if exist "%%d:\$Recycle.Bin" (
        call :get_folder_size_mb "%%d:\$Recycle.Bin" rb
        set /a size_before+=!rb!
    )
)
if "%~2"=="1" (
    set "%~1=!size_before!"
    goto :eof
)
if !size_before! gtr 0 (
    rd /s /q "C:\$Recycle.Bin" 2>nul
    rd /s /q "D:\$Recycle.Bin" 2>nul
    rd /s /q "E:\$Recycle.Bin" 2>nul
)
set "%~1=!size_before!"
goto :eof


:: ======== 浏览器缓存 ========
:clean_browser_cache
set "size_before=0"
call :get_folder_size_mb "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache\Cache_Data" c1
call :get_folder_size_mb "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Cache\Cache_Data" c2
set /a size_before=!c1!+!c2!
if "%~2"=="1" (
    set "%~1=!size_before!"
    goto :eof
)
if !size_before! gtr 0 (
    rmdir /s /q "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache\Cache_Data" 2>nul
    rmdir /s /q "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Cache\Cache_Data" 2>nul
)
set "%~1=!size_before!"
goto :eof


:: ======== Windows Update 下载缓存 ========
:clean_windows_update
set "wu=C:\Windows\SoftwareDistribution\Download"
call :get_folder_size_mb "!wu!" size_before
if "%~2"=="1" (
    set "%~1=!size_before!"
    goto :eof
)
if !size_before! gtr 0 (
    net stop wuauserv >nul 2>&1
    del /f /s /q "!wu!\*" 2>nul
    net start wuauserv >nul 2>&1
)
set "%~1=!size_before!"
goto :eof


:: ======== Windows 传递优化文件 ========
:clean_delivery_opt
set "dopt=C:\Windows\SoftwareDistribution\DeliveryOptimization"
call :get_folder_size_mb "!dopt!" size_before
if "%~2"=="1" (
    set "%~1=!size_before!"
    goto :eof
)
if !size_before! gtr 0 (
    del /f /s /q "!dopt!\*" 2>nul
)
set "%~1=!size_before!"
goto :eof


:: ======== Windows 错误报告 ========
:clean_wer
set "size_before=0"
call :get_folder_size_mb "%LOCALAPPDATA%\CrashDumps" w1
call :get_folder_size_mb "C:\ProgramData\Microsoft\Windows\WER\ReportArchive" w2
call :get_folder_size_mb "C:\ProgramData\Microsoft\Windows\WER\ReportQueue" w3
set /a size_before=!w1!+!w2!+!w3!
if "%~2"=="1" (
    set "%~1=!size_before!"
    goto :eof
)
if !size_before! gtr 0 (
    del /f /s /q "%LOCALAPPDATA%\CrashDumps\*" 2>nul
    del /f /s /q "C:\ProgramData\Microsoft\Windows\WER\ReportArchive\*" 2>nul
    del /f /s /q "C:\ProgramData\Microsoft\Windows\WER\ReportQueue\*" 2>nul
)
set "%~1=!size_before!"
goto :eof


:: ======== 缩略图缓存 ========
:clean_thumbcache
set "size_before=0"
call :get_folder_size_mb "%LOCALAPPDATA%\Microsoft\Windows\Explorer" thumb
if "%~2"=="1" (
    set "%~1=!thumb!"
    goto :eof
)
if !thumb! gtr 0 (
    del /f /s /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\thumbcache_*.db" 2>nul
    del /f /s /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db" 2>nul
    set "size_before=!thumb!"
)
set "%~1=!size_before!"
goto :eof


:: ======== Prefetch 预读取文件 ========
:clean_prefetch
set "pf=C:\Windows\Prefetch"
call :get_folder_size_mb "!pf!" size_before
if "%~2"=="1" (
    set "%~1=!size_before!"
    goto :eof
)
if !size_before! gtr 0 (
    del /f /s /q "!pf!\*.pf" 2>nul
)
set "%~1=!size_before!"
goto :eof


:: ======== pip 包缓存 ========
:clean_pip_cache
set "pc=%LOCALAPPDATA%\pip\cache"
call :get_folder_size_mb "!pc!" size_before
if "%~2"=="1" (
    set "%~1=!size_before!"
    goto :eof
)
if !size_before! gtr 0 (
    rmdir /s /q "!pc!" 2>nul
)
set "%~1=!size_before!"
goto :eof


:: ======== npm 包缓存 ========
:clean_npm_cache
set "nc=%LOCALAPPDATA%\npm-cache"
call :get_folder_size_mb "!nc!" size_before
if "%~2"=="1" (
    set "%~1=!size_before!"
    goto :eof
)
if !size_before! gtr 0 (
    rmdir /s /q "!nc!" 2>nul
)
set "%~1=!size_before!"
goto :eof
