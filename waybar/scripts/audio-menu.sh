#!/usr/bin/env bash
# ~/.config/waybar/scripts/audio-menu.sh

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

get_volume_percent() {
    local target="$1"
    wpctl get-volume "$target" 2>/dev/null | awk '{v=$2*100; printf "%d", v}'
}

is_muted() {
    local target="$1"
    wpctl get-volume "$target" 2>/dev/null | grep -q MUTED && echo "yes" || echo "no"
}

notify_volume() {
    local label="$1" target="$2"
    local volume muted
    volume=$(get_volume_percent "$target")
    muted=$(is_muted "$target")

    if [[ "$muted" == "yes" ]]; then
        notify "$label muted"
    else
        notify "$label: ${volume}%"
    fi
}

adjust_volume() {
    local target="$1" delta="$2" label="$3"
    wpctl set-volume "$target" "$delta"
    notify_volume "$label" "$target"
}

set_volume() {
    local target="$1" value="$2" label="$3"
    wpctl set-volume "$target" "$value"
    notify_volume "$label" "$target"
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

# ── Sub-menus ────────────────────────────────────────────────

menu_output_volume() {
    get_sink_info

    local sink_ico
    sink_ico=$(vol_icon "$SINK_VOL" "$SINK_MUTED")
    local bar
    bar=$(vol_bar "$SINK_VOL")

    local header
    [[ "$SINK_MUTED" == "yes" ]] \
        && header="$ICO_MUTED  Muted  —  $SINK_DESC" \
        || header="$sink_ico  ${SINK_VOL}%  $bar  $SINK_DESC"

    local mute_label="$ICO_MUTE_TOGGLE  Mute output"
    [[ "$SINK_MUTED" == "yes" ]] && mute_label="$ICO_SINK  Unmute output"

    local entries=(
        "$header"
        "─────────────────────────────────────────────"
        "$ICO_VOL_UP  +1%"
        "$ICO_VOL_UP  +5%"
        "$ICO_VOL_UP  +10%"
        "$ICO_VOL_DOWN  −1%"
        "$ICO_VOL_DOWN  −5%"
        "$ICO_VOL_DOWN  −10%"
        "$mute_label"
        "─────────────────────────────────────────────"
        "$ICO_SINK  Set 0%"
        "$ICO_SINK  Set 25%"
        "$ICO_SINK  Set 50%"
        "$ICO_SINK  Set 75%"
        "$ICO_SINK  Set 100%"
    )

    local choice
    choice=$(printf '%s\n' "${entries[@]}" | rofi_run -p "󰕾  Output volume" -no-custom -selected-row 0)
    [[ -z "$choice" ]] && return

    case "$choice" in
        *"+1%") adjust_volume @DEFAULT_AUDIO_SINK@ 1%+ "Volume" ;;
        *"+5%") adjust_volume @DEFAULT_AUDIO_SINK@ 5%+ "Volume" ;;
        *"+10%") adjust_volume @DEFAULT_AUDIO_SINK@ 10%+ "Volume" ;;
        *"−1%") adjust_volume @DEFAULT_AUDIO_SINK@ 1%- "Volume" ;;
        *"−5%") adjust_volume @DEFAULT_AUDIO_SINK@ 5%- "Volume" ;;
        *"−10%") adjust_volume @DEFAULT_AUDIO_SINK@ 10%- "Volume" ;;
        *"Mute output")
            wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
            notify "Output muted"
            ;;
        *"Unmute output")
            wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
            notify "Output unmuted"
            ;;
        *"Set 0%") set_volume @DEFAULT_AUDIO_SINK@ 0% "Volume" ;;
        *"Set 25%") set_volume @DEFAULT_AUDIO_SINK@ 25% "Volume" ;;
        *"Set 50%") set_volume @DEFAULT_AUDIO_SINK@ 50% "Volume" ;;
        *"Set 75%") set_volume @DEFAULT_AUDIO_SINK@ 75% "Volume" ;;
        *"Set 100%") set_volume @DEFAULT_AUDIO_SINK@ 100% "Volume" ;;
    esac
}

menu_input_volume() {
    get_source_info

    local src_ico="$ICO_MIC"
    [[ "$SRC_MUTED" == "yes" ]] && src_ico="$ICO_MIC_MUTED"
    local bar
    bar=$(vol_bar "$SRC_VOL")

    local header="$src_ico  ${SRC_VOL}%  $bar  $SRC_DESC"
    [[ "$SRC_MUTED" == "yes" ]] && header="$ICO_MIC_MUTED  Muted  —  $SRC_DESC"

    local mute_label="$ICO_MIC_MUTED  Mute microphone"
    [[ "$SRC_MUTED" == "yes" ]] && mute_label="$ICO_MIC  Unmute microphone"

    local entries=(
        "$header"
        "─────────────────────────────────────────────"
        "$ICO_VOL_UP  +1%"
        "$ICO_VOL_UP  +5%"
        "$ICO_VOL_UP  +10%"
        "$ICO_VOL_DOWN  −1%"
        "$ICO_VOL_DOWN  −5%"
        "$ICO_VOL_DOWN  −10%"
        "$mute_label"
        "─────────────────────────────────────────────"
        "$ICO_MIC  Set 0%"
        "$ICO_MIC  Set 25%"
        "$ICO_MIC  Set 50%"
        "$ICO_MIC  Set 75%"
        "$ICO_MIC  Set 100%"
    )

    local choice
    choice=$(printf '%s\n' "${entries[@]}" | rofi_run -p "󰍬  Mic volume" -no-custom -selected-row 0)
    [[ -z "$choice" ]] && return

    case "$choice" in
        *"+1%") adjust_volume @DEFAULT_AUDIO_SOURCE@ 1%+ "Mic" ;;
        *"+5%") adjust_volume @DEFAULT_AUDIO_SOURCE@ 5%+ "Mic" ;;
        *"+10%") adjust_volume @DEFAULT_AUDIO_SOURCE@ 10%+ "Mic" ;;
        *"−1%") adjust_volume @DEFAULT_AUDIO_SOURCE@ 1%- "Mic" ;;
        *"−5%") adjust_volume @DEFAULT_AUDIO_SOURCE@ 5%- "Mic" ;;
        *"−10%") adjust_volume @DEFAULT_AUDIO_SOURCE@ 10%- "Mic" ;;
        *"Mute microphone")
            wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
            notify "Mic muted"
            ;;
        *"Unmute microphone")
            wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
            notify "Mic unmuted"
            ;;
        *"Set 0%") set_volume @DEFAULT_AUDIO_SOURCE@ 0% "Mic" ;;
        *"Set 25%") set_volume @DEFAULT_AUDIO_SOURCE@ 25% "Mic" ;;
        *"Set 50%") set_volume @DEFAULT_AUDIO_SOURCE@ 50% "Mic" ;;
        *"Set 75%") set_volume @DEFAULT_AUDIO_SOURCE@ 75% "Mic" ;;
        *"Set 100%") set_volume @DEFAULT_AUDIO_SOURCE@ 100% "Mic" ;;
    esac
}

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
        "─────────────────────────────────────────────"
        "$mute_label"
        "$mic_mute_label"
        "─────────────────────────────────────────────"
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
        "$sink_line")
            menu_output_volume
            ;;
        "$src_line")
            menu_input_volume
            ;;
        *"Mute output")
            wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
            notify "Output muted"
            ;;
        *"Unmute output")
            wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
            notify "Output unmuted"
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
            ;;
    esac
}

main
