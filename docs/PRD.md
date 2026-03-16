# PRD: Stim — 极简 Keep-Awake 工具

**项目代号：** project-caffeine
**产品名称：** Stim
**状态：** ✅ PRD 已批准
**审批人：** Steins
**日期：** 2026-03-16

---

## 1. 产品定位

一句话：点一下，Mac 不睡觉。合盖也不睡。

对标 Amphetamine 但砍掉 90% 功能，只做最核心的事，做到极致优雅。

## 2. 目标平台

- macOS 13 Ventura+
- App Store 分发
- 支持 Intel + Apple Silicon

## 3. 运行方式

**菜单栏应用（Menu Bar Only）**
- 无 Dock 图标，无主窗口
- 菜单栏图标：激活态（☕ 有蒸汽/高亮）/ 休眠态（灰色/空杯）
- 使用 SwiftUI `MenuBarExtra` 原生 API

### 交互方式
- **左键点击菜单栏图标** → 直接 toggle 开/关（最快路径）
- **右键点击 / Option+点击** → 打开面板，调整选项
- 激活时菜单栏图标有视觉区分（颜色/动画）
- 到期前 5 分钟发 macOS 通知

## 4. 面板 UI

```
┌─────────────────────────┐
│  ☕ Caffeine             │
│                         │
│  ◉ 保持唤醒    [开关]    │
│                         │
│  ── 持续时间 ──          │
│  ○ 30 分钟              │
│  ○ 1 小时               │
│  ○ 2 小时               │
│  ○ 4 小时               │
│  ● 无限期               │
│                         │
│  ── 选项 ──             │
│  ☑ 合盖保持唤醒          │
│  ☑ 保持显示器亮起        │
│                         │
│  剩余: 1:23:45          │
│                         │
│  ─────────────────────  │
│  ⚙ 设置...    退出      │
└─────────────────────────┘
```

## 5. 可配置项

| 配置项 | 默认值 | 说明 |
|-------|--------|------|
| 持续时间 | 无限期 | 30m / 1h / 2h / 4h / 无限期 / 自定义 |
| 合盖保持唤醒 | ✅ 开 | 核心差异化功能 |
| 保持显示器亮起 | ❌ 关 | 关 = 只阻止系统睡眠，显示器可以暗 |
| 登录时启动 | ❌ 关 | Launch at Login（macOS 13+ SMAppService） |
| 启动时自动激活 | ❌ 关 | 打开 app 就立刻开始 session |
| 默认持续时间 | 无限期 | 每次开启时的预设时长 |
| 菜单栏图标样式 | 咖啡杯 | 2-3 种可选（咖啡杯 / 圆点 / 闪电） |
| 到期提醒 | ✅ 开 | 到期前 5 分钟通知 |
| 低电量自动关闭 | ✅ 开（20%） | 电池低于阈值自动结束 session |

## 6. 设置窗口

SwiftUI Settings scene，macOS 原生风格，单 tab：
- **通用：** 登录启动、启动时激活、默认时长、图标样式
- **高级：** 低电量阈值、到期提醒开关

## 7. 技术方案

### 核心技术栈
- **SwiftUI** + **AppKit**（NSStatusItem / MenuBarExtra）
- **Swift Package Manager**，零第三方依赖
- **App Sandbox** ✅

### 防睡眠实现
| 场景 | API | 说明 |
|------|-----|------|
| 阻止系统空闲睡眠 | `IOPMAssertionCreateWithName` → `PreventUserIdleSystemSleep` | caffeinate -i 同款，沙箱内可用 ✅ |
| 阻止显示器睡眠 | `IOPMAssertionCreateWithName` → `PreventUserIdleDisplaySleep` | caffeinate -d 同款，沙箱内可用 ✅ |
| 合盖不睡眠 | AppleScript → `sudo pmset disablesleep 1` | Amphetamine Power Protect 同款，需首次安装 helper |
| 合盖恢复 | AppleScript → `sudo pmset disablesleep 0` | session 结束 / app 退出时恢复 |

### ~~已排除方案（M1 验证结论）~~
| 方案 | 结论 | 原因 |
|------|------|------|
| `IOConnectCallScalarMethod` + `kPMSetClamshellSleepState` | ❌ 不可用 | macOS 26 + Apple Silicon 下 root 也调不通，Apple 已收紧权限 |
| `SMJobBless` privileged helper | ❌ 不采用 | 实现过重，App Store 审核无前人验证 |

