# Yakker Stream App - UI Overview

## Menu Bar Icon States

The app displays a baseball emoji in the macOS menu bar with different status indicators:

- **⚾️ ✓** - Connected and streaming data
- **⚾️ ...** - Connecting to backend
- **⚾️ ✗** - Disconnected
- **⚾️ ⚠️** - Error state

## Main Popover Interface

When you click the menu bar icon, a popover appears with:

### Header Section
```
⚾️ Yakker Stream
```

### Settings Section
```
Settings

Yakker Domain:
[domain.yakkertech.com]

Authorization Key:
[Basic ...]
```
- Text fields for entering custom yakker domain and auth key
- Fields are disabled while stream is running
- Values are saved automatically and persist between app launches

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

### Metrics Display Section
```
Live Metrics

Exit Velocity    --    mph
Launch Angle     --    °
Pitch Velocity   --    mph
Spin Rate        --    rpm
Hit Distance     --    ft
Hang Time        --    sec
```

When the stream is running with data, metrics show actual values:
```
Exit Velocity    87.9   mph
Launch Angle     30.3   °
Pitch Velocity   44.7   mph
Spin Rate        1031   rpm
Hit Distance     287    ft
Hang Time        3.6    sec
```

### Footer Section
```
Web Interface
http://localhost:8000

[Quit]
```

## Interaction Flow

1. **Launch App**
   - Baseball icon appears in menu bar
   - Shows disconnected status (⚾️ ✗)
   - No dock icon (menu bar only)

2. **Click Menu Bar Icon**
   - Popover slides down from menu bar
   - Shows current connection status
   - Displays settings fields (pre-filled from saved settings)
   - Displays control button

3. **Configure Settings** (optional)
   - Enter custom Yakker domain (e.g., "yourdomain.yakkertech.com")
   - Enter authorization key (e.g., "Basic YOUR_AUTH_TOKEN")
   - Settings are saved automatically when changed
   - If not changed, defaults to angelosubb.yakkertech.com with default auth key

4. **Click "Start Stream"**
   - Settings fields become disabled (locked)
   - Button changes to "Stop Stream" (red)
   - Status changes to "Connecting..." (⚾️ ...)
   - Backend Python process launches with custom domain and auth key
   - After ~2-3 seconds, status changes to "Connected" (⚾️ ✓)
   - Metrics begin updating every second

5. **View Metrics**
   - Metrics refresh automatically from backend
   - Values displayed in monospaced font
   - "--" shown when no data available

6. **Click Web Link** (optional)
   - Opens http://localhost:8000 in default browser
   - Shows full web interface with auto-refresh

7. **Click "Stop Stream"**
   - Backend process terminates
   - Status changes to "Disconnected" (⚾️ ✗)
   - Button changes to "Start Stream" (green)
   - Settings fields become enabled again
   - Metrics cleared

8. **Click Outside Popover**
   - Popover closes
   - Menu bar icon remains visible
   - Stream continues running in background

9. **Click "Quit"**
   - Stops stream if running
   - Terminates application
   - Menu bar icon disappears

## Technical Implementation

### Menu Bar Setup
- Uses `LSUIElement = YES` in Info.plist to hide dock icon
- `NSStatusBar.system.statusItem` for menu bar presence
- `NSPopover` with `transient` behavior for auto-dismiss
- `NSHostingController` bridges SwiftUI to AppKit

### Connection Monitoring
- ObservableObject pattern for reactive UI updates
- NotificationCenter for status change broadcasts
- Timer-based polling of backend HTTP endpoint
- Process monitoring to detect crashes

### Backend Integration
- Launches `yakker.sh` script using Foundation.Process
- Captures stdout/stderr for status detection
- Polls `/data.xml` endpoint every 1 second
- Simple regex parsing of XML for metrics extraction

### UI Components
- SwiftUI for interface
- Combine for reactive updates
- URLSession for HTTP requests
- NSWorkspace for browser launching

## App Size & Requirements

- Compiled app size: ~1-2 MB (excluding Xcode metadata)
- RAM usage: ~20-30 MB for UI, plus Python backend (~50-100 MB)
- macOS 13.0+ required for SwiftUI features
- No third-party dependencies (uses system frameworks only)
