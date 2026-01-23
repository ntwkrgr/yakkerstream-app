import Foundation
import Combine
import Security

enum ConnectionStatus {
    case disconnected
    case connecting
    case connected
    case error
}

struct YakkerMetrics {
    var exitVelocity: String?
    var launchAngle: String?
    var pitchVelocity: String?
    var spinRate: String?
    var hitDistance: String?
    var hangTime: String?
}

// Keychain helper for secure storage of sensitive credentials
class KeychainHelper {
    static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }
        
        // Delete any existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
}

class YakkerStreamManager: ObservableObject {
    static let shared = YakkerStreamManager()
    
    @Published var isRunning = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var metrics = YakkerMetrics()
    @Published var errorMessage: String?
    @Published var terminalLines: [String] = []
    
    // User configurable settings
    @Published var yakkerDomain: String {
        didSet {
            UserDefaults.standard.set(yakkerDomain, forKey: "yakkerDomain")
        }
    }
    @Published var authKey: String {
        didSet {
            _ = KeychainHelper.save(key: "yakkerAuthKey", value: authKey)
        }
    }
    
    // Configuration constants
    /// Delay after starting the backend before checking connection status (allows backend to initialize)
    private static let startupDelay: TimeInterval = 2.0
    /// Interval for polling the backend HTTP endpoint for live metrics
    private static let metricsPollingInterval: TimeInterval = 1.0
    /// Interval for checking if the backend process is still running
    private static let statusCheckInterval: TimeInterval = 5.0
    /// Grace period for backend process to terminate cleanly before forcing interrupt
    private static let processTerminationDelay: TimeInterval = 1.0
    /// HTTP port for backend server
    static let backendPort = 8000
    /// Base URL for backend HTTP endpoints
    static let backendBaseURL = "http://localhost:\(backendPort)"
    /// Convenience endpoint for livedata XML feed served by yakker_stream.py
    private static let livedataEndpoint = backendBaseURL + "/livedata.xml"
    /// Ignore exit velocity readings below this threshold (throwbacks, foul tips, etc.)
    private static let minimumExitVelocity: Double = 65.0
    /// Max terminal log lines to retain in UI
    private static let maxTerminalLines = 200
    
    // Backend output patterns for connection detection
    private static let connectingPatterns = ["Connecting to Yakker", "Starting Yakker"]
    private static let connectedPatterns = [
        "ProScoreboard XML API available",
        "Connected to Yakker",
        "Connected to YakkerTech websocket",
        "Demo feed"
    ]
    private static let errorPatterns = ["[ERROR]", "ERROR:", "Traceback", "Exception", "Failed to", "CRITICAL"]
    private static let infoLogIndicators = ["[info]", " info:", " info "]
    private static let fatalLogIndicators = [
        "[error]",
        " error:",
        " error ",
        "traceback",
        "exception",
        "critical",
        "fatal",
        "failed to",
        "failed:",
        "unable to"
    ]
    
    // Cached regex patterns for XML parsing
    private static let xmlPatterns: [String: NSRegularExpression] = {
        // livedata.xml uses ProScoreboard baseball attribute mapping
        let patterns = [
            "exitVelo": #"h=\"([^\"]+)\""#,
            "launchAngle": #"rbi=\"([^\"]+)\""#,
            "pitchVelo": #"er=\"([^\"]+)\""#,
            "spinRate": #"pitches=\"([^\"]+)\""#,
            "hitDistance": #"double=\"([^\"]+)\""#,
            "hangTime": #"triple=\"([^\"]+)\""#
        ]
        return patterns.compactMapValues { try? NSRegularExpression(pattern: $0, options: []) }
    }()
    
    private enum PortManagementError: LocalizedError {
        case commandUnavailable(String)
        case failedToTerminate(String)
        
        var errorDescription: String? {
            switch self {
            case .commandUnavailable(let command):
                return "Required command \(command) is not available."
            case .failedToTerminate(let pid):
                return "Could not terminate process \(pid) occupying the port."
            }
        }
    }
    
    private var process: Process?
    private var metricsTimer: Timer?
    private var statusCheckTimer: Timer?
    
