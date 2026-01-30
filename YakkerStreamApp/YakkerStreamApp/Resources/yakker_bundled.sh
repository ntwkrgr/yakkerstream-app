#!/usr/bin/env bash
# Bundled version of yakker.sh that runs from within the app bundle
set -e

# Get the directory where this script is located (inside the app bundle)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Parse port from command line arguments or use default
PORT="${YAKKER_PORT:-8000}"
next_is_port=false
for arg in "$@"; do
  if [[ "$arg" =~ ^--port ]]; then
    next_is_port=true
  elif [[ "$next_is_port" == "true" ]]; then
    if [[ "$arg" =~ ^[0-9]+$ ]]; then
      PORT="$arg"
      break
    fi
  fi
done

echo "🔎 Checking prerequisites..."
if ! command -v python3 >/dev/null 2>&1; then
  echo "❌ Python 3 is required. Please install it from https://www.python.org/downloads/mac-osx/ and re-run this script."
  exit 1
fi

if ! command -v pip3 >/dev/null 2>&1; then
  echo "❌ pip3 is required. You can install it with: python3 -m ensurepip --upgrade"
  exit 1
fi

# Create a temporary working directory for the virtual environment and output files
WORK_DIR="$HOME/.yakker-stream"
mkdir -p "$WORK_DIR"

if [ ! -d "$WORK_DIR/.venv" ]; then
  echo "🌱 Creating local virtual environment..."
  python3 -m venv "$WORK_DIR/.venv"
fi

echo "📦 Installing dependencies..."
source "$WORK_DIR/.venv/bin/activate"

# Install dependencies with error checking
if ! pip3 install --upgrade pip 2>&1 | grep -q "Successfully installed\|already satisfied\|Requirement already satisfied"; then
  echo "⚠️  Warning: pip upgrade may have failed, continuing..."
fi

if ! pip3 install -r "$SCRIPT_DIR/requirements.txt" 2>&1; then
  echo "❌ Failed to install Python dependencies"
  exit 1
fi

echo ""
echo "✅ Ready! Starting Yakker stream..."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Web Display:       http://localhost:${PORT}"
echo "📡 Data Link URL:     http://localhost:${PORT}/livedata.xml"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 ProScoreboard Setup Instructions:"
echo "   1. Open ProPresenter and go to your Scoreboard"
echo "   2. Click the Edit Button (Pencil icon)"
echo "   3. Go to Settings"
echo "   4. Enable 'Data Link'"
echo "   5. Enter URL: http://localhost:${PORT}/livedata.xml"
echo "   6. Click 'Turn Data On' button"
echo ""
echo "🎯 Yakker Data Mapping:"
echo "   • Exit Velocity → Hits (h)"
echo "   • Launch Angle → RBI"
echo "   • Hit Distance → Doubles (double)"
echo "   • Hangtime → Triples (triple)"
echo "   • Pitch Velocity → Earned Runs (er)"
echo "   • Spin Rate → Pitches"
echo ""
echo "💡 Tip: Use --demo flag for sample data without Yakker connection"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📡 Connecting to Yakker data feed..."
echo ""

# Run yakker_stream.py from the work directory so it can write livedata.xml there
# Pass the template path as an environment variable
cd "$WORK_DIR"
export YAKKER_TEMPLATE_PATH="$SCRIPT_DIR/livedata.xml.template"
python3 "$SCRIPT_DIR/yakker_stream.py" "$@"
