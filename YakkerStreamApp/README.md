# Yakker Stream macOS App

A native macOS application for controlling and monitoring the Yakker Stream backend.

## Features

- **User-Configurable Credentials**: Enter your own Yakker domain and authorization key
- **Built-in Help**: Step-by-step guide to obtain your credentials
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
- **Fully Self-Contained**: All Python scripts and dependencies bundled in the app

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later (for building)
- Python 3.7+ (will be used at runtime to execute the backend)

## Installation

### Simple Installation (Recommended)

The app is now fully self-contained and can be installed anywhere on your Mac:

1. Build the app using the build script (see "Building the App" below)
2. Copy `YakkerStreamApp.app` to your `/Applications` folder, or run it from anywhere
3. Double-click to launch - no need to worry about script locations!

**The app includes everything it needs:**
- Python backend script (`yakker_stream.py`)
- Configuration template (`livedata.xml.template`)
- Dependencies list (`requirements.txt`)
- Startup script (`yakker_bundled.sh`)

All files are bundled inside the app, so you can move it anywhere without breaking functionality.

## Building the App

1. Open the project in Xcode:
   ```bash
   cd YakkerStreamApp
   open YakkerStreamApp.xcodeproj
   ```

2. Select the "YakkerStreamApp" scheme in Xcode

3. Build and run (⌘R) or archive for distribution

**Or use the build script:**
```bash
cd YakkerStreamApp
./build.sh
```

The built app will be in `./build/Build/Products/Release/YakkerStreamApp.app`

## Using the App

1. **Launch the app**: Double-click YakkerStreamApp anywhere on your Mac

2. **Configure settings** (first time or to change):
   - Click "How to Get Credentials" button for detailed instructions
   - Enter your Yakker domain (e.g., "yourdomain.yakkertech.com")
   - Enter your authorization key (e.g., "Basic YOUR_AUTH_TOKEN")
   - Settings are saved automatically and persist between launches

3. **Start the stream**: Click the "Start Stream" button
   - The app will automatically set up Python dependencies on first run (stored in `~/.yakker-stream`)
   - Connection status will update to show when it's ready

4. **View metrics**: Live metrics will appear once the stream is running

5. **Open web interface**: Click the localhost:8000 link to view the full web interface

6. **Stop the stream**: Click the "Stop Stream" button

7. **Quit**: Click "Quit" at the bottom of the window

## Technical Details

### Architecture

The app consists of three main components:

1. **YakkerStreamAppApp.swift**: Main app entry point
2. **ContentView.swift**: SwiftUI interface for the app window
3. **YakkerStreamManager.swift**: Business logic for managing the Python backend

### Backend Integration

- All Python scripts are bundled inside the app's Resources folder
- Virtual environment is created in `~/.yakker-stream` on first run
- Launches the Python backend using the bundled `yakker_bundled.sh` script
- Uses custom Yakker domain and authorization key from user settings
- Polls `http://localhost:8000/data.xml` every second for metrics
- Monitors process status to detect crashes or unexpected exits

### What's Bundled

The app includes these resources in its bundle:
- `yakker_bundled.sh` - Startup script that handles Python environment setup
- `yakker_stream.py` - Main Python backend that connects to Yakker and serves data
- `livedata.xml.template` - ProScoreboard XML template
- `requirements.txt` - Python dependencies (aiohttp)

## Customization

### Changing Settings

The app stores your Yakker domain in UserDefaults and authorization key in macOS Keychain. To reset:

```bash
defaults delete com.yakkerstream.YakkerStreamApp yakkerDomain
```

Or simply clear the fields in the app UI and enter new values.

### Change Port

The app currently uses port 8000. To change it, update the port in:
- `YakkerStreamManager.swift` (fetchMetrics method)
- `ContentView.swift` (web link)

## Troubleshooting

### "Backend process stopped unexpectedly"

This can happen if:
- Python is not installed or not in the PATH
- Required Python dependencies failed to install
- Port 8000 is already in use

First-time setup requires internet to download Python dependencies (aiohttp).

### "Bundled script not found in app resources"

This means the app was not built correctly. Rebuild using Xcode or the build.sh script to ensure all resources are included in the bundle.

### "Please configure your Yakker domain and authorization key"

This means you need to enter your credentials:
- Click "How to Get Credentials" button in the app for detailed instructions
- Enter your Yakker domain and authorization key in the Settings section

### Metrics not updating

- Verify the backend is running (check Activity Monitor for Python processes)
- Test the endpoint directly: open http://localhost:8000 in a browser
- Check Console.app for error messages from the app

### Permission Issues

If macOS blocks the app from running:
1. Right-click the app and select "Open"
2. Click "Open" in the security dialog
3. Or go to System Settings > Privacy & Security and allow the app

## License

Part of the Yakker Stream project for displaying YakkerTech baseball data.
