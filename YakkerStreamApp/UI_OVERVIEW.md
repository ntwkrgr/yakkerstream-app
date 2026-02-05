# Yakker Stream App - UI Overview

> **Version 1.0** - Feature complete release

## Application Window

The app displays a standard macOS window with connection status and controls.

### Header Section
```
⚾️ Yakker Stream
```

### Configuration Section (Collapsible)
```
▶ Configuration              [? How to Get Credentials]

Yakker Domain:
[yourdomain.yakkertech.com]

Authorization Key:
[Basic YOUR_AUTH_KEY_HERE]

HTTP Port:
[8000]       (Default: 8000)
```
- Text fields for entering custom yakker domain and auth key
- HTTP port field to customize the backend server port
- "How to Get Credentials" button opens detailed help window
- Fields are disabled while stream is running
- Values are saved automatically and persist between app launches
- Authorization key stored securely in macOS Keychain
- Section collapses automatically when connected

### Connection Status Section
```
Connection Status: ● Connected
```
- Green dot for connected
- Yellow dot for connecting
- Gray dot for disconnected
- Red dot for error
- Error messages displayed below if any

### Control Section
```
[🛑 Stop Stream]  (red button when running)
[▶️ Start Stream] (green button when stopped)
```

### Live Output Section
```
Live Output                                    Waiting...

┌─────────────────────────────────────────────────────┐
│ [info] Starting Yakker Stream...                    │
│ [info] Connecting to YakkerTech websocket...        │
│ [info] Connected to Yakker                          │
│ [info] ProScoreboard XML API available at :8000     │
│ Exit: 87.9 mph | Angle: 30.3° | Dist: 287 ft        │
│ Pitch: 44.7 mph | Spin: 1031 rpm                    │
└─────────────────────────────────────────────────────┘
```
- Terminal-style scrolling log view
- Shows backend output in real-time
- Auto-scrolls to latest output
- Dark background with monospaced font

### Footer Section (when running)
```
Data Stream URL
[Copy URL to Clipboard]

[Quit]
```
- Copy URL button copies the livedata.xml URL to clipboard
- Shows "Copied!" feedback briefly after clicking

## Interaction Flow

1. **Launch App**
   - App window opens
   - Shows disconnected status
   - Configuration section expanded if no saved credentials

2. **Configure Settings** (required on first run)
   - Expand Configuration section if collapsed
   - Click "How to Get Credentials" for detailed instructions
   - Enter custom Yakker domain (e.g., "yourdomain.yakkertech.com")
   - Enter authorization key (e.g., "Basic YOUR_AUTH_TOKEN")
   - Optionally change HTTP port (default: 8000)
   - Settings are saved automatically when changed
   - Authorization key stored securely in macOS Keychain

3. **Click "Start Stream"**
   - Configuration fields become disabled (locked)
   - Button changes to "Stop Stream" (red)
   - Status changes to "Connecting..."
   - Backend Python process launches with configured settings
   - Live Output shows real-time backend logs
   - After ~2-3 seconds, status changes to "Connected"
   - Configuration section auto-collapses

4. **View Live Output**
   - Backend logs displayed in terminal-style view
   - Auto-scrolls to show latest output
   - Shows connection status, data events, and metrics

5. **Copy URL** (optional)
   - Click "Copy URL to Clipboard" button
   - URL is copied to system clipboard
   - Button shows "Copied!" feedback

6. **Click "Stop Stream"**
   - Backend process terminates
   - Status changes to "Disconnected"
   - Button changes to "Start Stream" (green)
   - Configuration fields become enabled again
   - Live output cleared

7. **Click "Quit"**
   - Stops stream if running
   - Terminates application

## Technical Implementation

### Connection Monitoring
- ObservableObject pattern for reactive UI updates
- NotificationCenter for status change broadcasts
- Timer-based polling of backend HTTP endpoint
- Process monitoring to detect crashes

### Backend Integration
- Copies bundled scripts to Application Support directory
- Launches `yakker.sh` script using Foundation.Process
- Captures stdout/stderr for live terminal output
- Polls `/livedata.xml` endpoint every 1 second
- Regex parsing of XML for metrics extraction

### UI Components
- SwiftUI for interface
- Combine for reactive updates
- URLSession for HTTP requests
- NSWorkspace for browser launching
- ScrollViewReader for auto-scrolling terminal output

### Security
- Authorization key stored in macOS Keychain
- Domain validation to prevent injection attacks
- Shell argument escaping for safe process launching

## App Size & Requirements

- Compiled app size: ~1-2 MB (excluding Xcode metadata)
- RAM usage: ~20-30 MB for UI, plus Python backend (~50-100 MB)
- macOS 13.0+ required for SwiftUI features
- No third-party dependencies (uses system frameworks only)
