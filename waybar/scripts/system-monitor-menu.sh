#!/usr/bin/env bash
# ~/.config/waybar/scripts/system-monitor-menu.sh

ROFI_THEME="$HOME/.config/rofi/catppuccin-audio.rasi"
TERMINAL="kitty"

SECTION="$1"

ICO_CPU="󰻠"
ICO_RAM="󰍛"
ICO_TEMP="󰔏"
ICO_PROC="󰈐"
ICO_SWAP="󰓡"
ICO_CACHE="󰾆"
ICO_FAN="󰈐"
ICO_GOV="󰘚"
ICO_FREQ="󱐋"
ICO_NVME="󰋊"
ICO_GPU="󰢮"
ICO_BTOP="󰄪"
ICO_NVTOP="󰄪"

rofi_run() {
    rofi -dmenu -theme "$ROFI_THEME" -location 0 "$@"
}

notify() {
    command -v notify-send &>/dev/null && \
        notify-send "System Monitor" "$1" -t 2500 2>/dev/null
}

open_terminal_app() {
    local app="$1"
    "$TERMINAL" -e "$app" >/dev/null 2>&1 &
}

cpu_usage() {
    awk '/^cpu / {usage=($2+$4)*100/($2+$4+$5); printf "%.0f", usage}' /proc/stat
}

cpu_loadavg() {
    awk '{print $1" "$2" "$3}' /proc/loadavg
}

cpu_governor() {
    local gov
    gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
    [[ -n "$gov" ]] && printf "%s" "$gov" || printf "n/a"
}

cpu_available_governors() {
    local govs
    govs=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null)
    [[ -n "$govs" ]] && printf "%s\n" "$govs" | tr ' ' '\n'
}

set_cpu_governor() {
    local governor="$1"
    local changed=0

    for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [[ -w "$file" ]] || continue
        printf '%s' "$governor" > "$file" || return 1
        changed=1
    done

    [[ $changed -eq 1 ]]
}

