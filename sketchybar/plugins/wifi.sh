#!/usr/bin/env bash

# macOS prints the literal placeholder "<redacted>" for the network name.
# Show the icon only. "off" means the Wi-Fi link is down.

# Interface numbering differs between Mac models. Detect it each time so an
# adapter change does not require restarting the bar.
WIFI_DEVICE="$(networksetup -listallhardwareports 2>/dev/null | awk '
    /^Hardware Port: (Wi-Fi|AirPort)$/ { wifi=1; next }
    wifi && /^Device: / { print $2; exit }
')"

if [ -z "$WIFI_DEVICE" ]; then
    sketchybar --set "$NAME" drawing=off
    exit 0
fi

LINK="$(ipconfig getsummary "$WIFI_DEVICE" 2>/dev/null | awk -F ' : ' '/LinkStatusActive/ {print $2; exit}')"

if [ "$LINK" = "TRUE" ]; then
    sketchybar --set "$NAME" drawing=on icon="󰖩" label="" label.drawing=off
else
    sketchybar --set "$NAME" drawing=on icon="󰖪" label="off" label.drawing=on
fi
