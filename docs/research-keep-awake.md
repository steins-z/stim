# Keep-Awake 产品调研

## 1. caffeinate (macOS 内建命令行工具)

### 产品形态
- **纯命令行工具**，无 GUI，macOS 自带（路径 `/usr/bin/caffeinate`）
- 没有菜单栏图标、没有偏好设置界面

### 用法
```bash
caffeinate                    # 无限期阻止系统睡眠
caffeinate -d                 # 阻止显示器睡眠
caffeinate -i                 # 阻止系统空闲睡眠
caffeinate -s                 # 阻止系统睡眠（仅接电源时有效）
caffeinate -u                 # 模拟用户活动（阻止显示器变暗）
caffeinate -t 3600            # 持续 3600 秒
caffeinate -w <PID>           # 跟随指定进程，进程退出则恢复
caffeinate -- <command>       # 运行命令期间阻止睡眠
```
- 可以组合 flag：`caffeinate -dims -t 7200`

### 技术实现
- 底层调用 **IOKit 的 Power Assertions API**（`IOPMAssertionCreateWithName`）
- 主要的 assertion 类型：
  - `kIOPMAssertionTypePreventUserIdleSystemSleep` → `-i`
  - `kIOPMAssertionTypePreventUserIdleDisplaySleep` → `-d`
  - `kIOPMAssertionTypePreventSystemSleep` → `-s`
  - `kIOPMAssertionTypeNoDisplaySleep` + user activity → `-u`
- 进程退出时 assertion 自动释放，系统恢复正常睡眠策略
- 本质是一个轻量 wrapper，核心就几个系统调用

---

## 2. Amphetamine (App Store 免费应用)

### 产品形态
- **菜单栏应用**（Menu Bar App），无 Dock 图标
- 免费、无广告、无内购、无追踪
- 开发者：William Gustafson
- 支持 macOS 10.11+，当前版本 5.3.x
- 有配套的 **Amphetamine Enhancer**（GitHub 上的辅助工具，绕过沙箱限制扩展功能）

### 用法

**手动 Session（点击开启）：**
- 无限期保持唤醒
- 指定时长（分钟/小时）
- 指定截止时间
- 文件下载期间保持
- 指定 App 运行期间保持

**Session 期间可控制：**
- 允许/阻止显示器睡眠
- 允许/阻止屏保
- 合盖不睡眠（Closed-Display Mode）
- 自动移动鼠标光标
- 阻止锁屏

**自动 Trigger（条件触发）：**
- 外接显示器连接时
- 镜像显示时
- USB/蓝牙设备连接时
- 指定 App 运行时 / 前台运行时
- 电池充电中 / 电量高于阈值
- 电源适配器连接/断开时
- 特定 IP 地址时
- 特定 Wi-Fi 网络时
- Cisco AnyConnect VPN 连接时
- 特定 DNS 服务器时
- 耳机/音频输出使用时
- 特定磁盘/卷挂载时
- CPU 使用率超过阈值时
- 空闲超过指定时间时

**其他功能：**
- 空闲后自动锁屏
- 定期移动鼠标（防止被检测为 AFK）
- Drive Alive（保持磁盘活跃）
- AppleScript 支持
- 自定义菜单栏图标和通知音
- 快捷键支持
- 低电量自动结束 session
- Power Protect（Apple Silicon 合盖模式电源切换修复）

### 技术实现
- 同样基于 **IOKit Power Assertions API**，这是所有 macOS keep-awake 方案的底层
- 作为 App Store 应用，运行在 **App Sandbox** 中，部分功能受限
  - 无法监控后台 daemon 进程 → 通过 Amphetamine Enhancer（非沙箱辅助工具）扩展
  - Closed-Display Mode 在 Apple Silicon 上需要额外脚本 + 管理员认证
- Trigger 系统通过监听系统事件实现：
  - 网络变化 → Core WLAN / SystemConfiguration framework
  - USB/蓝牙设备 → IOKit device notifications
  - 电池状态 → IOPowerSources
  - 进程监控 → NSWorkspace notifications
  - CPU 使用率 → host_processor_info / sysctl
- 菜单栏 UI → NSStatusItem + NSMenu
- AppleScript 支持 → Scripting Bridge / NSAppleScript

---

## 对比总结

| 维度 | caffeinate | Amphetamine |
|------|-----------|-------------|
| 形态 | CLI 工具 | 菜单栏 GUI |
| 价格 | 系统内建 | 免费 |
| 手动控制 | flag + 时间/PID | 点击 + 多种模式 |
| 自动触发 | 无（仅 -w 跟进程） | 20+ 种条件 Trigger |
| 显示器控制 | 有（-d flag） | 有 + 更细粒度 |
| 合盖模式 | 不支持 | 支持（需辅助脚本） |
| 鼠标移动 | 不支持 | 支持 |
| 锁屏控制 | 不支持 | 支持 |
| AppleScript | 不支持 | 支持 |
| 底层技术 | IOKit Power Assertions | IOKit Power Assertions + 系统事件监听 |
