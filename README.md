# Yakker Stream - Live Baseball Stats Display

Display live YakkerTech baseball data on your ProScoreboard! This program connects to YakkerTech sensors and sends real-time pitch and hit data to ProPresenter's ProScoreboard for video board display.

## What This Does

- **Captures live data** from YakkerTech sensors (exit velocity, launch angle, pitch velocity, spin rate, hit distance, hang time)
- **Displays metrics** on a simple web page you can view in any browser
- **Sends data to ProScoreboard** for professional video board integration
- **Averages duplicate readings** for accuracy
- **Smooths out noisy data** with 1-second rolling averages
- **Native macOS Menu Bar App** for easy control and monitoring (NEW!)
- **Add-on CLI dashboard** for a live ASCII readout when you do not need the browser
- **Extended metrics feed** including hit distance and hang time so the scoreboard shows ball flight, not just contact

## System Requirements

- **Operating System**: macOS (Mac) - *Tested on macOS. May work on Linux with minor modifications. Windows support not tested.*
- **Python**: Version 3.7 or higher
- **Internet**: Required for live Yakker data feed

## Quick Start (5 Minutes)

### Option A: macOS Menu Bar App (Recommended for Mac Users)

If you prefer a native Mac app with a menu bar interface:

1. Download and build the YakkerStreamApp from the `YakkerStreamApp` folder
2. Open `YakkerStreamApp.xcodeproj` in Xcode
3. Build and run the app (⌘R)
4. Install to Applications or run from anywhere - **the app is fully self-contained!**
5. Click the baseball icon (⚾️) in your menu bar
6. Click "Start Stream" to begin

**New!** The app now bundles all necessary Python scripts internally. You can install it anywhere on your Mac without worrying about where other files are located.

See [YakkerStreamApp/README.md](YakkerStreamApp/README.md) for detailed instructions.

### Option B: Command Line Interface

### Step 1: Install Python

**Mac Users:**
1. Open Terminal (find it in Applications → Utilities)
2. Check if Python 3 is installed: `python3 --version`
3. If not installed, download from: https://www.python.org/downloads/mac-osx/

### Step 2: Download This Program

1. Download this folder to your Mac (Desktop is a good place)
2. Open Terminal and navigate to the folder:
   ```bash
   cd ~/Desktop/yakker-stream
   ```

### Step 3: Start the Program

**For demo mode (no Yakker connection needed):**
```bash
./yakker.sh --demo
```

**For live Yakker data:**
```bash
./yakker.sh
```

That's it! The program will:
- ✅ Check for Python and pip
- ✅ Install necessary components (aiohttp)
- ✅ Start the data feed
- ✅ Show you the URLs to use

### Step 4: View Your Data

Open a web browser and go to: **http://localhost:8000**

You'll see a black screen with white text showing live metrics!

### Step 5: Connect to ProScoreboard

1. Open ProPresenter
2. Go to your Scoreboard
3. Click the **Edit Button** (Pencil icon)
4. Click **Settings**
5. Enable **Data Link**
6. Enter URL: `http://localhost:8000/livedata.xml`
7. Click **Turn Data On** button

Done! Your Yakker data is now feeding ProScoreboard.

### Terminal Dashboard (Optional)

Prefer to keep your eyes on the console? Launch the lightweight terminal UI:

```bash
python3 yakker_terminal.py --demo
```

Remove `--demo` to follow the live websocket feed (supply custom credentials via the flags listed below or environment variables). The dashboard refreshes every 250 ms by default and highlights pitch velo, spin rate, exit velo, launch angle, hang time, hit distance, and hit spin.

## How Data is Mapped

The program takes Yakker data and places it into ProScoreboard's baseball XML format:

| What Yakker Measures | Where It Goes in ProScoreboard | XML Field |
|---------------------|--------------------------------|-----------|
| **Exit Velocity** (mph) | Hits | `<hitting h="">` |
| **Launch Angle** (degrees) | RBI | `<hitting rbi="">` |
| **Hit Distance** (feet) | Doubles | `<hitting double="">` |
| **Hang Time** (seconds) | Triples | `<hitting triple="">` |
| **Pitch Velocity** (mph) | Earned Runs | `<pitching er="">` |
| **Spin Rate** (rpm) | Pitches | `<pitching pitches="">` |

### Why These Fields?

ProScoreboard expects baseball stats in specific XML fields. Since we're showing live sensor data (not actual game stats), we're "borrowing" these fields to display our metrics. This way, you can customize your ProScoreboard layout to show these values wherever you want on your video board.

