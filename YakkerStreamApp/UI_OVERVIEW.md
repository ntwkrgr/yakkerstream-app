# Yakker Stream App - UI Overview

## Application Window

The app displays a standard macOS window with connection status and controls.

### Header Section
```
⚾️ Yakker Stream
```

### Settings Section
```
Settings                    [? How to Get Credentials]

Yakker Domain:
[yourdomain.yakkertech.com]

Authorization Key:
[Basic YOUR_AUTH_KEY_HERE]
```
- Text fields for entering custom yakker domain and auth key
- "How to Get Credentials" button opens detailed help window
- Fields are disabled while stream is running
- Values are saved automatically and persist between app launches
- Empty by default (user must configure before first use)

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
   - App window opens
   - Shows disconnected status
   - Settings fields are empty (require configuration)

2. **Configure Settings** (required on first run)
   - Click "How to Get Credentials" for detailed instructions
   - Enter custom Yakker domain (e.g., "yourdomain.yakkertech.com")
   - Enter authorization key (e.g., "Basic YOUR_AUTH_TOKEN")
   - Settings are saved automatically when changed

3. **Click "Start Stream"**
   - Settings fields become disabled (locked)
   - Button changes to "Stop Stream" (red)
   - Status changes to "Connecting..."
   - Backend Python process launches with custom domain and auth key
   - After ~2-3 seconds, status changes to "Connected"
   - Metrics begin updating every second

4. **View Metrics**
   - Metrics refresh automatically from backend
   - Values displayed in monospaced font
   - "--" shown when no data available

5. **Click Web Link** (optional)
   - Opens http://localhost:8000 in default browser
   - Shows full web interface with auto-refresh

6. **Click "Stop Stream"**
   - Backend process terminates
   - Status changes to "Disconnected" (⚾️ ✗)
   - Button changes to "Start Stream" (green)
   - Settings fields become enabled again
   - Metrics cleared
6. **Click "Stop Stream"**
   - Backend process terminates
   - Status changes to "Disconnected"
   - Button changes to "Start Stream" (green)
   - Settings fields become enabled again
   - Metrics cleared

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
