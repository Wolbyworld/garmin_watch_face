#!/bin/bash
# Preview watch face in simulator and capture screenshot
# Usage: ./preview.sh [device]    (default: fenix847mm)
# Requires: simulator already running (launch with: connectiq)

DEVICE="${1:-fenix847mm}"
SDK_PATH="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.0-2025-12-03-5122605dc"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCREENSHOTS_DIR="$PROJECT_DIR/screenshots"
mkdir -p "$SCREENSHOTS_DIR"
OUTPUT="$SCREENSHOTS_DIR/latest.png"
PRG="/tmp/watchface-preview-${DEVICE}.prg"

# Build
echo "Building for $DEVICE..."
"$SDK_PATH/bin/monkeyc" -d "$DEVICE" -f "$PROJECT_DIR/monkey.jungle" -o "$PRG" -y "$PROJECT_DIR/developer_key.der" 2>&1
if [ $? -ne 0 ]; then
    echo "BUILD FAILED"
    exit 1
fi
echo "Build OK"

# Push to simulator
echo "Pushing to simulator..."
"$SDK_PATH/bin/monkeydo" "$PRG" "$DEVICE" &
MONKEYDO_PID=$!

# Wait for rendering
sleep 3

# Find simulator window ID (check on-screen first, then all windows)
WINDOW_ID=$(swift -e '
import CoreGraphics
for option: CGWindowListOption in [.optionOnScreenOnly, .optionAll] {
    if let windows = CGWindowListCopyWindowInfo(option, kCGNullWindowID) as? [[String: Any]] {
        for w in windows {
            let name = w[kCGWindowOwnerName as String] as? String ?? ""
            let layer = w[kCGWindowLayer as String] as? Int ?? -1
            if name.contains("Connect IQ") && layer == 0 {
                print(w[kCGWindowNumber as String] as? Int ?? 0)
                exit(0)
            }
        }
    }
}
' 2>/dev/null)

if [ -z "$WINDOW_ID" ] || [ "$WINDOW_ID" = "0" ]; then
    echo "ERROR: Could not find simulator window. Is it running?"
    exit 1
fi

# Capture screenshot (overwrite latest)
screencapture -l "$WINDOW_ID" "$OUTPUT" 2>/dev/null
echo "Screenshot saved to $OUTPUT"
