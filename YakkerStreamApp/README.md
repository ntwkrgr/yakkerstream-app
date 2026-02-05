# Yakker Stream macOS App

> **Version 1.0** - Feature complete release

A native macOS application for controlling and monitoring the Yakker Stream backend.

## Features

- **User-Configurable Credentials**: Enter your own Yakker domain and authorization key
- **Built-in Help**: Step-by-step guide to obtain your credentials
- **Configurable HTTP Port**: Change the default port (8000) as needed
- **Secure Storage**: Authorization key stored in macOS Keychain
- **Connection Status Indicator**: Real-time visual feedback on connection status
  - ● Green - Connected and running
  - ● Yellow - Connecting
  - ● Gray - Disconnected
  - ● Red - Error
- **Start/Stop Control**: Easy button to start and stop the stream
- **Live Metrics Display**: View real-time baseball metrics:
  - Exit Velocity (mph)
  - Launch Angle (degrees)
  - Pitch Velocity (mph)
  - Spin Rate (rpm)
  - Hit Distance (ft)
  - Hang Time (sec)
- **Live Terminal Output**: View backend logs in real-time
- **Copy URL Button**: Quickly copy the data stream URL to clipboard
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

2. **Configure settings** (first time or to change):
   - Click "How to Get Credentials" button for detailed instructions
   - Enter your Yakker domain (e.g., "yourdomain.yakkertech.com")
   - Enter your authorization key (e.g., "Basic YOUR_AUTH_TOKEN")
   - Settings are saved automatically and persist between launches

3. **Start the stream**: Click the "Start Stream" button
   - The app will automatically start the Python backend with your configured settings
   - Connection status will update to show when it's ready

4. **View metrics**: Live metrics will appear once the stream is running

5. **Open web interface**: Click the localhost:8000 link to view the full web interface

7. **Stop the stream**: Click the "Stop Stream" button

6. **Stop the stream**: Click the "Stop Stream" button

7. **Quit**: Click "Quit" at the bottom of the window

## Technical Details

### Architecture

The app consists of three main components:

1. **YakkerStreamAppApp.swift**: Main app entry point
2. **ContentView.swift**: SwiftUI interface for the app window
3. **YakkerStreamManager.swift**: Business logic for managing the Python backend

### Backend Integration

- Launches the Python backend using the existing `yakker.sh` script
- Uses custom Yakker domain and authorization key from user settings
- Polls `http://localhost:8000/data.xml` every second for metrics
- Monitors process status to detect crashes or unexpected exits

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
- The yakker.sh script is not executable
- Required Python dependencies are missing

Run the backend manually first to diagnose:
```bash
cd /path/to/yakker-stream
./yakker.sh --demo
```

### "Please configure your Yakker domain and authorization key"

This means you need to enter your credentials:
- Click "How to Get Credentials" button in the app for detailed instructions
- Enter your Yakker domain and authorization key in the Settings section

### Metrics not updating

- Verify the backend is running (check Activity Monitor for Python processes)
- Test the endpoint directly: open http://localhost:8000 in a browser
- Check Console.app for error messages from the app

## License

Part of the Yakker Stream project for displaying YakkerTech baseball data.
