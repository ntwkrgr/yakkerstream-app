# Yakker Stream Menu Bar App - Visual Guide

## Menu Bar Icon

```
┌────────────────────────────────────────────────────────┐
│  🍎   📁   🔍   ⚾️ ✓   🔋   📶   🕐 Mon 2:30 PM        │
└────────────────────────────────────────────────────────┘
                    ↑
              Click here to open
```

## Popover Interface (400×600 pixels)

```
┌──────────────────────────────────────────┐
│                                          │
│           ⚾️ Yakker Stream               │
│                                          │
├──────────────────────────────────────────┤
│                                          │
│  Settings                                │
│                                          │
│  Yakker Domain:                          │
│  ┌────────────────────────────────────┐  │
│  │ angelosubb.yakkertech.com          │  │
│  └────────────────────────────────────┘  │
│                                          │
│  Authorization Key:                      │
│  ┌────────────────────────────────────┐  │
│  │ Basic d2VidWk...                   │  │
│  └────────────────────────────────────┘  │
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
│  Live Metrics                            │
│                                          │
│  Exit Velocity     87.9  mph             │
│  Launch Angle      30.3  °               │
│  Pitch Velocity    44.7  mph             │
│  Spin Rate         1031  rpm             │
│  Hit Distance      287   ft              │
│  Hang Time         3.6   sec             │
│                                          │
├──────────────────────────────────────────┤
│                                          │
│          Web Interface                   │
│       http://localhost:8000              │
│         (clickable link)                 │
│                                          │
│              Quit                        │
│                                          │
└──────────────────────────────────────────┘
```

## Connection States

### 1. Disconnected
```
Menu Bar: ⚾️ ✗
Status: ● Disconnected (gray dot)
Button: [▶️ Start Stream] (green)
Metrics: "Start the stream to view metrics"
```

### 2. Connecting
```
Menu Bar: ⚾️ ...
Status: ● Connecting... (yellow dot)
Button: [🛑 Stop Stream] (red, disabled)
Metrics: "Start the stream to view metrics"
```

### 3. Connected
```
Menu Bar: ⚾️ ✓
Status: ● Connected (green dot)
Button: [🛑 Stop Stream] (red, active)
Metrics: Live values updating every second
```

### 4. Error
```
Menu Bar: ⚾️ ⚠️
Status: ● Error (red dot)
Error: "Connection error - check logs"
Button: [▶️ Start Stream] (green)
Metrics: "--" for all values
```

## User Flow Diagram

```
Launch App
    │
    ▼
⚾️ ✗ appears in menu bar
    │
    ▼
Click menu bar icon
    │
    ▼
┌───────────────────┐
│   Popover opens   │
│  Status: ✗        │
│  Button: Start    │
└───────────────────┘
    │
    ▼
Click "Start Stream"
    │
    ├─────────────────────────┐
    │                         │
    ▼                         ▼
Status: ⚾️ ...          Backend launches
Connecting...            yakker.sh --demo
    │                         │
    └─────────────────────────┘
                  │
                  ▼
         ⚾️ ✓ Connected!
                  │
                  ▼
    ┌─────────────────────────┐
    │  Metrics auto-update    │
    │  Every 1 second via     │
    │  HTTP poll to backend   │
    └─────────────────────────┘
                  │
      ┌───────────┴───────────┐
      │                       │
      ▼                       ▼
Click outside           Click "Stop Stream"
Popover closes          Backend terminates
(keeps running)         Status: ⚾️ ✗
      │                       │
      │                       │
      └───────────────────────┘
                  │
                  ▼
            Click "Quit"
                  │
                  ▼
         App terminates
       Menu icon disappears
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│                   Menu Bar App                      │
│                  (Swift/SwiftUI)                    │
│                                                     │
│  ┌──────────────┐      ┌──────────────────────┐   │
│  │  AppDelegate │──────│ YakkerStreamManager  │   │
│  │  (Menu Bar)  │      │   (Process Control)  │   │
│  └──────────────┘      └──────────┬───────────┘   │
│         │                          │               │
│         │                          │               │
│  ┌──────▼──────┐                  │               │
│  │ ContentView │                  │               │
│  │   (UI)      │◄─────────────────┘               │
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
         │  │ to Yakker│  │ :8000      │  │
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
     :8000      livedata.xml    data.xml
   (HTML view)   (XML feed)    (polling)
                                   │
                                   ▼
                            Menu Bar Popover
                            (Live Metrics UI)
```

## File Structure

```
yakker-stream/
├── yakker.sh              ← Launch script (used by app)
├── yakker_stream.py       ← Python backend
├── requirements.txt       ← Python dependencies
├── README.md             ← Main documentation
│
└── YakkerStreamApp/      ← SwiftUI Menu Bar App
    ├── README.md         ← App-specific docs
    ├── UI_OVERVIEW.md    ← This file
    ├── build.sh          ← Build script
    ├── check-system.sh   ← System requirements checker
    │
    ├── YakkerStreamApp.xcodeproj/
    │   └── project.pbxproj
    │
    └── YakkerStreamApp/  ← Source code
        ├── YakkerStreamAppApp.swift    ← Main app + menu bar
        ├── ContentView.swift            ← UI popover
        ├── YakkerStreamManager.swift    ← Backend controller
        ├── Info.plist                   ← App config
        ├── YakkerStreamApp.entitlements ← Permissions
        └── Assets.xcassets/             ← Icons
```

## Key Features Checklist

- [✓] Menu bar app (no dock icon)
- [✓] Connection status indicator (⚾️ with symbols)
- [✓] Start/Stop button for stream control
- [✓] Live metrics display (6 metrics)
- [✓] Auto-updating metrics (1-second poll)
- [✓] Error handling and display
- [✓] Process monitoring
- [✓] Web interface quick link
- [✓] Clean shutdown on quit
- [✓] Transient popover (auto-dismiss)
