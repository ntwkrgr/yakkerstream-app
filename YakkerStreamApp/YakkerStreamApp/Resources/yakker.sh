#!/usr/bin/env bash
set -e

# Parse port from command line arguments or use default
PORT="${YAKKER_PORT:-80}"
next_is_port=false
for arg in "$@"; do
  if [[ "$arg" =~ ^--port ]]; then
    next_is_port=true
  elif [[ "$next_is_port" == "true" ]]; then
    if [[ "$arg" =~ ^[0-9]+$ ]]; then
      PORT="$arg"
    fi
    break
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

if [ ! -d ".venv" ]; then
  echo "🌱 Creating local virtual environment..."
  python3 -m venv .venv
fi

echo "📦 Installing dependencies..."
source .venv/bin/activate
pip3 install --upgrade pip >/dev/null
pip3 install -r requirements.txt >/dev/null

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

python3 yakker_stream.py "$@"
