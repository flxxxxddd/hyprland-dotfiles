#!/usr/bin/env bash
# clipboard menu via rofi + cliphist

ROFI_THEME="$HOME/.config/rofi/catppuccin-clipboard.rasi"

rofi_run() {
    rofi -dmenu -theme "$ROFI_THEME" -location 0 "$@"
}

notify() {
    command -v notify-send &>/dev/null && \
        notify-send "Clipboard" "$1" --icon=edit-paste -t 2000 2>/dev/null
}

if ! command -v cliphist &>/dev/null; then
    notify "cliphist not installed!\nInstall it with: sudo pacman -S cliphist"
    exit 1
fi

declare -a DISPLAY_LINES
declare -a ID_LIST

while IFS=$'\t' read -r id content; do
    [[ -z "$id" ]] && continue

    if [[ "$content" == "[[ binary data"* ]]; then
        # extract size only e.g. "3 KiB"
        size=$(echo "$content" | grep -oP '\d+ \w+iB' | head -1)
        display="󰋩  [Image  $size]"
    else
        text=$(echo "$content" | tr '\n\r' ' ' | sed 's/  */ /g' | sed 's/^ //;s/ $//' | cut -c1-72)
        [[ -z "$text" ]] && continue
        display="󰈚  $text"
    fi

    DISPLAY_LINES+=("$display")
    ID_LIST+=("$id")

done < <(cliphist list 2>/dev/null)

HISTORY_COUNT=${#ID_LIST[@]}
CLEAR_LINE="󰃢  Clear history  ($HISTORY_COUNT items)"

FULL_LIST="$CLEAR_LINE"
for line in "${DISPLAY_LINES[@]}"; do
    FULL_LIST+=$'\n'"$line"
done

CHOICE=$(echo "$FULL_LIST" | rofi_run \
    -p "󰅌  Clipboard" \
    -i \
    -format "i" \
    -selected-row 0)

[[ -z "$CHOICE" ]] && exit 0

if [[ "$CHOICE" == "0" ]]; then
    cliphist wipe
    wl-copy --clear 2>/dev/null
    notify "History cleared"
    exit 0
fi

IDX=$(( CHOICE - 1 ))
SELECTED_ID="${ID_LIST[$IDX]}"

if [[ -z "$SELECTED_ID" ]]; then
    notify "Error: item not found"
    exit 1
fi

cliphist decode "$SELECTED_ID" | wl-copy
notify "Copied"
