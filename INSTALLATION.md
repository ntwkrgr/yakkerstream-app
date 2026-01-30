# Yakker Stream App - Standalone Installation Guide

## Overview

The Yakker Stream macOS app is now fully self-contained and can be installed anywhere on your Mac without requiring external Python scripts or configuration files.

## What's Changed

### Before
- Required `yakker.sh` and `yakker_stream.py` to be in specific locations
- Had to keep app near the Python scripts
- Installation was location-dependent

### After
- All scripts bundled inside the app
- Install anywhere (Applications, Desktop, Documents, etc.)
- True drag-and-drop installation
- Works from any location

## Installation Steps

### 1. Build the App

```bash
cd YakkerStreamApp
./build.sh
```

Or open in Xcode and build manually (⌘R).

### 2. Install the App

Copy the built app to your desired location:

```bash
# Install to Applications (recommended)
cp -r ./build/Build/Products/Release/YakkerStreamApp.app /Applications/

# Or keep it anywhere else
mv ./build/Build/Products/Release/YakkerStreamApp.app ~/Desktop/
```

### 3. Launch the App

Double-click `YakkerStreamApp.app` to launch.

## First Run

When you launch the app for the first time:

1. **Python Check**: The app verifies Python 3 is installed
2. **Environment Setup**: Creates a virtual environment in `~/.yakker-stream`
3. **Dependencies**: Installs aiohttp and other Python dependencies
4. **Ready**: App is ready to use

This one-time setup takes about 30 seconds and requires internet access.

## Configuration

1. Click **"How to Get Credentials"** in the app for instructions
2. Enter your Yakker domain (e.g., "yourdomain.yakkertech.com")
3. Enter your authorization key
4. Click **"Start Stream"**

Settings are saved securely in macOS Keychain and persist between launches.

## What's Bundled Inside

The app includes:
- `yakker_stream.py` - Main Python backend
- `livedata.xml.template` - ProScoreboard XML template
- `requirements.txt` - Python dependencies
- `yakker_bundled.sh` - Startup script

All files are in the app bundle's Resources folder.

## File Locations

- **App Bundle**: Wherever you place the .app file (read-only)
- **Virtual Environment**: `~/.yakker-stream/.venv` (installed packages)
- **Output Files**: `~/.yakker-stream/livedata.xml` (writable)
- **Settings**: macOS Keychain (secure storage)

## Uninstallation

To completely remove the app:

1. Delete `YakkerStreamApp.app`
2. Remove virtual environment: `rm -rf ~/.yakker-stream`
3. Clear settings: `defaults delete com.yakkerstream.YakkerStreamApp`

## Troubleshooting

### "Python 3 is required"
Install Python from https://www.python.org/downloads/mac-osx/

### "Failed to install Python dependencies"
- Check internet connection
- Ensure pip is working: `python3 -m pip --version`
- Try manually: `pip3 install aiohttp`

### Permission Issues
If macOS blocks the app:
1. Right-click and select "Open"
2. Or: System Settings > Privacy & Security > Allow

### Port Already in Use
The app automatically cleans up port 8000. If issues persist, restart the app or use Activity Monitor to stop Python processes.

## Benefits

✅ Install anywhere on your Mac
✅ No script placement requirements
✅ Works from read-only locations
✅ Secure credential storage
✅ Self-updating dependencies
✅ Isolated virtual environment

## Support

For issues or questions:
1. Check Console.app for error messages
2. Look for "YakkerStreamApp" logs
3. Verify Python is installed: `python3 --version`
4. Test manually: `cd ~/.yakker-stream && source .venv/bin/activate`
