import SwiftUI

struct ContentView: View {
    @ObservedObject var manager = YakkerStreamManager.shared
    
    // UI Constants - used to size the standalone window
    private static let windowWidth: CGFloat = 260
    private static let windowHeight: CGFloat = 420
    
    var body: some View {
        VStack(spacing: 18) {
            // Header
            HStack {
                Image(systemName: "baseball.fill")
                    .font(.title)
                Text("Yakker Stream")
                    .font(.title2)
                    .bold()
            }
            .padding(.top)
            
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
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
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
            
            // Footer with web link
            if manager.isRunning {
                VStack(spacing: 4) {
                    Text("Data Stream URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 6)
                    
                    Button(action: {
                        if let url = URL(string: YakkerStreamManager.backendBaseURL + "/livedata.xml") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Text(YakkerStreamManager.backendBaseURL + "/livedata.xml")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.bottom)
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
                .frame(minHeight: 140, maxHeight: 240)
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
