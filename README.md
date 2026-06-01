# Windows 系统清理工具

一个模块化、带交互确认的 Windows 系统清理批处理脚本，帮助你安全地释放 C 盘空间。

## 快速开始

1. **右键 → 以管理员身份运行** `cleanup.bat`（可解锁全部 13 项清理功能）
2. 每项清理前都会先**扫描大小**，然后**询问你是否执行**
3. 按 `Y` 清理，按 `N` 跳过，按 `Q` 退出

```
  ┌─ NVIDIA 着色器缓存 (DXCache)
  │  位置: C:\Users\xxx\AppData\Local\NVIDIA\DXCache
  │  预计释放: 1240 MB
  └─ [Y]清理  [N]跳过  [Q]退出:
```

## 清理项一览

| 模块 | 需要管理员 | 说明 |
|------|:---:|------|
| NVIDIA DXCache 着色器缓存 | | `%LOCALAPPDATA%\NVIDIA\DXCache` |
| NVIDIA GLCache 着色器缓存 | | `%LOCALAPPDATA%\NVIDIA\GLCache` |
| hiberfil.sys 休眠文件 | ⚡ | 关闭 Windows 休眠功能 |
| Windows 临时文件 | | `%TEMP%` 和 `C:\Windows\Temp` |
| 回收站 | | 所有盘符的 `$Recycle.Bin` |
| 浏览器缓存 (Chrome/Edge) | | Chrome + Edge 缓存目录 |
| Windows Update 下载缓存 | ⚡ | 已安装的更新包残留 |
| Windows 传递优化文件 | ⚡ | P2P 更新分发缓存 |
| Windows 错误报告 (WER) | ⚡ | 崩溃转储和错误报告 |
| 缩略图缓存 | | `thumbcache_*.db` |
| Prefetch 预读取文件 | ⚡ | `C:\Windows\Prefetch\*.pf` |
| pip 包缓存 | | `%LOCALAPPDATA%\pip\cache` |
| npm 包缓存 | | `%LOCALAPPDATA%\npm-cache` |

⚡ = 需要管理员权限

## 如何添加新的清理项

两步即可：

**1.** 在文件末尾写一个新函数：

```batch
:clean_my_feature
set "my_path=C:\Path\To\Cache"
call :get_folder_size_mb "!my_path!" size_before
if "%~2"=="1" (              :: dry-run 模式，仅计算大小
    set "%~1=!size_before!"
    goto :eof
)
if !size_before! gtr 0 (
    rmdir /s /q "!my_path!" 2>nul
)
set "%~1=!size_before!"
goto :eof
```

**2.** 在 `:main` 区域加一行注册：

```batch
call :module  "我的清理项"  clean_my_feature  1  "C:\Path\To\Cache 说明"
```

第三个参数 `1` 表示需要管理员，`0` 表示不需要。调度器会自动处理权限判断、大小扫描、用户确认和结果汇总。

## 许可证

MIT