### 合盖方案详细设计（Power Protect 模式）

**原理：** App Sandbox 允许应用从 `~/Library/Application Scripts/<bundle-id>/` 加载并执行脚本。通过配置 sudoers 规则让该脚本无密码调用 `pmset disablesleep`。

**需要安装的文件（一次性，需管理员权限）：**
1. `~/Library/Application Scripts/<bundle-id>/clamshellControl.sh` — shell 脚本，调用 `pmset disablesleep`
2. `/private/etc/sudoers.d/stim_clamshell` — sudoers 规则，允许当前用户无密码执行该脚本

**sudoers 规则示例：**
```
<username> ALL=(root) NOPASSWD: /Users/<username>/Library/Application Scripts/<bundle-id>/clamshellControl.sh
```

**安装流程（UX）：**
1. 用户首次开启"合盖保持唤醒"时，弹出引导弹窗
2. 说明需要一次性安装辅助脚本
3. 点击"安装"后触发 macOS 管理员认证（Touch ID / 密码）
4. 通过 `NSAppleScript` 或 `AuthorizationExecuteWithPrivileges` 写入两个文件
5. 安装完成，后续使用无感

**运行时流程：**
```
用户开启合盖 → App 调用 NSUserUnixTask 执行脚本 → 脚本 sudo pmset disablesleep 1
用户关闭合盖/退出 → 同上 → sudo pmset disablesleep 0
电源事件（充电器插拔） → 监听 IOPowerSources → 重新执行脚本（防 Apple Silicon 掉线）
```

### 关键文件结构（更新）
```
Stim/
├── StimApp.swift              # App 入口，MenuBarExtra
├── Core/
│   ├── PowerManager.swift     # IOKit Power Assertions 封装
│   ├── ClamshellManager.swift # 合盖控制（Power Protect 模式）
│   └── SessionManager.swift   # 计时 session 管理
├── UI/
│   ├── MenuBarView.swift      # 面板 UI
│   ├── SettingsView.swift     # 设置窗口
│   └── SetupGuideView.swift   # 合盖功能首次安装引导
├── Resources/
│   ├── clamshellControl.sh    # 合盖控制脚本（安装到 Application Scripts）
│   └── Assets.xcassets/       # 图标资源
└── Info.plist
```

## 8. ⚠️ 风险点

1. ~~**App Sandbox 下 `IOConnectCallScalarMethod` 是否可用？**~~ → **M1 已验证：不可用。已切换到 Power Protect 方案。**

2. **App 名称**
   - ~~"Caffeine" 可能在 App Store 已被占用~~ → 已定名 **Stim**
   - 需要在 App Store Connect 验证 "Stim" 可用性

3. **App Store 审核**
   - Amphetamine 品类已验证，审核风险低
   - Power Protect 模式（sudoers + 外部脚本）Amphetamine 已过审
   - 注意避免在描述中使用违规词汇

4. **Apple Silicon 电源切换问题**
   - Apple Silicon MacBook 在合盖模式下插拔充电器会导致系统短暂睡眠
   - 需要监听电源事件并重新执行 `pmset disablesleep 1`
   - Amphetamine 的 Power Protect 已解决此问题，可参考

## 9. 里程碑

- **M1：** ✅ 技术验证（IOKit 合盖方案不可用，确认 Power Protect 路线）
- **M2：** 核心功能（toggle + 计时 + 合盖 Power Protect）
- **M3：** UI 打磨（面板 + 设置 + 图标 + 安装引导）
- **M4：** App Store 提审

## 10. 参考资料

- Amphetamine CDMManager 源码：<https://github.com/x74353/CDMManager-Sample>
- Phil Dennis-Jordan 的 StackOverflow 方案：<https://stackoverflow.com/questions/59594123>
- Amphetamine Power Protect：<https://github.com/x74353/Amphetamine-Power-Protect>
- Apple Silicon IOKit issue：<https://github.com/x74353/IOConnectCallScalarMethod_Issue_AppleFB>
- 调研文档：`memory/channel-1482954071223701585/research-keep-awake.md`