## URLs You'll Need

| What For | URL |
|----------|-----|
| View live data in browser | http://localhost:8000 |
| ProScoreboard Data Link | http://localhost:8000/livedata.xml |
| Simple XML feed | http://localhost:8000/data.xml |

## Advanced Options

### Use a Different Port

If port 8000 is already in use:
```bash
./yakker.sh --port 9000
```

### Silence Console Updates

If you don't want to see metric updates in the terminal:
```bash
./yakker.sh --no-console
```

### Connect to Different Yakker Feed

Set environment variables before running:
```bash
export YAKKER_WS_URL="wss://your-yakker-url.com/api/v2/ws-events"
export YAKKER_AUTH_HEADER="Authorization: Basic YOUR_AUTH_TOKEN"
./yakker.sh
```

### Configuration Cheatsheet

Environment variables (override defaults without touching `yakker_stream.py`):
- `YAKKER_WS_URL` – websocket URL (defaults to the YakkerTech sample)
- `YAKKER_AUTH_HEADER` – value for the `Authorization` header (Basic, Bearer, etc.)
- `YAKKER_PORT` – HTTP port for the local server (default `8000`)
- `YAKKER_POLL_INTERVAL` – seconds between demo payload injections (default `1.0`)
- `YAKKER_CLI_REFRESH` – refresh cadence for `yakker_terminal.py` (default `0.25`)

CLI flags mirror most of these settings. Run `./yakker.sh --help` or `python3 yakker_terminal.py --help` for the latest list.

## Stopping the Program

Press **Ctrl+C** (hold Control and press C) in the Terminal window.

## Troubleshooting

### "Python 3 is required" Error
Install Python from: https://www.python.org/downloads/mac-osx/

### "pip3 is required" Error
Run this command:
```bash
python3 -m ensurepip --upgrade
```

### Can't Connect to Yakker
1. Check your internet connection
2. Verify the Yakker websocket URL is correct
3. Make sure your auth token is valid
4. Try demo mode to test: `./yakker.sh --demo`

### ProScoreboard Not Updating
1. Make sure the program is running (you should see metrics in Terminal)
2. Verify the Data Link URL is: `http://localhost:8000/livedata.xml`
3. Check that "Turn Data On" is enabled in ProScoreboard
4. Try viewing the XML in a browser to confirm it's working

### Port Already in Use
Use a different port:
```bash
./yakker.sh --port 9000
```
Then update your ProScoreboard URL to: `http://localhost:9000/livedata.xml`

## How the Data Works

### Smart Averaging
When Yakker sends multiple readings for the same event (which happens often), the program:
- Collects all readings for that event
- Ignores any "N/A" or invalid values
- Averages the valid numbers
- Shows you the final result

### Rolling Buffer
To smooth out jumpy readings:
- Keeps the last 1 second of data
- Calculates a rolling average
- Updates every second
- Removes data older than 10 seconds

### Data Freshness
- Data older than 10 seconds is considered "stale" and won't display
- The XML file updates every second with current values
- If no recent data, fields show "--"

## Want More Metrics?

This program currently tracks 6 key metrics (exit velo, launch angle, pitch velo, spin rate, hit distance, hang time), but Yakker provides dozens more! Check **YAKKER_METRICS.md** for a complete list of available data points you could add, including:
- Hit distance
- Hang time  
- Spin efficiency
- Vertical & horizontal break
- Weather conditions
- And much more!

## Files in This Folder

- **yakker.sh** - The startup script (run this!)
- **yakker_stream.py** - The main program (Python)
- **yakker_terminal.py** - Optional terminal dashboard
- **livedata.xml.template** - Baseball XML template
- **requirements.txt** - Python dependencies
- **YAKKER_METRICS.md** - Complete metrics reference
- **README.md** - This file

## Technical Details

For developers and advanced users:

- Built with Python 3 and aiohttp
- Connects via WebSocket to YakkerTech API
- Serves HTTP endpoints on localhost
- Updates livedata.xml every second
- Implements duplicate event aggregation
- Uses rolling 1-second buffer for smoothing
- Filters invalid/stale data automatically

## Support

If you run into issues:
1. Check the Troubleshooting section above
2. Try demo mode: `./yakker.sh --demo`
3. Make sure Python 3 is installed
4. Verify your Yakker credentials

## License

This is a custom program for displaying YakkerTech data on ProScoreboard video boards.
