#!/usr/bin/env bash

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
