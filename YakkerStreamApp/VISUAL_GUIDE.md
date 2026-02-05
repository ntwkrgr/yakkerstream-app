# Yakker Stream App - Visual Guide

> **Version 1.0** - Feature complete release

## Application Window

```
┌──────────────────────────────────────────┐
│                                          │
│           ⚾️ Yakker Stream               │
│                                          │
├──────────────────────────────────────────┤
│                                          │
│  ▶ Configuration [? How to Get Creds]    │
│                                          │
│  Yakker Domain:                          │
│  ┌────────────────────────────────────┐  │
│  │ yourdomain.yakkertech.com          │  │
│  └────────────────────────────────────┘  │
│                                          │
│  Authorization Key:                      │
│  ┌────────────────────────────────────┐  │
│  │ Basic YOUR_AUTH_KEY_HERE           │  │
│  └────────────────────────────────────┘  │
│                                          │
│  HTTP Port:                              │
│  ┌──────────┐ (Default: 8000)            │
│  │ 8000     │                            │
│  └──────────┘                            │
│                                          │
├──────────────────────────────────────────┤
│                                          │
│  Connection Status:        ● Connected   │
│                                          │
├──────────────────────────────────────────┤
│                                          │
│  ┌────────────────────────────────────┐  │
│  │       🛑  Stop Stream              │  │
│  │         (red button)               │  │
│  └────────────────────────────────────┘  │
│                                          │
├──────────────────────────────────────────┤
│                                          │
│  Live Output                  Waiting... │
│  ┌────────────────────────────────────┐  │
│  │ [info] Starting Yakker Stream...   │  │
│  │ [info] Connected to Yakker         │  │
│  │ Exit: 87.9 | Angle: 30.3           │  │
│  │ Pitch: 44.7 | Spin: 1031           │  │
│  └────────────────────────────────────┘  │
│                                          │
├──────────────────────────────────────────┤
│                                          │
│          Data Stream URL                 │
│       [Copy URL to Clipboard]            │
│                                          │
│              Quit                        │
│                                          │
└──────────────────────────────────────────┘
```

## Connection States

### 1. Disconnected
```
Status: ● Disconnected (gray dot)
Button: [▶️ Start Stream] (green)
Configuration: Editable
Live Output: "Idle"
```

### 2. Connecting
```
Status: ● Connecting... (yellow dot)
Button: [🛑 Stop Stream] (red)
Configuration: Locked (disabled)
Live Output: Backend startup logs
```

### 3. Connected
```
Status: ● Connected (green dot)
Button: [🛑 Stop Stream] (red, active)
Configuration: Locked (disabled), auto-collapsed
Live Output: Real-time metric data
Copy URL: Button visible
```

### 4. Error
```
Status: ● Error (red dot)
Error: "Please configure your Yakker domain and authorization key"
Button: [▶️ Start Stream] (green)
Configuration: Editable, auto-expanded
Live Output: Error details
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│               YakkerStream macOS App                │
│                  (Swift/SwiftUI)                    │
│                                                     │
│  ┌──────────────┐      ┌──────────────────────┐   │
│  │YakkerStream- │──────│ YakkerStreamManager  │   │
│  │ AppApp.swift │      │   (Process Control)  │   │
│  └──────────────┘      └──────────┬───────────┘   │
│         │                          │               │
│         │                          │               │
│  ┌──────▼──────┐                  │               │
│  │ ContentView │                  │               │
│  │ (Main UI)   │◄─────────────────┘               │
│  └─────────────┘                                   │
└─────────────────┬───────────────────┬──────────────┘
                  │                   │
                  │ Foundation.Process│ URLSession
                  │ (Launch/Monitor)  │ (HTTP Poll)
                  │                   │
                  ▼                   ▼
         ┌─────────────────────────────────┐
         │    yakker_stream.py Backend     │
         │         (Python/aiohttp)        │
         │                                 │
         │  ┌──────────┐  ┌────────────┐  │
         │  │ WebSocket│  │ HTTP Server│  │
         │  │ to Yakker│  │ (port cfg) │  │
         │  └──────────┘  └────────────┘  │
         │                                 │
         │  Endpoints:                     │
         │  • GET /                        │
         │  • GET /data.xml                │
         │  • GET /livedata.xml            │
         └─────────────────────────────────┘
```

## Data Flow

```
YakkerTech Sensors
       │
       ▼
WebSocket Stream
       │
       ▼
Python Backend (yakker_stream.py)
  • Aggregates metrics
  • Smooths data (1-sec rolling avg)
  • Serves HTTP endpoints
       │
       ├─────────────┬─────────────┐
       ▼             ▼             ▼
    Browser    ProScoreboard   SwiftUI App
    (port cfg)  livedata.xml   livedata.xml
   (HTML view)   (XML feed)    (polling)
                                   │
                                   ▼
                            App Window
                         (Live Terminal UI)
```

## File Structure

```
yakkerstream-app/
├── README.md             ← Main documentation
├── YAKKER_METRICS.md     ← Metrics reference
│
└── YakkerStreamApp/      ← SwiftUI macOS App
    ├── README.md         ← App-specific docs
    ├── UI_OVERVIEW.md    ← UI documentation
    ├── VISUAL_GUIDE.md   ← This file
    ├── build.sh          ← Build script
    ├── check-system.sh   ← System requirements checker
    │
    ├── YakkerStreamApp.xcodeproj/
    │   └── project.pbxproj
    │
    └── YakkerStreamApp/  ← Source code
        ├── YakkerStreamAppApp.swift    ← Main app entry
        ├── ContentView.swift           ← Main UI window
        ├── YakkerStreamManager.swift   ← Backend controller
        ├── Info.plist                  ← App config
        ├── YakkerStreamApp.entitlements ← Permissions
        ├── Assets.xcassets/            ← Icons
        └── Resources/                  ← Bundled backend files
            ├── yakker.sh
            ├── yakker_stream.py
            ├── requirements.txt
            └── livedata.xml.template
```

## Version 1.0 Features Checklist

- [✓] Native macOS app window
- [✓] Connection status indicator (colored dots)
- [✓] Start/Stop button for stream control
- [✓] Six metrics: Exit Velocity, Launch Angle, Hit Distance, Hang Time, Pitch Velocity, Spin Rate
- [✓] Live terminal output display
- [✓] Auto-scrolling log view
- [✓] Collapsible configuration section
- [✓] Configurable HTTP port
- [✓] Secure credential storage (Keychain)
- [✓] Copy URL to clipboard button
- [✓] Error handling and display with help link
- [✓] Process monitoring
- [✓] Clean shutdown on quit
- [✓] Domain validation
- [✓] Shell argument escaping for security
