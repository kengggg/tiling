#!/usr/bin/env bash

BATTERY="$(pmset -g batt)"
PERCENT="$(printf '%s\n' "$BATTERY" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')"

# Desktop Macs have no internal battery. Do not show an empty percentage.
if [ -z "$PERCENT" ]; then
    sketchybar --set "$NAME" drawing=off
    exit 0
fi

CHARGING="$(printf '%s\n' "$BATTERY" | grep 'AC Power')"

if [ -n "$CHARGING" ]; then
    ICON=""
elif [ "$PERCENT" -ge 80 ]; then
    ICON=""
elif [ "$PERCENT" -ge 60 ]; then
    ICON=""
elif [ "$PERCENT" -ge 40 ]; then
    ICON=""
elif [ "$PERCENT" -ge 20 ]; then
    ICON=""
else
    ICON=""
fi

sketchybar --set "$NAME" drawing=on icon="$ICON" label="${PERCENT}%"
