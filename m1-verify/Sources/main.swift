/// M1 技术验证 — Clamshell Sleep State (合盖不睡眠)
///
/// 测试目标：验证 App Sandbox 下能否调用 IOConnectCallScalarMethod
/// 来控制 kPMSetClamshellSleepState。
///
/// 用法:
///   cd m1-verify
///   swift build
///   swift run                          # 非沙箱测试
///   sandbox-exec -f sandbox.sb swift run   # 沙箱模拟测试
///
/// 参考: https://github.com/x74353/CDMManager-Sample

import Foundation
import IOKit
import IOKit.pwr_mgt

// MARK: - Test 1: Power Assertions (应该在沙箱内外都能工作)

func testPowerAssertions() {
    print("=" * 60)
    print("TEST 1: IOPMAssertion (Power Assertions)")
    print("=" * 60)

    var assertionID: IOPMAssertionID = 0

    // PreventUserIdleSystemSleep
    let result = IOPMAssertionCreateWithName(
        "PreventUserIdleSystemSleep" as CFString,
        IOPMAssertionLevel(kIOPMAssertionLevelOn),
        "Stim M1 verification" as CFString,
        &assertionID
    )

    if result == kIOReturnSuccess {
        print("✅ PreventUserIdleSystemSleep — 成功 (assertionID: \(assertionID))")
        IOPMAssertionRelease(assertionID)
        print("   已释放 assertion")
    } else {
        print("❌ PreventUserIdleSystemSleep — 失败 (error: 0x\(String(result, radix: 16)))")
    }

    // PreventUserIdleDisplaySleep
    var displayAssertionID: IOPMAssertionID = 0
    let displayResult = IOPMAssertionCreateWithName(
        "PreventUserIdleDisplaySleep" as CFString,
        IOPMAssertionLevel(kIOPMAssertionLevelOn),
        "Stim M1 verification - display" as CFString,
        &displayAssertionID
    )

    if displayResult == kIOReturnSuccess {
        print("✅ PreventUserIdleDisplaySleep — 成功 (assertionID: \(displayAssertionID))")
        IOPMAssertionRelease(displayAssertionID)
        print("   已释放 assertion")
    } else {
        print("❌ PreventUserIdleDisplaySleep — 失败 (error: 0x\(String(displayResult, radix: 16)))")
    }
}

// MARK: - Test 2: Clamshell Sleep State (合盖控制 — 关键测试)

func testClamshellSleepState() {
    print("")
    print("=" * 60)
    print("TEST 2: IOConnectCallScalarMethod (Clamshell Sleep State)")
    print("=" * 60)

    // Step 1: 获取 IOPMrootDomain 服务
    let rootDomainService = IOServiceGetMatchingService(
        kIOMainPortDefault,
        IOServiceMatching("IOPMrootDomain")
    )

    guard rootDomainService != IO_OBJECT_NULL else {
        print("❌ 无法获取 IOPMrootDomain 服务")
        return
    }
    print("✅ Step 1: 获取 IOPMrootDomain 服务 — 成功 (port: \(rootDomainService))")

    // Step 2: 打开 user client 连接
    var connect: io_connect_t = IO_OBJECT_NULL
    let openResult = IOServiceOpen(rootDomainService, mach_task_self_, 0, &connect)
    IOObjectRelease(rootDomainService)

    if openResult != kIOReturnSuccess {
        print("❌ Step 2: IOServiceOpen — 失败 (error: 0x\(String(openResult, radix: 16)))")
        print("")
        print("⚠️  这很可能是 App Sandbox 阻止了 IOKit user client 访问")
        print("   如果你在沙箱外运行也失败，可能需要 root 权限")
        return
    }
    print("✅ Step 2: IOServiceOpen — 成功 (connect: \(connect))")

    // Step 3: 调用 kPMSetClamshellSleepState
    // Selector 7 = kPMSetClamshellSleepState (禁用合盖睡眠)
    // Input: 1 = disable clamshell sleep, 0 = enable clamshell sleep
    let kPMSetClamshellSleepState: UInt32 = 7
    var scalarInput: [UInt64] = [1] // 1 = disable clamshell sleep

    let callResult = IOConnectCallScalarMethod(
        connect,
        kPMSetClamshellSleepState,
        &scalarInput,
        1,
        nil,
        nil
    )

    if callResult == kIOReturnSuccess {
        print("✅ Step 3: kPMSetClamshellSleepState(disable) — 成功!")
        print("")
        print("🎉 合盖不睡眠功能在当前环境下可用！")

        // 立即恢复
        scalarInput[0] = 0
        let restoreResult = IOConnectCallScalarMethod(
            connect,
            kPMSetClamshellSleepState,
            &scalarInput,
            1,
            nil,
            nil
        )
        if restoreResult == kIOReturnSuccess {
            print("   已恢复正常合盖行为")
        }
    } else {
        print("❌ Step 3: kPMSetClamshellSleepState — 失败 (error: 0x\(String(callResult, radix: 16)))")
        print("")
        print("⚠️  合盖控制在当前环境下不可用")

        if callResult == 0xe00002c1 { // kIOReturnNotPermitted
            print("   错误码 = kIOReturnNotPermitted → 权限不足")
        } else if callResult == 0xe00002bc { // kIOReturnNotPrivileged
            print("   错误码 = kIOReturnNotPrivileged → 需要更高权限")
        }
    }

    IOServiceClose(connect)
}

// MARK: - Test 3: 检查 Sandbox 状态

func checkSandboxStatus() {
    print("")
    print("=" * 60)
    print("环境检查")
    print("=" * 60)

    // 检测是否在 sandbox 中
    let sandboxEnv = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"]
    if let containerID = sandboxEnv {
        print("🔒 运行在 App Sandbox 中 (container: \(containerID))")
    } else {
        print("🔓 运行在非沙箱环境")
    }

    // 检查架构
    #if arch(arm64)
    print("🖥  架构: Apple Silicon (arm64)")
    #elseif arch(x86_64)
    print("🖥  架构: Intel (x86_64)")
    #endif

    print("📋 macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
}

// MARK: - String repeat helper

extension String {
    static func * (lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}

// MARK: - Main

print("")
print("☕ Stim M1 技术验证 — Clamshell Sleep State")
print("   测试 App Sandbox 下 IOKit 访问能力")
print("")

checkSandboxStatus()
testPowerAssertions()
testClamshellSleepState()

print("")
print("=" * 60)
print("验证完成。请将输出发到 #project-caffeine")
print("=" * 60)
