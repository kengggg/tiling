#!/usr/bin/env bash

# A forced update after startup/reload has no custom event environment.
FOCUSED_WORKSPACE="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"

if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
    sketchybar --set "$NAME" \
        background.drawing=on \
        background.color=0xff89b4fa \
        label.color=0xff1e1e2e
else
    sketchybar --set "$NAME" \
        background.drawing=off \
        label.color=0x99ffffff
fi
