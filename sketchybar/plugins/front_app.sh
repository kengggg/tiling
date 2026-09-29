#!/usr/bin/env bash

# Reload creates a new item and runs this with an empty INFO, which wiped the
# name. Use the name SketchyBar sends. If it sent none, ask who is in front.

if [ -n "$INFO" ]; then
    APP="$INFO"
else
    APP="$(lsappinfo info -only name "$(lsappinfo front)" 2>/dev/null | sed -n 's/^"\([^"]*\)".*/\1/p' | head -1)"
fi

if [ -n "$APP" ]; then
    sketchybar --set "$NAME" label="$APP"
fi
