
#!/usr/bin/env bash
# ~/.config/waybar/scripts/bluetooth-menu.sh

ROFI_THEME="$HOME/.config/rofi/catppuccin-bluetooth.rasi"

ICO_BT="󰂯"
ICO_BT_ON="󰂱"
ICO_BT_OFF="󰂲"
ICO_CONNECTED="󰂰"
ICO_SCAN="󰐻"
ICO_DISCONNECT="󰂲"
ICO_TRUST="󰒋"
ICO_REMOVE="󰩰"
ICO_CHECK="󰄬"

rofi_run() {
    rofi -dmenu -theme "$ROFI_THEME" -location 0 "$@"
}

notify() {
    command -v notify-send &>/dev/null && \
        notify-send "Bluetooth" "$1" --icon=bluetooth -t 3000 2>/dev/null
}

# ── Check bluetoothctl ───────────────────────────────────────
if ! command -v bluetoothctl &>/dev/null; then
    notify "bluetoothctl not found!\nRun: sudo pacman -S bluez bluez-utils"
    exit 1
fi

# ── Get BT state ─────────────────────────────────────────────
bt_power() {
    bluetoothctl show 2>/dev/null | grep -i "powered:" | awk '{print $2}'
}

bt_on() { [[ "$(bt_power)" == "yes" ]]; }

# ── Get devices ──────────────────────────────────────────────
get_paired_devices() {
    bluetoothctl devices Paired 2>/dev/null | while read -r _ mac name; do
        [[ -z "$mac" ]] && continue
        [[ -z "$name" ]] && name="$mac"
        connected=$(bluetoothctl info "$mac" 2>/dev/null | grep -i "Connected:" | awk '{print $2}')
        if [[ "$connected" == "yes" ]]; then
            echo "$ICO_CONNECTED  $name  $ICO_CHECK|$mac|connected|$name"
        else
            echo "$ICO_BT  $name|$mac|paired|$name"
        fi
    done
}

scan_devices() {
    bluetoothctl devices 2>/dev/null | while read -r _ mac name; do
        [[ -z "$mac" ]] && continue
        [[ -z "$name" ]] && name="$mac"
        paired=$(bluetoothctl info "$mac" 2>/dev/null | grep -i "Paired:" | awk '{print $2}')
        [[ "$paired" == "yes" ]] && continue
        echo "$ICO_BT  $name  [$mac]|$mac|available|$name"
    done
}

# ── Connect to device ─────────────────────────────────────────
pair_and_connect_device() {
    local mac="$1" name="$2"

    notify "Pairing with $name..."
    if bluetoothctl pair "$mac" &>/dev/null; then
        bluetoothctl trust "$mac" &>/dev/null
        if bluetoothctl connect "$mac" &>/dev/null; then
            notify "Paired and connected to $name"
        else
            notify "Paired with $name, but failed to connect"
        fi
    else
        notify "Failed to pair with $name"
    fi
}

connect_device() {
    local mac="$1" name="$2"
    notify "Connecting to $name..."
    bluetoothctl connect "$mac" &>/dev/null \
        && notify "Connected to $name" \
        || notify "Failed to connect to $name"
}

disconnect_device() {
    local mac="$1" name="$2"
    bluetoothctl disconnect "$mac" &>/dev/null \
        && notify "Disconnected from $name" \
        || notify "Failed to disconnect"
}

# ── Main ─────────────────────────────────────────────────────
main() {
    local entries=()
    declare -A MAC_MAP
    declare -A STATE_MAP

    # Power toggle
    if bt_on; then
        entries+=("$ICO_BT_OFF  Turn Bluetooth OFF")
    else
        entries+=("$ICO_BT_ON  Turn Bluetooth ON")
        # Show menu even when off
        CHOICE=$(printf '%s\n' "${entries[@]}" | rofi_run -p "$ICO_BT  Bluetooth" -i -format "i" -selected-row 0)
        [[ -z "$CHOICE" ]] && exit 0
        bluetoothctl power on &>/dev/null && notify "Bluetooth enabled"
        exit 0
    fi

    # Scan toggle
    entries+=("$ICO_SCAN  Start scanning for devices")

    # Separator
    entries+=("───────────────────────────────")

    # Paired/connected devices
    local has_paired_devices=false
    while IFS='|' read -r display mac state _name; do
        [[ -z "$mac" ]] && continue
        has_paired_devices=true
        entries+=("$display")
        MAC_MAP["$display"]="$mac"
        STATE_MAP["$display"]="$state"
    done < <(get_paired_devices)

    if ! $has_paired_devices; then
        entries+=("  No paired devices")
    fi

    # Available scanned devices
    local has_available_devices=false
    while IFS='|' read -r display mac state _name; do
        [[ -z "$mac" ]] && continue
        has_available_devices=true
        entries+=("$display")
        MAC_MAP["$display"]="$mac"
        STATE_MAP["$display"]="$state"
    done < <(scan_devices)

    if ! $has_available_devices; then
        entries+=("  No scanned devices")
    fi

    # Show rofi
    CHOICE=$(printf '%s\n' "${entries[@]}" | rofi_run \
        -p "$ICO_BT  Bluetooth" \
        -i \
        -format "i" \
        -selected-row 0)

    [[ -z "$CHOICE" ]] && exit 0

    local chosen="${entries[$CHOICE]}"

    # Power off
    if [[ "$chosen" == *"Turn Bluetooth OFF"* ]]; then
        bluetoothctl power off &>/dev/null && notify "Bluetooth disabled"
        exit 0
    fi

    # Scan
    if [[ "$chosen" == *"Start scanning"* ]]; then
        notify "Scanning for 10 seconds..."
        bluetoothctl --timeout 10 scan on &>/dev/null
        # Refresh menu after scan
        sleep 1
        main
        return
    fi

    # Separator or empty
    [[ "$chosen" == "─────"* || "$chosen" == *"No paired"* || "$chosen" == *"No scanned"* ]] && exit 0

    # Device action
    local mac="${MAC_MAP[$chosen]}"
    local state="${STATE_MAP[$chosen]}"
    local name="$chosen"

    if [[ "$chosen" == "$ICO_CONNECTED  "* ]]; then
        name="${name#"$ICO_CONNECTED  "}"
        name="${name%"  $ICO_CHECK"}"
    elif [[ "$chosen" == "$ICO_BT  "* ]]; then
        name="${name#"$ICO_BT  "}"
        name="${name% \[*}"
    fi

    [[ -z "$mac" ]] && exit 0

    if [[ "$state" == "connected" ]]; then
        # Ask: disconnect or remove
        local action
        action=$(printf "󰂰  Stay connected\n󰂲  Disconnect\n󰩰  Remove device" | rofi_run \
            -p "  $name" -i -format "i" -selected-row 0)
        case "$action" in
            1) disconnect_device "$mac" "$name" ;;
            2)
                disconnect_device "$mac" "$name"
                bluetoothctl remove "$mac" &>/dev/null
                notify "Removed $name"
                ;;
        esac
    elif [[ "$state" == "available" ]]; then
        pair_and_connect_device "$mac" "$name"
    else
        connect_device "$mac" "$name"
    fi
}

main
