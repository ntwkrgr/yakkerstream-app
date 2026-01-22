# UI Changes - Visual Guide

## Before (Original UI)
```
┌──────────────────────────────────────────┐
│           ⚾️ Yakker Stream               │
├──────────────────────────────────────────┤
│  Connection Status:    ● Disconnected    │
├──────────────────────────────────────────┤
│  ┌────────────────────────────────────┐  │
│  │       ▶️  Start Stream             │  │
│  └────────────────────────────────────┘  │
├──────────────────────────────────────────┤
│  Live Output                             │
│  ┌────────────────────────────────────┐  │
│  │ [Terminal output area]             │  │
│  │                                    │  │
│  └────────────────────────────────────┘  │
├──────────────────────────────────────────┤
│  Data Stream URL                         │
│  http://localhost:8000/livedata.xml      │
│                                          │
│  Quit                                    │
└──────────────────────────────────────────┘
Height: 420px
```

## After (New UI with Settings)
```
┌──────────────────────────────────────────┐
│           ⚾️ Yakker Stream               │
├──────────────────────────────────────────┤
│  Settings                                │
│                                          │
│  Yakker Domain:                          │
│  ┌────────────────────────────────────┐  │
│  │ angelosubb.yakkertech.com     [✏️] │  │ ← NEW
│  └────────────────────────────────────┘  │
│                                          │
│  Authorization Key:                      │
│  ┌────────────────────────────────────┐  │
│  │ Basic d2VidWk...              [✏️] │  │ ← NEW
│  └────────────────────────────────────┘  │
│                                          │
├──────────────────────────────────────────┤
│  Connection Status:    ● Disconnected    │
├──────────────────────────────────────────┤
│  ┌────────────────────────────────────┐  │
│  │       ▶️  Start Stream             │  │
│  └────────────────────────────────────┘  │
├──────────────────────────────────────────┤
│  Live Output                             │
│  ┌────────────────────────────────────┐  │
│  │ [Terminal output area]             │  │
│  │                                    │  │
│  └────────────────────────────────────┘  │
├──────────────────────────────────────────┤
│  Data Stream URL                         │
│  http://localhost:8000/livedata.xml      │
│                                          │
│  Quit                                    │
└──────────────────────────────────────────┘
Height: 580px (+160px)
```

## Key UI Changes

### 1. New Settings Section
- **Location**: Added at the top, immediately after the header
- **Contains**: Two text input fields with labels
- **Styling**: 
  - Headline font for "Settings" title
  - Caption font for field labels in gray
  - Rounded border text fields
  - Consistent padding and spacing

### 2. Text Field States

#### When Stream is Stopped (Editable)
```
Yakker Domain:
┌────────────────────────────────────┐
│ angelosubb.yakkertech.com     [✏️] │  ← Can edit
└────────────────────────────────────┘
```

#### When Stream is Running (Disabled)
```
Yakker Domain:
┌────────────────────────────────────┐
│ angelosubb.yakkertech.com     [🔒] │  ← Grayed out, locked
└────────────────────────────────────┘
```

### 3. Validation Feedback

#### Valid Domain
```
Yakker Domain:
┌────────────────────────────────────┐
│ mydomain.yakkertech.com       [✓]  │  ← No error
└────────────────────────────────────┘
```

#### Invalid Domain (shows error)
```
Yakker Domain:
┌────────────────────────────────────┐
│ invalid..domain                [✗]  │  ← Red border
└────────────────────────────────────┘
❌ Invalid domain format. Please enter a valid domain (e.g., yourdomain.yakkertech.com).
```

## User Interaction Flow

### First Time Launch
1. App launches with default values pre-filled
2. User sees: "angelosubb.yakkertech.com" and "Basic d2VidWk..."
3. User can either:
   - Use defaults → Click "Start Stream"
   - Change values → Enter custom domain/key → Click "Start Stream"

### Changing Settings
```
[User clicks in domain field]
    ↓
[Field becomes active, cursor appears]
    ↓
[User types new domain]
    ↓
[Setting auto-saves to UserDefaults on change]
    ↓
[User clicks "Start Stream"]
    ↓
[Validation runs]
    ↓
    ├─ Valid → Fields lock, stream starts with custom settings
    └─ Invalid → Error shown, fields remain editable
```

### Settings Persistence
```
Session 1: User enters "custom.yakkertech.com"
           ↓
           Setting saved to UserDefaults
           ↓
           User quits app
           
Session 2: User launches app again
           ↓
           Settings auto-load from UserDefaults
           ↓
           Field shows "custom.yakkertech.com" (not default)
```

## Security Features Visible to User

### 1. Keychain Storage
- Auth key stored securely in macOS Keychain
- Not visible in plain text in preferences files
- System-level encryption

### 2. Domain Validation
- Real-time feedback if domain format is invalid
- Prevents typos and injection attempts
- Clear error messages

### 3. Locked During Operation
- Settings cannot be changed mid-stream
- Prevents accidental disconnections
- Forces intentional configuration changes

## Accessibility
- All fields have clear labels
- Placeholder text provides examples
- Error messages are descriptive
- Keyboard navigation supported
- VoiceOver compatible

## Responsive Behavior
- Window resizes to 580px to accommodate new fields
- Maintains minimum width of 260px
- Scrollable if needed on smaller screens
- All elements maintain proper spacing
