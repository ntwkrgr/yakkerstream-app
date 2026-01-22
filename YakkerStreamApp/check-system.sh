#!/bin/bash
# System check script for Yakker Stream App

echo "🔍 Yakker Stream System Check"
echo "================================"
echo ""

# Check OS
echo "1️⃣  Checking Operating System..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "   ✅ macOS detected"
    sw_vers 2>/dev/null | grep ProductVersion | awk '{print "   Version: " $2}'
else
    echo "   ⚠️  Not running on macOS"
    echo "   The menu bar app requires macOS 13.0 or later"
fi
echo ""

# Check Python
echo "2️⃣  Checking Python..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    echo "   ✅ Python found: $PYTHON_VERSION"
    
    # Check if version is >= 3.7
    MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
    MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)
    if [ "$MAJOR" -ge 3 ] && [ "$MINOR" -ge 7 ]; then
        echo "   ✅ Version is compatible (>= 3.7)"
    else
        echo "   ⚠️  Python 3.7+ recommended, found $PYTHON_VERSION"
    fi
else
    echo "   ❌ Python 3 not found"
    echo "   Install from: https://www.python.org/downloads/mac-osx/"
fi
echo ""

# Check pip
echo "3️⃣  Checking pip..."
if command -v pip3 &> /dev/null; then
    echo "   ✅ pip3 found"
else
    echo "   ⚠️  pip3 not found"
    echo "   Run: python3 -m ensurepip --upgrade"
fi
echo ""

# Check aiohttp
echo "4️⃣  Checking Python dependencies..."
if python3 -c "import aiohttp" 2>/dev/null; then
    echo "   ✅ aiohttp installed"
else
    echo "   ⚠️  aiohttp not installed"
    echo "   Run: pip3 install aiohttp"
fi
echo ""

# Check Xcode (for building the app)
echo "5️⃣  Checking Xcode (for building)..."
if command -v xcodebuild &> /dev/null; then
    XCODE_VERSION=$(xcodebuild -version 2>/dev/null | head -1)
    echo "   ✅ Xcode found: $XCODE_VERSION"
else
    echo "   ⚠️  Xcode not found"
    echo "   Install from Mac App Store to build the app"
    echo "   (Not needed if using pre-built app)"
fi
echo ""

# Check if yakker.sh exists
echo "6️⃣  Checking yakker.sh script..."
if [ -f "../yakker.sh" ]; then
    echo "   ✅ yakker.sh found"
    if [ -x "../yakker.sh" ]; then
        echo "   ✅ yakker.sh is executable"
    else
        echo "   ⚠️  yakker.sh is not executable"
        echo "   Run: chmod +x ../yakker.sh"
    fi
else
    echo "   ⚠️  yakker.sh not found in parent directory"
fi
echo ""

# Summary
echo "================================"
echo "📊 Summary"
echo "================================"
echo ""
echo "Ready to use Yakker Stream App if:"
echo "  • macOS 13.0+ ✓"
echo "  • Python 3.7+ ✓"
echo "  • aiohttp installed ✓"
echo "  • yakker.sh present ✓"
echo ""
echo "Build the app if:"
echo "  • All above requirements ✓"
echo "  • Xcode installed ✓"
echo ""
echo "To build: cd YakkerStreamApp && ./build.sh"
echo "To test backend: cd .. && ./yakker.sh --demo"