menu_set_governor() {
    local current
    current=$(cpu_governor)
    mapfile -t governors < <(cpu_available_governors)
    [[ ${#governors[@]} -eq 0 ]] && return

    local entries=()
    local gov
    for gov in "${governors[@]}"; do
        if [[ "$gov" == "$current" ]]; then
            entries+=("$ICO_GOV  $gov  󰄬")
        else
            entries+=("$ICO_GOV  $gov")
        fi
    done

    local choice selected
    choice=$(printf '%s\n' "${entries[@]}" | rofi_run -p "$ICO_GOV  CPU governor" -no-custom -selected-row 0)
    [[ -z "$choice" ]] && return

    selected=${choice#"$ICO_GOV  "}
    selected=${selected%"  󰄬"}

    if set_cpu_governor "$selected"; then
        notify "Governor: $selected"
    else
        notify "Failed to set governor to $selected"
    fi
}

cpu_freq_info() {
    local cur min max
    cur=$(awk '{printf "%.2f GHz", $1/1000000}' /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
    min=$(awk '{printf "%.2f GHz", $1/1000000}' /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq 2>/dev/null)
    max=$(awk '{printf "%.2f GHz", $1/1000000}' /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null)
    printf "%s|%s|%s" "${cur:-n/a}" "${min:-n/a}" "${max:-n/a}"
}

top_cpu_processes() {
    ps -eo pid,comm,%cpu --sort=-%cpu | awk 'NR==1 {next} NR<=11 {printf "%s  PID %-7s %-18s %s%%\n", "󰈐", $1, $2, $3}'
}

top_mem_processes() {
    ps -eo pid,comm,%mem,rss --sort=-%mem | awk 'NR==1 {next} NR<=11 {printf "%s  PID %-7s %-18s %s%% (%d MB)\n", "󰈐", $1, $2, $3, $4/1024}'
}

memory_info() {
    awk '
        /^MemTotal:/ {total=$2}
        /^MemFree:/ {free=$2}
        /^MemAvailable:/ {avail=$2}
        /^Buffers:/ {buffers=$2}
        /^Cached:/ {cached=$2}
        /^SwapTotal:/ {swap_total=$2}
        /^SwapFree:/ {swap_free=$2}
        /^SwapCached:/ {swap_cached=$2}
        /^AnonPages:/ {anon=$2}
        END {
            used=total-avail
            swap_used=swap_total-swap_free
            printf "%d|%d|%d|%d|%d|%d|%d|%d|%d", used/1024, total/1024, swap_used/1024, swap_total/1024, buffers/1024, cached/1024, free/1024, swap_cached/1024, anon/1024
        }
    ' /proc/meminfo
}

mission_center_installed() {
    command -v missioncenter >/dev/null 2>&1 || command -v mission-center >/dev/null 2>&1
}

open_mission_center() {
    if command -v missioncenter >/dev/null 2>&1; then
        missioncenter >/dev/null 2>&1 &
    elif command -v mission-center >/dev/null 2>&1; then
        mission-center >/dev/null 2>&1 &
    else
        notify "mission center not found!\nRun: sudo pacman -S mission-center"
    fi
}

read_temp_millic() {
    local path="$1"
    [[ -r "$path" ]] && awk '{printf "%.1f", $1/1000}' "$path" 2>/dev/null
}

read_hwmon_name() {
    local hwmon_dir="$1"
    [[ -r "$hwmon_dir/name" ]] && cat "$hwmon_dir/name" 2>/dev/null
}

collect_temp_lines() {
    local lines=()
    local cpu_pkg=""
    local core_lines=()
    local other_lines=()

    for hwmon in /sys/class/hwmon/hwmon*; do
        [[ -d "$hwmon" ]] || continue
        local chip
        chip=$(read_hwmon_name "$hwmon")

        for input in "$hwmon"/temp*_input; do
            [[ -e "$input" ]] || continue
            local temp label base
            temp=$(read_temp_millic "$input")
            [[ -z "$temp" ]] && continue

            base=${input%_input}
            if [[ -r "${base}_label" ]]; then
                label=$(<"${base}_label")
            else
                label=$(basename "$base")
            fi

            case "$chip:$label" in
                k10temp:Tctl|k10temp:Tdie|coretemp:Package*|zenpower:Tdie)
                    [[ -z "$cpu_pkg" ]] && cpu_pkg="$ICO_TEMP  CPU package: ${temp}°C"
                    ;;
                coretemp:Core*|k10temp:Core*|zenpower:Core*)
                    core_lines+=("$ICO_TEMP  $label: ${temp}°C")
                    ;;
                amdgpu:*|nouveau:*|nvidia:* )
                    other_lines+=("$ICO_GPU  GPU ${label}: ${temp}°C")
                    ;;
                nvme:* )
                    other_lines+=("$ICO_NVME  NVMe ${label}: ${temp}°C")
                    ;;
            esac
        done
    done

    [[ -n "$cpu_pkg" ]] && lines+=("$cpu_pkg")
    if [[ ${#core_lines[@]} -gt 0 ]]; then
        lines+=("${core_lines[@]:0:6}")
    fi
    if [[ ${#other_lines[@]} -gt 0 ]]; then
        lines+=("${other_lines[@]:0:8}")
    fi

    printf '%s\n' "${lines[@]}"
}

fan_lines() {
    local found=0
    for hwmon in /sys/class/hwmon/hwmon*; do
        [[ -d "$hwmon" ]] || continue
        local chip
        chip=$(read_hwmon_name "$hwmon")
        for input in "$hwmon"/fan*_input; do
            [[ -e "$input" ]] || continue
            local rpm base label
            rpm=$(cat "$input" 2>/dev/null)
            [[ -z "$rpm" ]] && continue
            base=${input%_input}
            if [[ -r "${base}_label" ]]; then
                label=$(<"${base}_label")
            else
                label=$(basename "$base")
            fi
            printf "%s  %s %s: %s RPM\n" "$ICO_FAN" "$chip" "$label" "$rpm"
            found=1
        done
    done

    if [[ $found -eq 0 ]]; then
        if command -v sensors >/dev/null 2>&1; then
            local sensor_fans
            sensor_fans=$(sensors 2>/dev/null | awk '/fan[0-9]+:/ {printf "󰈐  %s %s %s\n", $1, $2, $3}')
            if [[ -n "$sensor_fans" ]]; then
                printf "%s\n" "$sensor_fans"
                return
            fi
        fi

        printf "%s  Fan speed: N/A\n" "$ICO_FAN"
    fi
}

throttling_lines() {
    local found=0
    for zone in /sys/class/thermal/thermal_zone*; do
        [[ -d "$zone" ]] || continue
        local type temp trip
        type=$(cat "$zone/type" 2>/dev/null)
        temp=$(read_temp_millic "$zone/temp")
        trip=$(read_temp_millic "$zone/trip_point_0_temp")
        [[ -z "$type" || -z "$temp" ]] && continue
        if [[ -n "$trip" ]]; then
            printf "%s  %s: %s°C / trip %s°C\n" "$ICO_TEMP" "$type" "$temp" "$trip"
        else
            printf "%s  %s: %s°C\n" "$ICO_TEMP" "$type" "$temp"
        fi
        found=1
    done
    [[ $found -eq 0 ]] && printf "%s  Throttling info: n/a\n" "$ICO_TEMP"
}

menu_cpu() {
    local usage load gov freq cur min max
    usage=$(cpu_usage)
    load=$(cpu_loadavg)
    gov=$(cpu_governor)
    freq=$(cpu_freq_info)
    IFS='|' read -r cur min max <<< "$freq"

    local entries=(
        "$ICO_CPU  CPU usage: ${usage}%"
        "$ICO_CPU  Load average: $load"
        "$ICO_GOV  Governor: $gov"
        "$ICO_FREQ  Frequency: $cur  (min $min / max $max)"
        "─────────────────────────────────────────────"
        "$ICO_PROC  Top CPU processes"
        "$ICO_BTOP  Open btop"
    )

    local choice
    choice=$(printf '%s\n' "${entries[@]}" | rofi_run -p "$ICO_CPU  CPU" -no-custom -selected-row 0)
    [[ -z "$choice" ]] && exit 0

    case "$choice" in
        *"Top CPU processes")
            {
                printf "%s\n" "$ICO_CPU  CPU usage: ${usage}%"
                printf "%s\n" "$ICO_CPU  Load average: $load"
                printf "%s\n" "─────────────────────────────────────────────"
                top_cpu_processes
            } | rofi_run -p "$ICO_PROC  Top CPU" -no-custom
            ;;
        *"Change governor")
            menu_set_governor
            ;;
        *"Governor:"*)
            menu_set_governor
            ;;
        *"Open btop")
            open_terminal_app btop
            ;;
    esac
}

menu_memory() {
    local mem used total swap_used swap_total buffers cached free swap_cached anon
    mem=$(memory_info)
    IFS='|' read -r used total swap_used swap_total buffers cached free swap_cached anon <<< "$mem"

    local entries=(
        "$ICO_RAM  Memory: ${used} MB / ${total} MB"
        "$ICO_SWAP  Swap: ${swap_used} MB / ${swap_total} MB"
        "$ICO_CACHE  Buffers/Cache: ${buffers} MB / ${cached} MB"
        "$ICO_RAM  Free / Anon: ${free} MB / ${anon} MB"
        "$ICO_SWAP  Swap cached: ${swap_cached} MB"
        "─────────────────────────────────────────────"
        "$ICO_PROC  Top memory processes"
        "$ICO_BTOP  Open btop"
        "󰖟  Open mission-center"
    )

    local choice
    choice=$(printf '%s\n' "${entries[@]}" | rofi_run -p "$ICO_RAM  Memory" -no-custom -selected-row 0)
    [[ -z "$choice" ]] && exit 0

    case "$choice" in
        *"Top memory processes")
            {
                printf "%s\n" "$ICO_RAM  Memory: ${used} MB / ${total} MB"
                printf "%s\n" "$ICO_SWAP  Swap: ${swap_used} MB / ${swap_total} MB"
                printf "%s\n" "$ICO_CACHE  Buffers/Cache: ${buffers} MB / ${cached} MB"
                printf "%s\n" "$ICO_RAM  Free / Anon: ${free} MB / ${anon} MB"
                printf "%s\n" "$ICO_SWAP  Swap cached: ${swap_cached} MB"
                printf "%s\n" "─────────────────────────────────────────────"
                top_mem_processes
            } | rofi_run -p "$ICO_PROC  Top memory" -no-custom
            ;;
        *"Open btop")
            open_terminal_app btop
            ;;
        *"Open mission-center")
            open_mission_center
            ;;
    esac
}

