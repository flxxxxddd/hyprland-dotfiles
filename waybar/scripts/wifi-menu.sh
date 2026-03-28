#!/usr/bin/env bash
# ~/.config/waybar/scripts/wifi-menu.sh
# Wi-Fi menu via nmcli + rofi

ROFI_THEME="$HOME/.config/rofi/catppuccin-wifi.rasi"
ICO_WIFI=("󰤯" "󰤟" "󰤢" "󰤥" "󰤨")
ICO_LOCK="󰌾"
ICO_DISCONNECT="󰤭"
ICO_RESCAN="󰑐"
ICO_MANUAL="󰌐"

signal_icon() {
    local s=$1
    if   [[ $s -ge 80 ]]; then echo "${ICO_WIFI[4]}"
    elif [[ $s -ge 60 ]]; then echo "${ICO_WIFI[3]}"
    elif [[ $s -ge 40 ]]; then echo "${ICO_WIFI[2]}"
    elif [[ $s -ge 20 ]]; then echo "${ICO_WIFI[1]}"
    else echo "${ICO_WIFI[0]}"
    fi
}

get_password() {
    rofi -dmenu \
        -theme "$ROFI_THEME" \
        -p "󰌾  Password" \
        -password \
        -lines 0
}

main() {
    # Get active connection at top level — accessible everywhere
    ACTIVE_SSID=$(nmcli -t -f NAME,TYPE connection show --active \
        | grep ':802-11-wireless' | cut -d: -f1 | head -1)
    ACTIVE_DEV=$(nmcli -t -f DEVICE,TYPE device status \
        | grep ':wifi' | cut -d: -f1 | head -1)

    # Build list
    local entries=()

    if [[ -n "$ACTIVE_SSID" ]]; then
        entries+=("$ICO_DISCONNECT  Disconnect  ($ACTIVE_SSID)")
    fi

    while IFS= read -r line; do
        entries+=("$line")
    done < <(nmcli -t -f SSID,SECURITY,SIGNAL,IN-USE device wifi list 2>/dev/null \
        | sort -t: -k3 -rn \
        | awk -F: '!seen[$1]++ && $1!=""' \
        | while IFS=: read -r ssid security signal in_use; do
            [[ -z "$ssid" ]] && continue
            icon=$(signal_icon "$signal")
            lock=""
            [[ "$security" != "--" && -n "$security" ]] && lock="  $ICO_LOCK"
            mark=""
            [[ "$in_use" == "*" ]] && mark=" ✔"
            printf "%s  %-32s %3s%%%s%s\n" "$icon" "$ssid" "$signal" "$lock" "$mark"
        done)

    entries+=("$ICO_RESCAN  Rescan")
    entries+=("$ICO_MANUAL  Manual connection")

    # Show rofi
    local choice
    choice=$(printf '%s\n' "${entries[@]}" | rofi -dmenu \
        -theme "$ROFI_THEME" \
        -p "󰤨  Wi-Fi" \
        -i \
        -selected-row 0)

    [[ -z "$choice" ]] && exit 0

    # Rescan
    if [[ "$choice" == *"Rescan"* ]]; then
        nmcli device wifi rescan 2>/dev/null
        sleep 2
        main
        return
    fi

    # Disconnect — use device disconnect which always works
    if [[ "$choice" == *"Disconnect"* ]]; then
        if [[ -n "$ACTIVE_DEV" ]]; then
            nmcli device disconnect "$ACTIVE_DEV"
        else
            nmcli connection down "$ACTIVE_SSID"
        fi
        exit 0
    fi

    # Manual SSID
    if [[ "$choice" == *"Manual connection"* ]]; then
        local ssid
        ssid=$(rofi -dmenu \
            -theme "$ROFI_THEME" \
            -p "󰌐  SSID" -lines 0)
        [[ -z "$ssid" ]] && exit 0
        local password
        password=$(get_password)
        if [[ -n "$password" ]]; then
            nmcli device wifi connect "$ssid" password "$password"
        else
            nmcli device wifi connect "$ssid"
        fi
        exit 0
    fi

    # Extract SSID — strip icon + spaces from start, take first word
    local ssid
    ssid=$(echo "$choice" | sed 's/^[^ ]*[[:space:]]*//' | awk '{print $1}')
    [[ -z "$ssid" ]] && exit 0

    # Already saved — just bring up
    if nmcli connection show "$ssid" &>/dev/null; then
        nmcli connection up "$ssid"
        exit 0
    fi

    # New network — check security
    local security
    security=$(nmcli -t -f SSID,SECURITY device wifi list \
        | grep -m1 "^${ssid}:" | cut -d: -f2)

    if [[ "$security" != "--" && -n "$security" ]]; then
        local password
        password=$(get_password)
        [[ -z "$password" ]] && exit 0
        nmcli device wifi connect "$ssid" password "$password"
    else
        nmcli device wifi connect "$ssid"
    fi
}

main
