# M1 技术验证 — Clamshell Sleep State

验证 App Sandbox 下 `IOConnectCallScalarMethod` + `kPMSetClamshellSleepState` 是否可用。

## 运行方法

```bash
cd m1-verify
swift build
```

### 测试 1: 非沙箱环境
```bash
swift run
```

### 测试 2: 模拟 App Sandbox (严格)
去掉 `sandbox.sb` 中的 `iokit-open` 那一行，然后：
```bash
sandbox-exec -f sandbox.sb .build/debug/ClamshellVerify
```

### 测试 3: 模拟有 IOKit 权限的沙箱
保留 `sandbox.sb` 中的 `iokit-open` 行：
```bash
sandbox-exec -f sandbox.sb .build/debug/ClamshellVerify
```

## 预期结果

| 环境 | Power Assertions | Clamshell Control |
|------|-----------------|-------------------|
| 非沙箱 | ✅ | ✅ (可能需要 root) |
| 沙箱 + iokit-open | ✅ | ⚠️ 待验证 |
| 沙箱 - iokit-open | ✅ | ❌ |

## 结果记录

_(在 Mac 上跑完后把输出贴到这里)_

```
TODO: 贴测试输出
```
