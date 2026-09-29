#!/bin/bash
# One snapshot drives all buttons. Periodic updates recover missed events.
focused="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"
mode="$(aerospace list-modes --current 2>/dev/null)"

args=(--set aerospace_status)
if [ -z "$focused" ] || [ -z "$mode" ]; then
    focused=""
    args+=(drawing=on "label=Waiting for AeroSpace")
elif [ "$mode" = main ]; then
    args+=(drawing=off)
else
    args+=(drawing=on "label=$(printf '%s' "$mode" | tr '[:lower:]' '[:upper:]') · Esc to exit")
fi

for sid in 1 2 3 4 5 6 7; do
    args+=(--set "space.$sid")
    if [ "$sid" = "$focused" ]; then
        args+=(background.drawing=on label.color=0xff1e1e2e)
    else
        args+=(background.drawing=off label.color=0x99ffffff)
    fi
done
sketchybar "${args[@]}"
