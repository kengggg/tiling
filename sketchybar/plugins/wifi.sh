#!/usr/bin/env bash

# macOS prints the literal placeholder "<redacted>" for the network name.
# Show the icon only. "off" means the Wi-Fi link is down.

LINK="$(ipconfig getsummary en0 2>/dev/null | awk -F ' : ' '/LinkStatusActive/ {print $2; exit}')"

if [ "$LINK" = "TRUE" ]; then
    sketchybar --set "$NAME" icon="󰖩" label="" label.drawing=off
else
    sketchybar --set "$NAME" icon="󰖪" label="off" label.drawing=on
fi
