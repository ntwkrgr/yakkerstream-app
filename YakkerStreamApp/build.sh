#!/bin/bash
# Build script for YakkerStreamApp
set -e

echo "🏗️  Building Yakker Stream macOS App..."

cd "$(dirname "$0")"

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode command line tools not found"
    echo "Please install Xcode from the Mac App Store"
    exit 1
fi

echo "✅ Xcode found"

# Build the app
echo "📦 Building application..."
xcodebuild -project YakkerStreamApp.xcodeproj \
           -scheme YakkerStreamApp \
           -configuration Release \
           -derivedDataPath ./build \
           build

echo ""
echo "✅ Build complete!"
echo ""
echo "📍 App location:"
echo "   ./build/Build/Products/Release/YakkerStreamApp.app"
echo ""
echo "To run the app:"
echo "   open ./build/Build/Products/Release/YakkerStreamApp.app"
echo ""
echo "To install to Applications:"
echo "   cp -r ./build/Build/Products/Release/YakkerStreamApp.app /Applications/"
