#!/usr/bin/env bash
# ~/.config/waybar/scripts/audio-menu.sh
# Beautiful PulseAudio/PipeWire control via Rofi — Catppuccin Mocha

ROFI_THEME="$HOME/.config/rofi/catppuccin-audio.rasi"

# ── Icons ────────────────────────────────────────────────────
ICO_SINK="󰕾"
ICO_SINK_MID="󰖀"
ICO_SINK_LOW="󰕿"
ICO_MUTED="󰝟"
ICO_MIC="󰍬"
ICO_MIC_MUTED="󰍭"
ICO_HEADPHONE="󰋋"
ICO_BT="󰂰"
ICO_VOL_UP="󰝝"
ICO_VOL_DOWN="󰝞"
ICO_MUTE_TOGGLE="󰖁"
ICO_SOURCE="󰒓"
ICO_CHECK="󰄬"

# ── Helpers ──────────────────────────────────────────────────

rofi_run() {
    rofi -dmenu -theme "$ROFI_THEME" -location 0 "$@"
}

notify() {
    command -v notify-send &>/dev/null && \
        notify-send "Audio" "$1" --icon=audio-volume-high -t 2000 2>/dev/null
}

vol_icon() {
    local v=$1
    local muted=$2
    [[ "$muted" == "yes" ]] && echo "$ICO_MUTED" && return
    if   [[ $v -ge 60 ]]; then echo "$ICO_SINK"
    elif [[ $v -ge 20 ]]; then echo "$ICO_SINK_MID"
    else echo "$ICO_SINK_LOW"
    fi
}

# ── Volume bar (unicode blocks) ──────────────────────────────
vol_bar() {
    local vol=$1
    local filled=$(( vol / 5 ))
    local empty=$(( 20 - filled ))
    [[ $filled -gt 20 ]] && filled=20 && empty=0
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="▪"; done
    for ((i=0; i<empty;  i++)); do bar+="▫"; done
    echo "$bar"
}

# ── Get current sink info ────────────────────────────────────
get_sink_info() {
    SINK_VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null \
        | awk '{v=$2*100; printf "%d", v}')
    SINK_MUTED=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null \
        | grep -q MUTED && echo "yes" || echo "no")
    SINK_NAME=$(pactl get-default-sink 2>/dev/null)
    SINK_DESC=$(pactl list sinks 2>/dev/null \
        | grep -A5 "Name: $SINK_NAME" \
        | grep "Description:" | head -1 \
        | sed 's/.*Description: //' | cut -c1-38)
    [[ -z "$SINK_DESC" ]] && SINK_DESC="$SINK_NAME"
}

get_source_info() {
    SRC_VOL=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null \
        | awk '{v=$2*100; printf "%d", v}')
    SRC_MUTED=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null \
        | grep -q MUTED && echo "yes" || echo "no")
    SRC_NAME=$(pactl get-default-source 2>/dev/null)
    SRC_DESC=$(pactl list sources 2>/dev/null \
        | grep -A5 "Name: $SRC_NAME" \
        | grep "Description:" | head -1 \
        | sed 's/.*Description: //' | cut -c1-38)
    [[ -z "$SRC_DESC" ]] && SRC_DESC="$SRC_NAME"
}

# ── List all sinks ───────────────────────────────────────────
list_sinks() {
    local default
    default=$(pactl get-default-sink 2>/dev/null)
    pactl list sinks short 2>/dev/null | while read -r idx name _; do
        local desc
        desc=$(pactl list sinks 2>/dev/null \
            | grep -A5 "Name: $name" \
            | grep "Description:" | head -1 \
            | sed 's/.*Description: //' | cut -c1-42)
        local mark=""
        [[ "$name" == "$default" ]] && mark=" $ICO_CHECK"
        printf "%s  %s%s\n" "$ICO_SINK" "$desc" "$mark"
    done
}

list_sources() {
    local default
    default=$(pactl get-default-source 2>/dev/null)
    pactl list sources short 2>/dev/null | grep -v "monitor" | while read -r idx name _; do
        local desc
        desc=$(pactl list sources 2>/dev/null \
            | grep -A5 "Name: $name" \
            | grep "Description:" | head -1 \
            | sed 's/.*Description: //' | cut -c1-42)
        local mark=""
        [[ "$name" == "$default" ]] && mark=" $ICO_CHECK"
        printf "%s  %s%s\n" "$ICO_MIC" "$desc" "$mark"
    done
}

# ── Sub-menus ────────────────────────────────────────────────

