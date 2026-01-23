# Implementation Summary: User-Configurable Yakker Domain and Authorization Key

## Overview
This implementation allows users to input their own Yakker domain and authorization key via the macOS YakkerStreamApp UI, replacing the previously hard-coded values.

## Changes Made

### 1. User Interface (ContentView.swift)
- Added a "Settings" section with two text fields:
  - **Yakker Domain**: Input field for custom domain (e.g., "yourdomain.yakkertech.com")
  - **Authorization Key**: Input field for custom auth key (e.g., "Basic YOUR_AUTH_TOKEN")
- Text fields are disabled while the stream is running to prevent mid-stream configuration changes
- Updated window height from 420 to 580 pixels to accommodate new UI elements

### 2. Settings Storage (YakkerStreamManager.swift)
- Added two `@Published` properties:
  - `yakkerDomain`: Stored in UserDefaults (non-sensitive)
  - `authKey`: Stored securely in macOS Keychain (sensitive credential)
- Implemented `KeychainHelper` class for secure credential storage with methods:
  - `save(key:value:)`: Stores credentials in Keychain
  - `load(key:)`: Retrieves credentials from Keychain
  - `delete(key:)`: Removes credentials from Keychain
- Settings persist between app launches

### 3. Security Features
- **Keychain Storage**: Authorization key is stored in macOS Keychain instead of UserDefaults for secure credential storage
- **Domain Validation**: Regex validation ensures domain format is valid and prevents injection attacks
  - Pattern: `^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.[a-zA-Z]{2,}(\\.[a-zA-Z]{2,})?$`
  - Allows standard domain formats with optional subdomains
- **Shell Escaping**: All user inputs are properly escaped using single-quote shell escaping before being passed to bash commands
- **Error Handling**: Improved error messages and validation feedback

### 4. Backend Integration (YakkerStreamManager.swift)
- Modified `startStream()` method to:
  - Validate domain format before starting
  - Build WebSocket URL from user-provided domain: `wss://{domain}/api/v2/ws-events`
  - Construct auth header: `Authorization: {authKey}`
  - Pass both values as command-line arguments to yakker.sh: `--ws-url` and `--auth-header`
- No changes needed to Python backend (yakker_stream.py) as it already supports these arguments

### 5. Documentation Updates
- **YakkerStreamApp/README.md**: Added configuration instructions and features
- **YakkerStreamApp/UI_OVERVIEW.md**: Updated to show settings section and interaction flow
- **YakkerStreamApp/VISUAL_GUIDE.md**: Updated popover interface diagram to include settings

## Default Values
- **Yakker Domain**: `angelosubb.yakkertech.com` (original hard-coded value)
- **Authorization Key**: `Basic d2VidWk6Q3J1Y2lhbCBTaHVmZmxlIE5ldmVy` (original hard-coded value)

## User Experience
1. Launch app → Settings fields are pre-filled with saved values (or defaults)
2. User can modify domain and auth key at any time when stream is stopped
3. Click "Start Stream" → Settings are locked, backend launches with custom configuration
4. Click "Stop Stream" → Settings become editable again
5. Changes are saved automatically and persist across app restarts

## Security Considerations
- ✅ Sensitive credentials stored in Keychain, not UserDefaults
- ✅ Domain input validated with regex to prevent injection
- ✅ All user inputs properly escaped before shell execution
- ✅ No force unwrapping that could cause crashes
- ✅ Clear error messages for invalid input

## Testing Recommendations
1. Test with default values to ensure backward compatibility
2. Test with custom domain and auth key to verify proper connection
3. Test domain validation with various invalid inputs
4. Verify Keychain storage and retrieval across app restarts
5. Test that settings cannot be changed while stream is running
6. Verify shell escaping with special characters in inputs

## Files Modified
- `YakkerStreamApp/YakkerStreamApp/YakkerStreamManager.swift` (84 lines added)
- `YakkerStreamApp/YakkerStreamApp/ContentView.swift` (24 lines added)
- `YakkerStreamApp/YakkerStreamApp/YakkerStreamAppApp.swift` (1 line changed)
- `YakkerStreamApp/README.md` (documentation updates)
- `YakkerStreamApp/UI_OVERVIEW.md` (documentation updates)
- `YakkerStreamApp/VISUAL_GUIDE.md` (documentation updates)

## Backward Compatibility
The implementation maintains full backward compatibility:
- If no custom values are set, the app uses the original hard-coded defaults
- Existing users will see the default values pre-filled in the settings UI
- No breaking changes to the Python backend or command-line interface
