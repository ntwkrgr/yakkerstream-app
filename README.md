# Yakker Stream - Live Baseball Stats Display

> **Version 1.0** - Feature complete release

Display live YakkerTech baseball data on your ProScoreboard! This Mac app connects to YakkerTech sensors and sends real-time pitch and hit data to ProPresenter's ProScoreboard for video board display.

## What This Does

- **Captures live data** from YakkerTech sensors (exit velocity, launch angle, pitch velocity, spin rate, hit distance, hang time)
- **Displays metrics** in a native Mac app and web browser
- **Sends data to ProScoreboard** for professional video board integration
- **Configurable HTTP port** for flexible network setups
- **Secure credential storage** using macOS Keychain

## System Requirements

- **Operating System**: macOS 13.0 (Ventura) or later
- **Python**: Version 3.7 or higher (pre-installed on most Macs)
- **Internet**: Required for live Yakker data feed

## Installation

### Step 1: Download the App

1. Go to the [Releases](../../releases) page
2. Download the latest `YakkerStreamApp.zip`
3. Unzip the file (double-click it)

### Step 2: Allow the App to Run

Since this app is distributed via GitHub (not the Mac App Store), macOS will initially block it. Here's how to allow it:

**Method 1: Right-Click to Open (Recommended)**
1. Locate `YakkerStreamApp.app` in Finder
2. **Right-click** (or Control-click) on the app
3. Select **"Open"** from the menu
4. Click **"Open"** in the dialog that appears
5. The app will now open and you won't need to do this again

**Method 2: System Settings**
1. Try to open the app normally (double-click)
2. If macOS blocks it, open **System Settings** → **Privacy & Security**
3. Scroll down to find the message about YakkerStreamApp being blocked
4. Click **"Open Anyway"**
5. Enter your password if prompted

**Method 3: Terminal (Advanced Users)**
If the above methods don't work, open Terminal and run:
```bash
xattr -cr /path/to/YakkerStreamApp.app
```
Replace `/path/to/` with the actual location of the app.

### Step 3: First-Time Setup

1. Launch the app
2. Click **"How to Get Credentials"** for instructions on finding your Yakker domain and authorization key
3. Enter your **Yakker Domain** (e.g., `yourdomain.yakkertech.com`)
4. Enter your **Authorization Key** (e.g., `Basic YOUR_AUTH_TOKEN`)
5. Your settings are saved automatically

## Using the App

1. **Start the Stream**: Click the "Start Stream" button
2. **View Metrics**: Live metrics appear in the app window once connected
3. **Web Interface**: Click the localhost link to view data in your browser
4. **Stop the Stream**: Click "Stop Stream" when finished

### Connection Status Indicators

| Icon | Meaning |
|------|---------|
| ● Green | Connected and running |
| ● Yellow | Connecting |
| ● Gray | Disconnected |
| ● Red | Error |

## Connecting to ProScoreboard

1. Open ProPresenter
2. Go to your Scoreboard
3. Click the **Edit Button** (Pencil icon)
4. Click **Settings**
5. Enable **Data Link**
6. Enter URL: `http://localhost:8000/livedata.xml`
7. Click **Turn Data On**

Done! Your Yakker data is now feeding ProScoreboard.

## How Data is Mapped

The program maps Yakker sensor data to ProScoreboard's baseball XML format:

| Yakker Metric | ProScoreboard Field | XML Field |
|---------------|---------------------|-----------|
| Exit Velocity (mph) | Visitor Hits | `<hitting h="">` |
| Launch Angle (degrees) | Visitor RBI | `<hitting rbi="">` |
| Hit Distance (feet) | Visitor Doubles | `<hitting double="">` |
| Hang Time (seconds) | Visitor Triples | `<hitting triple="">` |
| Pitch Velocity (mph) | Visitor Earned Runs | `<pitching er="">` |
| Spin Rate (rpm) | Visitor Pitches | `<pitching pitches="">` |

### Why These Fields?

ProScoreboard expects baseball stats in specific XML fields. Since we're showing live sensor data (not actual game stats), we "borrow" these fields to display our metrics. Customize your ProScoreboard layout to show these values wherever you want on your video board.

## URLs

The following URLs are available when the stream is running (default port 8000, configurable in app settings):

| Purpose | URL |
|---------|-----|
| View live data in browser | http://localhost:8000 |
| ProScoreboard Data Link | http://localhost:8000/livedata.xml |
| Simple XML feed | http://localhost:8000/data.xml |

> **Note:** If you change the HTTP port in the app settings, replace 8000 with your configured port number.

## Troubleshooting

### App Won't Open / "Unidentified Developer" Error

See **Step 2** above for instructions on allowing the app to run.

### "Backend process stopped unexpectedly"

This can happen if:
- Python is not installed or not in the PATH
- Required Python dependencies are missing

**Solution**: Open Terminal and run:
```bash
python3 --version
```
If Python isn't installed, download it from: https://www.python.org/downloads/mac-osx/

### Connection Status Shows Error

1. Check your internet connection
2. Verify your Yakker domain is correct
3. Make sure your authorization key is valid (keys can expire)
4. Try obtaining a fresh authorization key from your browser's developer tools

### ProScoreboard Not Updating

1. Verify the app shows "Connected" status
2. Check that the Data Link URL is: `http://localhost:8000/livedata.xml`
3. Ensure "Turn Data On" is enabled in ProScoreboard
4. Try viewing http://localhost:8000/livedata.xml in a browser to confirm data is flowing

### Port Already in Use

If another application is using the default port (8000), you can either:
- Change the HTTP port in the app's Configuration settings
- Stop the other application using that port

The app will automatically attempt to free the port when starting, but if it cannot, try specifying a different port.

## Building from Source

For developers who want to build the app themselves:

1. Clone this repository
2. Open `YakkerStreamApp/YakkerStreamApp.xcodeproj` in Xcode
3. Build and run (⌘R) or archive for distribution

See [YakkerStreamApp/README.md](YakkerStreamApp/README.md) for detailed development instructions.

## Additional Resources

- **YAKKER_METRICS.md** - Complete reference of all available Yakker data points and the six metrics mapped in Version 1
- **Yakker-Stream-How-To.pdf** - Visual guide for setup (if available)

## Version History

### Version 1.0
- Six core metrics: Exit Velocity, Launch Angle, Hit Distance, Hang Time, Pitch Velocity, Spin Rate
- Native macOS app with SwiftUI interface
- Configurable HTTP port
- Secure credential storage in macOS Keychain
- Live terminal output display
- Copy URL to clipboard feature

## License

This is a custom program for displaying YakkerTech data on ProScoreboard video boards.
