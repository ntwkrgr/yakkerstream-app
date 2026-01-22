# Yakker Stream macOS Menu Bar App

A native macOS menu bar application for controlling and monitoring the Yakker Stream backend.

## Features

- **Menu Bar Interface**: Lives in your menu bar - no dock icon
- **Connection Status Indicator**: Real-time visual feedback on connection status
  - ⚾️ ✓ - Connected and running
  - ⚾️ ... - Connecting
  - ⚾️ ✗ - Disconnected
  - ⚾️ ⚠️ - Error
- **Start/Stop Control**: Easy button to start and stop the stream
- **Live Metrics Display**: View real-time baseball metrics:
  - Exit Velocity (mph)
  - Launch Angle (degrees)
  - Pitch Velocity (mph)
  - Spin Rate (rpm)
  - Hit Distance (ft)
  - Hang Time (sec)
- **Web Interface Link**: Quick access to the browser interface

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later (for building)
- Python 3.7+ (for the backend)

## Installation

### Important: App Placement

The app needs to find the `yakker.sh` script to launch the backend. You have two options:

**Option 1 (Recommended)**: Place the entire `yakker-stream` folder in one of these locations:
- `~/yakker-stream`
- `~/Desktop/yakker-stream`
- `~/Documents/yakker-stream`
- `~/Downloads/yakker-stream`

**Option 2**: Keep the app bundle next to `yakker.sh` in the repository folder.

## Building the App

1. Open the project in Xcode:
   ```bash
   cd YakkerStreamApp
   open YakkerStreamApp.xcodeproj
   ```

2. Select the "YakkerStreamApp" scheme in Xcode

3. Build and run (⌘R) or archive for distribution

## Using the App

1. **Launch the app**: Double-click YakkerStreamApp in your Applications folder

2. **Access the menu**: Click the baseball icon (⚾️) in your menu bar

3. **Start the stream**: Click the "Start Stream" button
   - The app will automatically start the Python backend in demo mode
   - Connection status will update to show when it's ready

4. **View metrics**: Live metrics will appear in the menu once the stream is running

5. **Open web interface**: Click the localhost:8000 link to view the full web interface

6. **Stop the stream**: Click the "Stop Stream" button

7. **Quit**: Click "Quit" at the bottom of the menu

## Technical Details

### Architecture

The app consists of three main components:

1. **YakkerStreamAppApp.swift**: Main app entry point with menu bar setup
2. **ContentView.swift**: SwiftUI interface for the menu popover
3. **YakkerStreamManager.swift**: Business logic for managing the Python backend

### Backend Integration

- Launches the Python backend using the existing `yakker.sh` script
- Runs in demo mode by default for testing
- Polls `http://localhost:8000/data.xml` every second for metrics
- Monitors process status to detect crashes or unexpected exits

### Menu Bar Behavior

- The app uses `LSUIElement = YES` in Info.plist to hide from the dock
- Status bar icon updates based on connection state
- Popover shows on click and dismisses when clicking outside

## Customization

### Change Backend Mode

To use live Yakker data instead of demo mode, edit `YakkerStreamManager.swift`:

```swift
// Change this line in startStream():
let script = """
cd "\(repoPath)" && ./yakker.sh --demo
"""

// To this:
let script = """
cd "\(repoPath)" && ./yakker.sh
"""
```

### Change Port

The app currently uses port 8000. To change it, update the port in:
- `YakkerStreamManager.swift` (fetchMetrics method)
- `ContentView.swift` (web link)

## Troubleshooting

### "Backend process stopped unexpectedly"

This can happen if:
- Python is not installed or not in the PATH
- The yakker.sh script is not executable
- Required Python dependencies are missing

Run the backend manually first to diagnose:
```bash
cd /path/to/yakker-stream
./yakker.sh --demo
```

### Menu bar icon doesn't appear

- Check System Preferences > Dock & Menu Bar > Clock > Show date and time
- If your menu bar is full, the icon might be hidden under the "»" overflow menu

### Metrics not updating

- Verify the backend is running (check Activity Monitor for Python processes)
- Test the endpoint directly: open http://localhost:8000 in a browser
- Check Console.app for error messages from the app

## License

Part of the Yakker Stream project for displaying YakkerTech baseball data.
