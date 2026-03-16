import Foundation

/// Manages clamshell (closed-display) sleep prevention using the Power Protect pattern.
///
/// Uses `NSUserUnixTask` to execute a shell script that calls `sudo pmset disablesleep`.
/// Requires one-time setup: installing the control script and a sudoers rule.
///
/// Installation places:
/// - `~/Library/Application Scripts/com.steins.stim/clamshellControl.sh`
/// - `/private/etc/sudoers.d/stim_clamshell`
final class ClamshellManager: ObservableObject {

    static let shared = ClamshellManager()

    // MARK: - Published State

    /// Whether clamshell control is currently active (disablesleep = 1).
    @Published private(set) var isActive = false

    /// Whether Power Protect has been installed (script + sudoers).
    @Published private(set) var isInstalled = false

    // MARK: - Constants

    private let bundleID = "com.steins.stim"
    private let scriptName = "clamshellControl.sh"

    private var scriptDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Scripts/\(bundleID)")
    }

    private var scriptURL: URL {
        scriptDirectory.appendingPathComponent(scriptName)
    }

    private let sudoersPath = "/private/etc/sudoers.d/stim_clamshell"

    // MARK: - Init

    private init() {
        checkInstallation()
        cleanupResidualState()
    }

    // MARK: - Installation Check

    /// Check if both the script and sudoers rule are in place.
    func checkInstallation() {
        let scriptExists = FileManager.default.isExecutableFile(atPath: scriptURL.path)
        // We can't directly check sudoers (no read permission), but if the script exists
        // we assume installation was completed. The actual test is whether `sudo pmset`
        // succeeds without a password prompt.
        isInstalled = scriptExists
    }

    // MARK: - Install Power Protect

    /// Install the clamshell control script and sudoers rule.
    /// Requires admin authentication (Touch ID / password).
    ///
    /// - Parameter completion: Called with `true` on success, `false` on failure.
    func install(completion: @escaping (Bool) -> Void) {
        let username = NSUserName()
        let scriptPath = scriptURL.path
        let scriptDir = scriptDirectory.path

        // The script content to install
        guard let bundleScriptURL = Bundle.main.url(forResource: "clamshellControl", withExtension: "sh") else {
            // Fallback: generate script inline
            let scriptContent = """
            #!/bin/bash
            case "$1" in
                enable) sudo /usr/bin/pmset disablesleep 1 ;;
                disable) sudo /usr/bin/pmset disablesleep 0 ;;
                status) /usr/bin/pmset -g | grep -i disablesleep ;;
                *) echo "Usage: $0 {enable|disable|status}"; exit 1 ;;
            esac
            """

            installWithAppleScript(
                scriptContent: scriptContent,
                scriptDir: scriptDir,
                scriptPath: scriptPath,
                username: username,
                completion: completion
            )
            return
        }

        do {
            let scriptContent = try String(contentsOf: bundleScriptURL, encoding: .utf8)
            installWithAppleScript(
                scriptContent: scriptContent,
                scriptDir: scriptDir,
                scriptPath: scriptPath,
                username: username,
                completion: completion
            )
        } catch {
            completion(false)
        }
    }

    private func installWithAppleScript(
        scriptContent: String,
        scriptDir: String,
        scriptPath: String,
        username: String,
        completion: @escaping (Bool) -> Void
    ) {
        // Escape single quotes in script content for shell embedding
        let escapedScript = scriptContent.replacingOccurrences(of: "'", with: "'\\''")

        let sudoersContent = "\(username) ALL=(root) NOPASSWD: /usr/bin/pmset disablesleep 1, /usr/bin/pmset disablesleep 0"
        let escapedSudoers = sudoersContent.replacingOccurrences(of: "'", with: "'\\''")

        // Use osascript with admin privileges to install both files
        let shellCommand = """
        mkdir -p '\(scriptDir)' && \
        echo '\(escapedScript)' > '\(scriptPath)' && \
        chmod +x '\(scriptPath)' && \
        echo '\(escapedSudoers)' > \(sudoersPath) && \
        chmod 0440 \(sudoersPath)
        """

        let appleScript = """
        do shell script "\(shellCommand.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))" with administrator privileges
        """

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var error: NSDictionary?
            let script = NSAppleScript(source: appleScript)
            script?.executeAndReturnError(&error)

            DispatchQueue.main.async {
                if error == nil {
                    self?.isInstalled = true
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }
    }

    // MARK: - Activate / Deactivate

    /// Enable clamshell keep-awake (pmset disablesleep 1).
    func activate() {
        guard isInstalled else { return }
        runScript(argument: "enable") { [weak self] success in
            if success {
                self?.isActive = true
                UserDefaults.standard.set(true, forKey: "stim_clamshell_active")
            }
        }
    }

    /// Disable clamshell keep-awake (pmset disablesleep 0).
    func deactivate() {
        runScript(argument: "disable") { [weak self] _ in
            self?.isActive = false
            UserDefaults.standard.set(false, forKey: "stim_clamshell_active")
        }
    }

    // MARK: - Cleanup

    /// On launch, check if a previous session left pmset disablesleep on
    /// (e.g. due to crash or force quit) and restore normal behavior.
    private func cleanupResidualState() {
        let wasActive = UserDefaults.standard.bool(forKey: "stim_clamshell_active")
        if wasActive && isInstalled {
            print("[Stim] Cleaning up residual clamshell state from previous session")
            runScript(argument: "disable") { _ in
                UserDefaults.standard.set(false, forKey: "stim_clamshell_active")
            }
        }
    }

    // MARK: - Script Execution

    private func runScript(argument: String, completion: @escaping (Bool) -> Void) {
        guard FileManager.default.isExecutableFile(atPath: scriptURL.path) else {
            completion(false)
            return
        }

        // Use NSUserUnixTask for sandbox-compatible script execution
        do {
            let task = try NSUserUnixTask(url: scriptURL)
            task.execute(withArguments: [argument]) { error in
                DispatchQueue.main.async {
                    completion(error == nil)
                }
            }
        } catch {
            completion(false)
        }
    }
}
