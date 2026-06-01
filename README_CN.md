# Windows C盘清理工具

> 模块化、交互式的 Windows C 盘空间清理批处理脚本，安全释放磁盘空间。
> **兼容中文、英文及所有 Windows 语言版本。**

## 快速开始

1. **右键 → 以管理员身份运行** `cleanup.bat`
2. 每项清理**先扫描大小**，再由你**逐项决定**是否清理
3. 按 `Y` 清理，按 `N` 跳过，按 `Q` 退出

### 仅扫描模式（不删除）

```bash
cleanup.bat --dry-run
# 或
cleanup.bat -d
```

扫描所有活跃项，告诉你**可释放多少空间**，但不会删除任何文件。

```
  +-- NVIDIA Shader Cache (DXCache)
  |  Location: C:\Users\xxx\AppData\Local\NVIDIA\DXCache
  |  Size: 1240 MB
  +-- [Y]Clean  [N]Skip  [Q]Quit:
```

## 活跃清理模块

| 模块 | 管理员 | 路径 |
|------|:---:|------|
| NVIDIA 着色器缓存 (DXCache) | | `%LOCALAPPDATA%\NVIDIA\DXCache` |
| 休眠文件 (hiberfil.sys) | ⚡ | `C:\hiberfil.sys`（关闭休眠功能） |

⚡ = 需要管理员权限

## 已注释模块（取消注释即可启用）

在 `cleanup.bat` 中去掉对应行前面的 `::` 即可启用：

| 模块 | 管理员 | 路径 |
|------|:---:|------|
| NVIDIA 着色器缓存 (GLCache) | | `%LOCALAPPDATA%\NVIDIA\GLCache` |
| Windows 临时文件 | | `%TEMP%` + `C:\Windows\Temp` |
| 回收站 | | 所有盘符 `$Recycle.Bin` |
| 浏览器缓存 (Chrome / Edge) | | Chrome + Edge 缓存目录 |
| Windows Update 下载缓存 | ⚡ | `C:\Windows\SoftwareDistribution\Download` |
| Windows 传递优化文件 | ⚡ | `C:\Windows\SoftwareDistribution\DeliveryOptimization` |
| Windows 错误报告 (WER) | ⚡ | 崩溃转储 + 错误报告存档 |
| 缩略图缓存 | | `thumbcache_*.db` + `iconcache_*.db` |
| Prefetch 预读取文件 | ⚡ | `C:\Windows\Prefetch\*.pf` |
| pip 包缓存 | | `%LOCALAPPDATA%\pip\cache` |
| npm 包缓存 | | `%LOCALAPPDATA%\npm-cache` |

## 如何添加新的清理项

**第一步：** 在文件末尾写一个新函数：

```batch
:clean_my_feature
set "target=C:\Path\To\Clean"
call :get_size "%target%" size_before
if "%~2"=="1" (                   :: 仅测量模式，不删除
    set "%~1=!size_before!"
    goto :eof
)
if !size_before! gtr 0 (
    del /f /s /q "%target%\*" 2>nul
)
set "%~1=!size_before!"
goto :eof
```

**第二步：** 在 `:main` 区域注册一行：

```batch
call :module  "我的清理项"  clean_my_feature  1  "C:\Path\To\Clean"
```

第三个参数 `1` 表示需要管理员权限（`0` 表示不需要）。调度器会自动处理权限判断、大小扫描、用户确认和结果汇总。

## 更新日志

### v2.0
- **修复：** 文件夹大小计算改用 PowerShell，兼容所有语言版本 Windows（原版仅在中文系统可用）
- **修复：** 浏览器缓存路径从错误的 `Cache\Cache_Data` 修正为 `Cache`
- **修复：** UI 改为英文，避免编码乱码
- **新增：** `--dry-run` / `-d` 仅扫描模式

### v1.1
- 两步式清理：先扫描大小，再询问确认
- 13 个清理模块，模块化架构

## 许可证

MIT