menu_set_sink() {
    local default
    default=$(pactl get-default-sink 2>/dev/null)

    # Build name→desc map
    declare -A SINK_MAP
    local entries=()
    while read -r idx name _; do
        local desc
        desc=$(pactl list sinks 2>/dev/null \
            | grep -A5 "Name: $name" \
            | grep "Description:" | head -1 \
            | sed 's/.*Description: //' | cut -c1-42)
        local mark=""
        [[ "$name" == "$default" ]] && mark=" $ICO_CHECK"
        local line
        line=$(printf "%s  %s%s" "$ICO_SINK" "$desc" "$mark")
        entries+=("$line")
        SINK_MAP["$line"]="$name"
    done < <(pactl list sinks short 2>/dev/null)

    local choice
    choice=$(printf '%s\n' "${entries[@]}" | rofi_run -p "󰕾  Output device")
    [[ -z "$choice" ]] && return

    local chosen_name="${SINK_MAP[$choice]}"
    [[ -z "$chosen_name" ]] && return
    pactl set-default-sink "$chosen_name"
    notify "Output: $(echo "$choice" | sed "s/$ICO_SINK  //;s/ $ICO_CHECK//")"
}

menu_set_source() {
    declare -A SRC_MAP
    local entries=()
    local default
    default=$(pactl get-default-source 2>/dev/null)
    while read -r idx name _; do
        [[ "$name" == *"monitor"* ]] && continue
        local desc
        desc=$(pactl list sources 2>/dev/null \
            | grep -A5 "Name: $name" \
            | grep "Description:" | head -1 \
            | sed 's/.*Description: //' | cut -c1-42)
        local mark=""
        [[ "$name" == "$default" ]] && mark=" $ICO_CHECK"
        local line
        line=$(printf "%s  %s%s" "$ICO_MIC" "$desc" "$mark")
        entries+=("$line")
        SRC_MAP["$line"]="$name"
    done < <(pactl list sources short 2>/dev/null)

    local choice
    choice=$(printf '%s\n' "${entries[@]}" | rofi_run -p "󰍬  Input device")
    [[ -z "$choice" ]] && return

    local chosen_name="${SRC_MAP[$choice]}"
    [[ -z "$chosen_name" ]] && return
    pactl set-default-source "$chosen_name"
    notify "Input: $(echo "$choice" | sed "s/$ICO_MIC  //;s/ $ICO_CHECK//")"
}

# ── Main menu ────────────────────────────────────────────────

main() {
    get_sink_info
    get_source_info

    local sink_ico
    sink_ico=$(vol_icon "$SINK_VOL" "$SINK_MUTED")
    local bar
    bar=$(vol_bar "$SINK_VOL")

    local mute_label="$ICO_MUTE_TOGGLE  Mute output"
    [[ "$SINK_MUTED" == "yes" ]] && mute_label="$ICO_SINK  Unmute output"

    local mic_mute_label="$ICO_MIC_MUTED  Mute microphone"
    [[ "$SRC_MUTED" == "yes" ]] && mic_mute_label="$ICO_MIC  Unmute microphone"

    local sink_line
    [[ "$SINK_MUTED" == "yes" ]] \
        && sink_line="$ICO_MUTED  Muted  —  $SINK_DESC" \
        || sink_line="$sink_ico  ${SINK_VOL}%  $bar  $SINK_DESC"

    local src_ico="$ICO_MIC"
    [[ "$SRC_MUTED" == "yes" ]] && src_ico="$ICO_MIC_MUTED"
    local src_line="$src_ico  ${SRC_VOL}%  $SRC_DESC"

    local entries=(
        "$sink_line"
        "$src_line"
        "─────────────────────────────────────"
        "$ICO_VOL_UP  Volume +5%"
        "$ICO_VOL_DOWN  Volume −5%"
        "$mute_label"
        "$ICO_MIC  Mic volume +5%"
        "$ICO_MIC  Mic volume −5%"
        "$mic_mute_label"
        "─────────────────────────────────────"
        "$ICO_SINK  Switch output device"
        "$ICO_SOURCE  Switch input device"
    )

    local choice
    choice=$(printf '%s\n' "${entries[@]}" | rofi_run \
        -p "󰕾  Audio" \
        -no-custom \
        -selected-row 0)

    [[ -z "$choice" ]] && exit 0

    case "$choice" in
        *"Volume +5%")
            wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
            notify "Volume: $(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%d%%", $2*100}')"
            ;;
        *"Volume −5%")
            wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
            notify "Volume: $(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%d%%", $2*100}')"
            ;;
        *"Mute output")
            wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
            notify "Output muted"
            ;;
        *"Unmute output")
            wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
            notify "Output unmuted"
            ;;
        *"Mic volume +5%")
            wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%+
            notify "Mic: $(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | awk '{printf "%d%%", $2*100}')"
            ;;
        *"Mic volume −5%")
            wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%-
            notify "Mic: $(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | awk '{printf "%d%%", $2*100}')"
            ;;
        *"Mute microphone")
            wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
            notify "Mic muted"
            ;;
        *"Unmute microphone")
            wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
            notify "Mic unmuted"
            ;;
        *"Switch output device")
            menu_set_sink
            ;;
        *"Switch input device")
            menu_set_source
            ;;
        *"─────"*)
            # separator — do nothing
            ;;
    esac
}

main