menu_temp() {
    mapfile -t temp_entries < <(collect_temp_lines)
    mapfile -t fan_entries < <(fan_lines)
    mapfile -t throttle_entries < <(throttling_lines)

    [[ ${#temp_entries[@]} -eq 0 ]] && temp_entries=("$ICO_TEMP  Temperature info: n/a")

    local entries=(
        "${temp_entries[@]}"
        "─────────────────────────────────────────────"
        "${fan_entries[@]}"
        "─────────────────────────────────────────────"
        "${throttle_entries[@]}"
        "─────────────────────────────────────────────"
        "$ICO_BTOP  Open btop"
        "$ICO_NVTOP  Open nvtop"
    )

    local choice
    choice=$(printf '%s\n' "${entries[@]}" | rofi_run -p "$ICO_TEMP  Temperature" -no-custom -selected-row 0)
    [[ -z "$choice" ]] && exit 0

    case "$choice" in
        *"Open btop")
            open_terminal_app btop
            ;;
        *"Open nvtop")
            if command -v nvtop >/dev/null 2>&1; then
                open_terminal_app nvtop
            else
                notify "nvtop is not installed"
            fi
            ;;
    esac
}

case "$SECTION" in
    cpu) menu_cpu ;;
    memory) menu_memory ;;
    temp|temperature) menu_temp ;;
    *)
        notify "Usage: system-monitor-menu.sh {cpu|memory|temp}"
        exit 1
        ;;
esac