    private init() {
        // Load saved settings or use empty placeholders (non-functional defaults)
        self.yakkerDomain = UserDefaults.standard.string(forKey: "yakkerDomain") ?? ""
        self.authKey = KeychainHelper.load(key: "yakkerAuthKey") ?? ""
    }
    
    func hasSavedCredentials() -> Bool {
        return !yakkerDomain.isEmpty && !authKey.isEmpty
    }
    
    func startStream() {
        guard !isRunning else { return }
        
        // Check if settings are configured
        if yakkerDomain.isEmpty || authKey.isEmpty {
            connectionStatus = .error
            errorMessage = "Please configure your Yakker domain and authorization key before starting."
            notifyStatusChange()
            return
        }
        
        // Validate domain input
        guard isValidDomain(yakkerDomain) else {
            connectionStatus = .error
            errorMessage = "Invalid domain format. Please enter a valid domain (e.g., yourdomain.yakkertech.com)."
            notifyStatusChange()
            return
        }
        
        // Find the repository root directory
        let repoPath = findRepoPath()
        let scriptPath = repoPath + "/yakker.sh"
        
        // Check if yakker.sh exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: scriptPath) else {
            connectionStatus = .error
            errorMessage = "yakker.sh not found. Please ensure the app is in the same directory as yakker.sh or place yakker-stream in ~/yakker-stream"
            notifyStatusChange()
            return
        }
        
        do {
            try freeBackendPort()
        } catch {
            connectionStatus = .error
            errorMessage = "Port \(Self.backendPort) busy: \(error.localizedDescription)"
            notifyStatusChange()
            return
        }
        
        // Update status
        isRunning = true
        connectionStatus = .connecting
        errorMessage = nil
        terminalLines.removeAll()
        notifyStatusChange()
        
        // Start the Python backend
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        
        // Build websocket URL from domain
        let wsUrl = "wss://\(yakkerDomain)/api/v2/ws-events"
        let authHeader = "Authorization: \(authKey)"
        
        // Properly escape shell arguments to prevent injection
        let escapedRepoPath = shellEscape(repoPath)
        let escapedWsUrl = shellEscape(wsUrl)
        let escapedAuthHeader = shellEscape(authHeader)
        
        // Change to repo directory and run yakker.sh with custom settings
        let script = """
        cd \(escapedRepoPath) && ./yakker.sh --ws-url \(escapedWsUrl) --auth-header \(escapedAuthHeader)
        """
        
        process.arguments = ["-c", script]
        
        // Capture output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Monitor output for connection status
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let output = String(data: data, encoding: .utf8), !output.isEmpty else { return }
            print("Yakker output: \(output)")
            DispatchQueue.main.async {
                self?.appendTerminalOutput(output, isError: false)
                self?.processBackendLog(output, isErrorStream: false)
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let errorOutput = String(data: data, encoding: .utf8), !errorOutput.isEmpty else { return }
            print("Yakker stderr: \(errorOutput)")
            DispatchQueue.main.async {
                self?.appendTerminalOutput(errorOutput, isError: true)
                self?.processBackendLog(errorOutput, isErrorStream: true)
            }
        }
        
        do {
            try process.run()
            self.process = process
            
            // Give it a moment to start, then verify connection
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.startupDelay) { [weak self] in
                self?.verifyBackendConnection()
            }
            
