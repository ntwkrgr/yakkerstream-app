import SwiftUI

struct ContentView: View {
    @ObservedObject var manager = YakkerStreamManager.shared
    @State private var showingHelp = false
    @State private var showingSettings = false
    @State private var hasInitialized = false
    @State private var showCopiedFeedback = false
    
    // UI Constants - used to size the standalone window
    private static let windowWidth: CGFloat = 520
    private static let windowHeight: CGFloat = 580
    private static let repoIssuesURL = "https://github.com/ntwkrgr/yakker-to-proscoreboard/issues"
    
    var body: some View {
        VStack(spacing: 18) {
            // Header
            HStack {
                Image(systemName: "baseball.fill")
                    .font(.title)
                Text("Yakker Stream")
                    .font(.title2)
                    .bold()
                Spacer()
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Settings")
            }
            .padding(.top)
            .padding(.horizontal)
            
            Divider()
            
            // Connection Status
            VStack(spacing: 10) {
                HStack {
                    Text("Connection Status:")
                        .font(.headline)
                    Spacer()
                    connectionStatusView
                }
                
                if let error = manager.errorMessage {
                    VStack(spacing: 6) {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        // Add link to issues page for troubleshooting
                        Button(action: {
                            if let url = URL(string: Self.repoIssuesURL) {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "questionmark.circle")
                                Text("Get Help")
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal)
            
            // Control Button
            Button(action: {
                if manager.isRunning {
                    manager.stopStream()
                } else {
                    manager.startStream()
                }
            }) {
                HStack {
                    Image(systemName: manager.isRunning ? "stop.circle.fill" : "play.circle.fill")
                    Text(manager.isRunning ? "Stop Stream" : "Start Stream")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(manager.isRunning ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
            
            Divider()
            
            terminalOutputSection
                .padding(.horizontal)
            
            Spacer()
            
            // Footer with copy URL button
            if manager.isRunning {
                VStack(spacing: 8) {
                    Text("Data Stream URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        let urlString = manager.backendBaseURL + "/livedata.xml"
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(urlString, forType: .string)
                        
                        // Show feedback
                        showCopiedFeedback = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            showCopiedFeedback = false
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: showCopiedFeedback ? "checkmark.circle.fill" : "doc.on.doc")
                            Text(showCopiedFeedback ? "Copied!" : "Copy URL to Clipboard")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(showCopiedFeedback ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                        .foregroundColor(showCopiedFeedback ? .green : .blue)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.bottom, 8)
            }
            
            // Quit Button
            Button(action: {
                manager.stopStream()
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.bottom)
        }
        .frame(minWidth: Self.windowWidth, minHeight: Self.windowHeight)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingHelp) {
            HelpView()
        }
        .onAppear {
            // Auto-open settings if credentials are not configured
            if !hasInitialized {
                if !manager.hasSavedCredentials() {
                    showingSettings = true
                }
                hasInitialized = true
            }
        }
        .onChange(of: manager.connectionStatus) { status in
            // Open settings when connection fails (only if not already showing)
            if status == .error && !showingSettings {
                showingSettings = true
            }
        }
    }
    
    private var connectionStatusView: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            
            Text(statusText)
                .font(.subheadline)
                .bold()
        }
    }
    
    private var statusColor: Color {
        switch manager.connectionStatus {
        case .connected:
            return .green
        case .connecting:
            return .yellow
        case .disconnected:
            return .gray
        case .error:
            return .red
        }
    }
    
    private var statusText: String {
        switch manager.connectionStatus {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Disconnected"
        case .error:
            return "Error"
        }
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

extension ContentView {
    fileprivate var terminalOutputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Live Output")
                    .font(.headline)
                Spacer()
                if manager.terminalLines.isEmpty {
                    Text(manager.isRunning ? "Waiting..." : "Idle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 2)
            
            TerminalLogView(lines: manager.terminalLines)
                .frame(minHeight: 200, maxHeight: 350)
        }
    }
}

private struct TerminalLogView: View {
    let lines: [String]
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(index)
                    }
                }
                .padding(8)
            }
            .background(Color.black.opacity(0.85))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
            )
            .onChange(of: lines.count) { _ in
                guard let last = lines.indices.last else { return }
                withAnimation {
                    proxy.scrollTo(last, anchor: .bottom)
                }
            }
        }
    }
}

// Settings view displayed in its own window/sheet
struct SettingsView: View {
    @ObservedObject var manager = YakkerStreamManager.shared
    @State private var showingHelp = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.title2)
                    .bold()
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Connection Settings
                    GroupBox(label: Label("Connection", systemImage: "network")) {
                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Yakker Domain:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("yourdomain.yakkertech.com", text: $manager.yakkerDomain)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .disabled(manager.isRunning)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Authorization Key:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Basic YOUR_AUTH_KEY_HERE", text: $manager.authKey)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .disabled(manager.isRunning)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("HTTP Port:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack {
                                    TextField("8000", value: $manager.httpPort, format: .number.grouping(.never))
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .disabled(manager.isRunning)
                                        .frame(width: 100)
                                    Text("(Default: \(YakkerStreamManager.defaultBackendPort))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            }
                            
                            HStack {
                                Spacer()
                                Button(action: {
                                    showingHelp = true
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "questionmark.circle")
                                        Text("How to Get Credentials")
                                    }
                                    .font(.caption)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.top, 8)
                    }
                    
                    // Metric Settings
                    GroupBox(label: Label("Metrics", systemImage: "gauge")) {
                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Stale Timeout (seconds):")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack {
                                    TextField("10", value: $manager.staleTimeout, format: .number)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .disabled(manager.isRunning)
                                        .frame(width: 100)
                                    Text("(Default: \(YakkerStreamManager.defaultStaleTimeout))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle(isOn: $manager.minimumExitVeloEnabled) {
                                    Text("Enable Minimum Exit Velocity Filter")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .disabled(manager.isRunning)
                                
                                if manager.minimumExitVeloEnabled {
                                    HStack {
                                        Text("Minimum Exit Velo (mph):")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        TextField("65.0", value: $manager.minimumExitVelo, format: .number)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .disabled(manager.isRunning)
                                            .frame(width: 100)
                                        Text("(Default: \(String(format: "%.1f", YakkerStreamManager.defaultMinimumExitVelocity)))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    
                    if manager.isRunning {
                        Text("Some settings are disabled while the stream is running.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 480, minHeight: 420)
        .sheet(isPresented: $showingHelp) {
            HelpView()
        }
    }
}

// Help view that explains how to obtain Yakker credentials
struct HelpView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("How to Get Your Yakker Credentials")
                        .font(.title2)
                        .bold()
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                }
                .padding(.bottom, 10)
                
                Divider()
                
                // Domain section
                VStack(alignment: .leading, spacing: 10) {
                    Label("Finding Your Yakker Domain", systemImage: "globe")
                        .font(.headline)
                    
                    Text("The Yakker domain is the same one you use to log into YakkerTech via your web browser.")
                        .fixedSize(horizontal: false, vertical: true)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Open your web browser")
                        Text("2. Navigate to your YakkerTech dashboard")
                        Text("3. Look at the URL in the address bar")
                        Text("4. Copy the domain portion (e.g., \"yourdomain.yakkertech.com\")")
                    }
                    .font(.system(size: 13))
                    .padding(.leading, 10)
                    
                    Text("Example:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("If you access YakkerTech at https://myteam.yakkertech.com, your domain is: myteam.yakkertech.com")
                        .font(.system(size: 12, design: .monospaced))
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                }
                
                Divider()
                
                // Authorization Key section
                VStack(alignment: .leading, spacing: 10) {
                    Label("Finding Your Authorization Key", systemImage: "key.fill")
                        .font(.headline)
                    
                    Text("The authorization key can be obtained from your browser's developer tools.")
                        .fixedSize(horizontal: false, vertical: true)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("For Chrome/Safari/Firefox:")
                            .font(.subheadline)
                            .bold()
                        Text("1. Open YakkerTech in your browser and log in")
                        Text("2. Open Developer Tools:")
                        Text("   • Chrome/Safari: Right-click → Inspect")
                        Text("   • Firefox: Right-click → Inspect Element")
                        Text("   • Or press F12 (Windows) or Cmd+Option+I (Mac)")
                        Text("3. Click the \"Network\" tab")
                        Text("4. Refresh the page (F5 or Cmd+R)")
                        Text("5. Look for requests to \"ws-events\" or \"api\"")
                        Text("6. Click on one of these requests")
                        Text("7. Find the \"Request Headers\" section")
                        Text("8. Look for \"Authorization\" header")
                        Text("9. Copy the entire value (e.g., \"Basic ABC123...\")")
                    }
                    .font(.system(size: 13))
                    .padding(.leading, 10)
                    
                    Text("Example:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Authorization: Basic d2VidWk6Q3J1Y2lhbFNodWZmbGVOZXZlcg==")
                        .font(.system(size: 11, design: .monospaced))
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    
                    Text("Note: Copy the entire value including \"Basic\" prefix")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Tips", systemImage: "lightbulb.fill")
                        .font(.headline)
                        .foregroundColor(.yellow)
                    
                    Text("• Your authorization key is like a password - keep it secure")
                    Text("• If you have trouble finding the key, contact your YakkerTech administrator")
                    Text("• The key may expire - if connection fails, try obtaining a fresh key")
                }
                .font(.system(size: 13))
                
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 600)
    }
}

