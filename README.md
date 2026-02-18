# Yakker Stream

> **Version 1.0** — Native macOS app for displaying live YakkerTech baseball sensor data on ProScoreboard video boards.

Yakker Stream connects to YakkerTech sensors via WebSocket, aggregates real-time pitch and hit data, and serves it over HTTP so ProPresenter's ProScoreboard can pull it onto your video board.

---

## What It Does

- **Captures live sensor data** — exit velocity, launch angle, pitch velocity, spin rate, hit distance, hang time
- **Serves a ProScoreboard data link** at `http://localhost:PORT/livedata.xml`
- **Shows a live web dashboard** at `http://localhost:PORT` for in-browser monitoring
- **Filters stale and low-quality readings** with configurable timeout and minimum exit velocity
- **Optionally imports player rosters** from a Sidearm Sports XML feed
- **Stores credentials securely** in the macOS Keychain

---

## System Requirements

| Requirement | Minimum |
|-------------|---------|
| macOS | 13.0 (Ventura) or later |
| Python | 3.7 or higher |
| pip3 | Required for dependency install |
| Internet | Required for live Yakker data |

Python is pre-installed on most modern Macs. To verify: `python3 --version`

---

## Installation

### Step 1: Download

1. Go to the [Releases](../../releases) page
2. Download the latest `YakkerStreamApp.zip`
3. Unzip and move `YakkerStreamApp.app` to your Applications folder

### Step 2: Allow the App to Run

macOS will block the app on first launch since it's not from the App Store.

**Recommended — Right-click to open:**
1. Right-click (or Control-click) `YakkerStreamApp.app`
2. Select **Open**
3. Click **Open** in the confirmation dialog
4. You won't need to do this again

**Alternative — System Settings:**
1. Try to open the app; macOS will block it
2. Open **System Settings → Privacy & Security**
3. Find the blocked app message and click **Open Anyway**

**Advanced — Terminal:**
```bash
xattr -cr /path/to/YakkerStreamApp.app
```

### Step 3: Enter Your Credentials

1. Launch the app — settings expand automatically on first run
2. Click **"How to Get Credentials"** for step-by-step instructions
3. Enter your **Yakker Domain** (e.g., `yourdomain.yakkertech.com`)
4. Enter your **Authorization Key** (e.g., `Basic YOUR_AUTH_TOKEN`)
5. Settings save automatically

> Your authorization key is stored encrypted in the macOS Keychain, not in plain text.

---

## Using the App

1. Click **Start Stream** — the backend launches and connects to YakkerTech
2. Watch the **terminal output** panel for live connection logs
3. The **status indicator** shows your connection state:

| Indicator | Meaning |
|-----------|---------|
| ● Green | Connected and streaming |
| ● Yellow | Connecting… |
| ● Gray | Stopped |
| ● Red | Error |

4. Click **Copy URL** to copy the ProScoreboard data link to your clipboard
5. Click **Stop Stream** when you're done

---

## Settings

Open the gear icon (⚙) to configure. Settings are disabled while the stream is running.

| Setting | Default | Description |
|---------|---------|-------------|
| Yakker Domain | — | Your YakkerTech subdomain (e.g., `yourteam.yakkertech.com`) |
| Authorization Key | — | Base64 auth header from browser dev tools |
| HTTP Port | 80 | Port for the local data server |
| Stale Timeout | 10s | Seconds before a metric is considered expired and cleared |
| Min Exit Velocity Filter | On / 65 mph | Ignores soft throws (e.g., catcher throwbacks) below the threshold |

### Sidearm Sports Integration (Optional)

Yakker Stream can import your player roster from a Sidearm Sports XML feed to enrich the data display. Configure a **URL** (fetched every 30 seconds) or a **local file path** under the Player Info section in settings.

---

## Connecting to ProScoreboard

1. Open ProPresenter and navigate to your Scoreboard
2. Click the **Edit** (pencil) icon → **Settings**
3. Enable **Data Link**
4. Set the URL to: `http://localhost:80/livedata.xml`
   *(Replace `80` with your configured port if you changed it)*
5. Click **Turn Data On**

Yakker data will now feed your video board in real time.

