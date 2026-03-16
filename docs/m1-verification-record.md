# M1 技术验证记录

## 验证目标

验证 macOS 上合盖不睡眠的技术可行性，重点测试 `IOConnectCallScalarMethod` + `kPMSetClamshellSleepState` 在不同环境下的表现。

## 测试环境

- Apple Silicon (arm64)
- macOS 26.3.1 (Build 25D2128)
- 日期：2026-03-16

## 验证结果

### Power Assertions（IOPMAssertionCreateWithName）

| 环境 | PreventUserIdleSystemSleep | PreventUserIdleDisplaySleep |
|------|---------------------------|----------------------------|
| 非沙箱 | ✅ 成功 | ✅ 成功 |
| 沙箱 + iokit-open | ✅ 成功 | ✅ 成功 |
| 严格沙箱 | ✅ 成功 | ✅ 成功 |

**结论：** Power Assertions 在所有环境下都可用，沙箱不影响。

### IOConnectCallScalarMethod（kPMSetClamshellSleepState）

| 环境 | IOServiceOpen | kPMSetClamshellSleepState |
|------|--------------|--------------------------|
| 非沙箱（普通用户） | ✅ 成功 | ❌ 失败 (0xe00002c2) |
| 非沙箱（root/sudo） | ✅ 成功 | ❌ 失败 (0xe00002c2) |
| 沙箱 + iokit-open | ✅ 成功 | ❌ 失败 (0xe00002c2) |
| 严格沙箱 | ❌ 失败 (0xe00002e2) | N/A |

**结论：** `kPMSetClamshellSleepState` 在 macOS 26 + Apple Silicon 上完全不可用，即使 root 也无法调用。Apple 已在新版 macOS 上收紧了此 IOKit 接口的权限。CDMManager sample（2020年）的方案已失效。

## 最终决策

采用 **Amphetamine Power Protect 同款方案**：通过 sudoers 配置 + shell 脚本调用 `sudo pmset disablesleep 1/0` 实现合盖不睡眠。此方案已被 Amphetamine 验证可通过 App Store 审核。

## 参考

- CDMManager 源码：https://github.com/x74353/CDMManager-Sample
- Amphetamine Power Protect：https://github.com/x74353/Amphetamine-Power-Protect
- Apple Silicon IOKit issue：https://github.com/x74353/IOConnectCallScalarMethod_Issue_AppleFB