            // Start periodic status checks
            startStatusChecking()
            
        } catch {
            self.connectionStatus = .error
            self.errorMessage = "Failed to start: \(error.localizedDescription)"
            self.isRunning = false
            self.notifyStatusChange()
        }
    }
    
    func stopStream() {
        guard isRunning else { return }
        
        // Stop timers
        metricsTimer?.invalidate()
        metricsTimer = nil
        statusCheckTimer?.invalidate()
        statusCheckTimer = nil
        
        // Terminate the process
        if let process = process, process.isRunning {
            process.terminate()
            
            // Give it a moment to clean up
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.processTerminationDelay) { [weak self] in
                if let process = self?.process, process.isRunning {
                    process.interrupt()
                }
            }
        }
        
        process = nil
        isRunning = false
        connectionStatus = .disconnected
        errorMessage = nil
        
        // Clear metrics and terminal output
        metrics = YakkerMetrics()
        terminalLines.removeAll()
        
        notifyStatusChange()
    }
    
    private func startMetricsPolling() {
        // Poll the HTTP endpoint every second for metrics
        metricsTimer?.invalidate()
        metricsTimer = Timer.scheduledTimer(withTimeInterval: Self.metricsPollingInterval, repeats: true) { [weak self] _ in
            self?.fetchMetrics()
        }
    }
    
    private func startStatusChecking() {
        // Check if process is still running every 5 seconds
        statusCheckTimer?.invalidate()
        statusCheckTimer = Timer.scheduledTimer(withTimeInterval: Self.statusCheckInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if let process = self.process, !process.isRunning {
                DispatchQueue.main.async {
                    self.connectionStatus = .error
                    self.errorMessage = "Backend process stopped unexpectedly"
                    self.isRunning = false
                    self.notifyStatusChange()
                }
            }
        }
    }
    
    private func verifyBackendConnection() {
        // Verify backend is actually responding before marking as connected
        guard let url = URL(string: Self.livedataEndpoint) else {
            connectionStatus = .error
            errorMessage = "Invalid backend URL"
            notifyStatusChange()
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if error != nil || data == nil {
                    // Backend not responding yet, might still be starting
                    if self.connectionStatus == .connecting {
                        // Keep trying for a bit longer
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.verifyBackendConnection()
                        }
                    }
                } else {
                    // Backend is responding!
                    if self.connectionStatus == .connecting {
                        self.connectionStatus = .connected
                        self.notifyStatusChange()
                        self.startMetricsPolling()
                    }
                }
            }
        }
        task.resume()
    }
    
    private func fetchMetrics() {
        guard let url = URL(string: Self.livedataEndpoint) else { return }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching metrics: \(error)")
                return
            }
            
            guard let data = data,
                  let xmlString = String(data: data, encoding: .utf8) else {
                return
            }
            
            DispatchQueue.main.async {
                self.parseMetrics(from: xmlString)
            }
        }
        
        task.resume()
    }
    
    private func extractValue(from xml: String, patternKey: String) -> String? {
        guard let regex = Self.xmlPatterns[patternKey] else {
            return nil
        }
        
        let range = NSRange(xml.startIndex..., in: xml)
        guard let match = regex.firstMatch(in: xml, options: [], range: range) else {
            return nil
        }
        
        if match.numberOfRanges > 1,
           let valueRange = Range(match.range(at: 1), in: xml) {
            let value = String(xml[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let placeholders: Set<String> = ["--", "----"]
            return placeholders.contains(value) ? nil : value
        }
        
        return nil
    }
    
    private func parseMetrics(from xml: String) {
        // Parse XML metrics from the backend livedata.xml endpoint.
        // The backend writes ProScoreboard baseball attributes (e.g. h="Exit Velo", er="Pitch Velo").
        // See livedata.xml.template for the mapping rationale.
        let rawExitVelocity = extractValue(from: xml, patternKey: "exitVelo")
        if let exitValue = rawExitVelocity,
           let exitDouble = Double(exitValue),
           exitDouble < Self.minimumExitVelocity {
            metrics.exitVelocity = nil
        } else {
            metrics.exitVelocity = rawExitVelocity
        }
        metrics.launchAngle = extractValue(from: xml, patternKey: "launchAngle")
        metrics.pitchVelocity = extractValue(from: xml, patternKey: "pitchVelo")
        metrics.spinRate = extractValue(from: xml, patternKey: "spinRate")
        metrics.hitDistance = extractValue(from: xml, patternKey: "hitDistance")
        metrics.hangTime = extractValue(from: xml, patternKey: "hangTime")
    }
    
    private func processBackendLog(_ log: String, isErrorStream: Bool) {
        let trimmed = log.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        updateStatusFromLog(trimmed)
        
        if isErrorStream && logIndicatesFatal(trimmed) {
            connectionStatus = .error
            errorMessage = trimmed.components(separatedBy: .newlines).first
            notifyStatusChange()
        }
    }
    
    private func appendTerminalOutput(_ text: String, isError: Bool) {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return }
        for line in lines {
            let prefix = isError ? "⚠︎ " : ""
            terminalLines.append(prefix + line)
        }
        if terminalLines.count > Self.maxTerminalLines {
            terminalLines.removeFirst(terminalLines.count - Self.maxTerminalLines)
        }
    }
    
    private func updateStatusFromLog(_ log: String) {
        if Self.connectingPatterns.contains(where: { log.localizedCaseInsensitiveContains($0) }) {
            connectionStatus = .connecting
            notifyStatusChange()
        } else if Self.connectedPatterns.contains(where: { log.localizedCaseInsensitiveContains($0) }) {
            connectionStatus = .connected
            errorMessage = nil
            notifyStatusChange()
        } else if Self.errorPatterns.contains(where: { log.localizedCaseInsensitiveContains($0) }) {
            connectionStatus = .error
            errorMessage = log.components(separatedBy: .newlines).first
            notifyStatusChange()
        }
    }
    
    private func logIndicatesFatal(_ log: String) -> Bool {
        let lower = log.lowercased()
        if Self.infoLogIndicators.contains(where: { lower.contains($0) }) {
            return false
        }
        return Self.fatalLogIndicators.contains(where: { lower.contains($0) })
    }
    
    private func freeBackendPort() throws {
        let pids = try pidsUsingBackendPort()
        guard !pids.isEmpty else { return }
        for pid in pids {
            try terminateProcess(pid)
        }
    }
    
    private func pidsUsingBackendPort() throws -> [String] {
        let lsofPath = "/usr/sbin/lsof"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: lsofPath)
        task.arguments = ["-ti", "tcp:\(Self.backendPort)"]
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        do {
            try task.run()
        } catch {
            throw PortManagementError.commandUnavailable(lsofPath)
        }
        task.waitUntilExit()
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        return output
            .split(whereSeparator: { $0.isNewline })
            .map { String($0) }
            .filter { !$0.isEmpty }
    }
    
    private func terminateProcess(_ pid: String) throws {
        let killPath = "/bin/kill"
        let killTask = Process()
        killTask.executableURL = URL(fileURLWithPath: killPath)
        killTask.arguments = ["-9", pid]
        do {
            try killTask.run()
        } catch {
            throw PortManagementError.commandUnavailable(killPath)
        }
        killTask.waitUntilExit()
        if killTask.terminationStatus != 0 {
            throw PortManagementError.failedToTerminate(pid)
        }
    }
    
    private func findRepoPath() -> String {
        // Get the bundle path and navigate to the repo root
        let fileManager = FileManager.default
        let currentPath = fileManager.currentDirectoryPath
        let homeDir = NSHomeDirectory()
        
        // Common locations to check
        var possiblePaths = [
            currentPath,
            homeDir + "/yakker-stream",
            homeDir + "/Desktop/yakker-stream",
            homeDir + "/Documents/yakker-stream",
            homeDir + "/Downloads/yakker-stream",
        ]
        
        // Add parent directory of the app bundle (works regardless of app name)
        let bundleURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        if bundleURL.pathExtension == "app" {
            possiblePaths.append(bundleURL.deletingLastPathComponent().path)
        }
        
        for path in possiblePaths {
            if fileManager.fileExists(atPath: path + "/yakker.sh") {
                return path
            }
        }
        
        // If not found, return the home directory as fallback
        // This will cause the script to fail with a clear error message
        return homeDir + "/yakker-stream"
    }
    
    private func notifyStatusChange() {
        NotificationCenter.default.post(name: NSNotification.Name("ConnectionStatusChanged"), object: nil)
    }
    
    private func isValidDomain(_ domain: String) -> Bool {
        // Validate domain format to prevent injection attacks
        // Pattern allows: subdomain.domain.tld or domain.tld
        let domainPattern = "^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.[a-zA-Z]{2,}(\\.[a-zA-Z]{2,})?$"
        let domainRegex = try? NSRegularExpression(pattern: domainPattern, options: [])
        let range = NSRange(location: 0, length: domain.utf16.count)
        return domainRegex?.firstMatch(in: domain, options: [], range: range) != nil
    }
    
    private func shellEscape(_ string: String) -> String {
        // Escape shell special characters by wrapping in single quotes
        // and escaping any existing single quotes
        return "'\(string.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