---

## Data Mapping

ProScoreboard expects standard baseball stat fields in its XML. Since we're displaying sensor data rather than game stats, Yakker Stream maps each metric to an available field:

| Yakker Metric | ProScoreboard Field | XML Attribute |
|---------------|---------------------|---------------|
| Exit Velocity (mph) | Visitor Hits | `<hitting h="">` |
| Launch Angle (°) | Visitor RBI | `<hitting rbi="">` |
| Hit Distance (ft) | Visitor Doubles | `<hitting double="">` |
| Hang Time (sec) | Visitor Triples | `<hitting triple="">` |
| Pitch Velocity (mph) | Visitor Earned Runs | `<pitching er="">` |
| Spin Rate (rpm) | Visitor Pitches | `<pitching pitches="">` |

Customize your ProScoreboard layout to label and position these fields however you like on the video board.

---

## Available Endpoints

While the stream is running (default port 80):

| URL | Description |
|-----|-------------|
| `http://localhost:80` | Live web dashboard with all metrics |
| `http://localhost:80/livedata.xml` | ProScoreboard data link (baseball XML format) |
| `http://localhost:80/data.xml` | Simple XML feed |

---

## Troubleshooting

### App won't open / "Unidentified Developer" error
See [Step 2](#step-2-allow-the-app-to-run) above.

### "Backend process stopped unexpectedly"
- Python 3 is not installed or not in PATH → [Download Python](https://www.python.org/downloads/mac-osx/)
- pip3 is missing → install via `python3 -m ensurepip`
- Script permissions issue → run `chmod +x` on the app's support scripts

### Connection status shows Error
1. Verify your internet connection
2. Confirm the Yakker domain is reachable in a browser
3. Authorization keys can expire — re-extract a fresh key from your browser's Network tab in developer tools

### ProScoreboard not updating
1. Confirm the app shows ● Green status
2. Open `http://localhost:80/livedata.xml` in a browser — if data appears there, the issue is in ProScoreboard's Data Link config
3. Verify **Turn Data On** is enabled and the URL matches exactly

### Port already in use
The app automatically attempts to free the configured port on startup. If it can't:
- Change the HTTP Port in settings to an unused port (e.g., `8001`)

### Metrics clearing too quickly / not clearing fast enough
Adjust the **Stale Timeout** in settings. Lower values clear stale readings faster; higher values keep the last reading displayed longer between pitches.

### Soft throws showing up as hits
Enable the **Min Exit Velocity Filter** in settings and set the threshold (default 65 mph). Readings below the threshold are ignored.

---

## Building from Source

```bash
git clone <this repo>
cd yakkerstream-app/YakkerStreamApp
./build.sh
```

The compiled app will be at `./build/Build/Products/Release/YakkerStreamApp.app`.

To verify system requirements before building:
```bash
./check-system.sh
```

For detailed development documentation, see [YakkerStreamApp/README.md](YakkerStreamApp/README.md).

---

## Additional Resources

- **[YAKKER_METRICS.md](YAKKER_METRICS.md)** — Full reference of all available Yakker data points and the six metrics mapped in Version 1.0
- **[YakkerStreamApp/UI_OVERVIEW.md](YakkerStreamApp/UI_OVERVIEW.md)** — UI component documentation
- **[YakkerStreamApp/VISUAL_GUIDE.md](YakkerStreamApp/VISUAL_GUIDE.md)** — Architecture and file structure diagrams

---

## Version History

### Version 1.0
- Six core metrics: Exit Velocity, Launch Angle, Pitch Velocity, Spin Rate, Hit Distance, Hang Time
- Native macOS SwiftUI app (macOS 13.0+)
- Configurable HTTP port, stale timeout, and minimum exit velocity filter
- Optional Sidearm Sports XML player roster integration
- Secure authorization key storage in macOS Keychain
- Live terminal output panel with 200-line scrollback
- Copy-to-clipboard for ProScoreboard data link URL
- Auto-expands settings on first launch when credentials are missing
- Interactive web dashboard at `http://localhost:PORT`

---

## License

Custom software for displaying YakkerTech sensor data on ProScoreboard video boards.
