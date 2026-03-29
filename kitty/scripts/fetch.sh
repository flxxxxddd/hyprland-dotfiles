#!/usr/bin/env bash
# replacement of fastfetch; beauty styled system info

# palette
R='\033[0m'
B0='\033[38;2;30;30;46m'        # base
S0='\033[38;2;49;50;68m'        # surface0
S1='\033[38;2;69;71;90m'        # surface1 (dim lines)
OV='\033[38;2;108;112;134m'     # overlay / muted
TX='\033[38;2;205;214;244m'     # text
S10='\033[38;2;166;173;200m'    # subtext
BL='\033[38;2;137;180;250m'     # blue
LV='\033[38;2;180;190;254m'     # lavender
SA='\033[38;2;116;199;236m'     # sapphire
SK='\033[38;2;137;220;235m'     # sky
TL='\033[38;2;148;226;213m'     # teal
GR='\033[38;2;166;227;161m'     # green
YL='\033[38;2;249;226;175m'     # yellow
PE='\033[38;2;250;179;135m'     # peach
RD='\033[38;2;243;139;168m'     # red
MV='\033[38;2;203;166;247m'     # mauve
PK='\033[38;2;245;194;231m'     # pink

# helpers
bar() {
    # bar <value 0-100> <width> <fill_color> <empty_color>
    local val=$1 width=$2 fc=$3 ec=$4
    local filled=$(( val * width / 100 ))
    local empty=$(( width - filled ))
    printf "${fc}"
    for ((i=0; i<filled; i++)); do printf "█"; done
    printf "${ec}"
    for ((i=0; i<empty;  i++)); do printf "░"; done
    printf "${R}"
}

line() { printf "${S1}  %s${R}\n" "$(printf '─%.0s' {1..40})"; }

row() {
    # row <icon_color> <icon> <label_color> <label> <value_color> <value>
    printf "  ${1}${2}${R}  ${3}%-8s${R}  ${5}%s${R}\n" "$4" "$6"
}

# gather info
USER_NAME="${USER:-$(whoami)}"
HOST_NAME="$(hostname)"
OS=$(grep "^PRETTY_NAME" /etc/os-release 2>/dev/null | cut -d'"' -f2 | sed 's/ Linux//')
KERNEL=$(uname -r | cut -d'-' -f1-2)
WM="${XDG_CURRENT_DESKTOP:-${WAYLAND_DISPLAY:+Hyprland}}"
[[ -z "$WM" ]] && WM=$(wmctrl -m 2>/dev/null | grep Name | awk '{print $2}')
SHELL_NAME=$(basename "$SHELL")
TERM_NAME="${TERM_PROGRAM:-${TERM:-kitty}}"
UPTIME=$(uptime -p 2>/dev/null | sed 's/up //' | sed 's/ hours\?/h/' | sed 's/ minutes\?/m/' | sed 's/ days\?/d/')

# cpu
CPU_MODEL=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 \
    | sed 's/.*: //' \
    | sed 's/(R)//g;s/(TM)//g' \
    | sed 's/CPU //g' \
    | sed 's/  */ /g' \
    | sed 's/ @.*//')
CPU_CORES=$(nproc 2>/dev/null)
CPU_USAGE=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print int($2)}')
[[ -z "$CPU_USAGE" ]] && CPU_USAGE=0
CPU_TEMP=$(cat /sys/class/hwmon/hwmon4/temp1_input 2>/dev/null)
[[ -n "$CPU_TEMP" ]] && CPU_TEMP="$(( CPU_TEMP / 1000 ))°C" || CPU_TEMP=""

# ram
MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
MEM_AVAIL=$(grep MemAvailable /proc/meminfo | awk '{print int($2/1024)}')
MEM_USED=$(( MEM_TOTAL - MEM_AVAIL ))
MEM_PCT=$(( MEM_USED * 100 / MEM_TOTAL ))
MEM_USED_G=$(awk "BEGIN{printf \"%.1f\", $MEM_USED/1024}")
MEM_TOTAL_G=$(awk "BEGIN{printf \"%.1f\", $MEM_TOTAL/1024}")

# disk
DISK_INFO=$(df -h / 2>/dev/null | tail -1)
DISK_USED=$(echo "$DISK_INFO" | awk '{print $3}')
DISK_TOTAL=$(echo "$DISK_INFO" | awk '{print $2}')
DISK_PCT=$(echo "$DISK_INFO" | awk '{print $5}' | tr -d '%')
[[ -z "$DISK_PCT" ]] && DISK_PCT=0

# gpu
GPU_MODEL=$(lspci 2>/dev/null | grep -i "vga\|3d\|display" | head -1 \
    | sed 's/.*: //' \
    | sed 's/(.*)//' \
    | sed 's/  */ /g' \
    | sed 's/Corporation //g' \
    | sed 's/Advanced Micro Devices, Inc. //' \
    | cut -c1-36)

# packages
PKGS=""
if command -v pacman &>/dev/null; then
    PKGS="$(pacman -Q 2>/dev/null | wc -l) (pacman)"
elif command -v dpkg &>/dev/null; then
    PKGS="$(dpkg -l 2>/dev/null | grep ^ii | wc -l) (dpkg)"
fi

# swatches palette
swatches() {
    printf "  "
    local colors=("$RD" "$PE" "$YL" "$GR" "$TL" "$BL" "$MV" "$PK")
    for c in "${colors[@]}"; do
        printf "${c}●${R} "
    done
    printf "\n"
}

# render
echo
# header
printf "  ${BL}󰣇${R}  ${LV}%s${R}${S1}@${R}${BL}%s${R}\n" "$USER_NAME" "$HOST_NAME"
line

# system
row "$MV" "" "$OV" "os"     "$TX" "󰣇 $OS"
row "$MV" "" "$OV" "kernel" "$TX" "$KERNEL"
row "$MV" "" "$OV" "wm"     "$TX" "$WM"
row "$SK" "" "$OV" "term"   "$TX" "$TERM_NAME"
row "$SK" "" "$OV" "shell"  "$TX" "$SHELL_NAME"
line

# hardware
printf "  ${GR}󰻠${R}  ${OV}%-8s${R}  ${TX}%s${R}" "cpu" "$CPU_MODEL"
[[ -n "$CPU_TEMP" ]] && printf "  ${PE}%s${R}" "$CPU_TEMP"
printf "\n"

printf "  ${GR} ${R}  ${OV}%-8s${R}  " "cpu use"
bar "$CPU_USAGE" 20 "$GR" "$S1"
printf "  ${TX}%d%%${R}\n" "$CPU_USAGE"

[[ -n "$GPU_MODEL" ]] && row "$GR" "󰍛" "$OV" "gpu" "$TX" "$GPU_MODEL]"

printf "  ${GR}󰍛${R}  ${OV}%-8s${R}  " "ram"
bar "$MEM_PCT" 20 "$BL" "$S1"
printf "  ${TX}%s / %s${R}  ${OV}%d%%${R}\n" "$MEM_USED_G G" "$MEM_TOTAL_G G" "$MEM_PCT"

printf "  ${GR}󰋊${R}  ${OV}%-8s${R}  " "disk"
bar "$DISK_PCT" 20 "$MV" "$S1"
printf "  ${TX}%s / %s${R}  ${OV}%d%%${R}\n" "$DISK_USED" "$DISK_TOTAL" "$DISK_PCT"

line

# extras
row "$YL" "󱑂" "$OV" "uptime"  "$TX" "$UPTIME"
[[ -n "$PKGS" ]] && row "$YL" "󰏗" "$OV" "pkgs" "$TX" "$PKGS"
line

# color swatches
swatches
echo
