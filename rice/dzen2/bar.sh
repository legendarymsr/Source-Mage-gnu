#!/bin/sh
# ~/.config/dzen2/bar.sh — Tokyo Night bar: ram · battery · date
# Pure shell + dzen2 (C), the same idea as legenddots' lemonbar bar (the Source Mage
# grimoire has no lemonbar). bspwmrc launches this.

BG="#1a1b26"; FG="#c0caf5"; AC="#7aa2f7"
FONT="JetBrains Mono:size=10"

feed() {
  while :; do
    ram=$(free -m 2>/dev/null | awk '/Mem:/{printf "%d", ($3/$2)*100}')
    bat=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
    day=$(date '+%a %d %b %H:%M')
    line="^fg($AC)ram^fg($FG) ${ram}%   "
    [ -n "$bat" ] && line="${line}^fg($AC)bat^fg($FG) ${bat}%   "
    echo "${line}^fg($FG)${day}  "
    sleep 3
  done
}

# -p persistent · -h height 24 · right-aligned · Tokyo Night colours
feed | dzen2 -p -h 24 -ta r -bg "$BG" -fg "$FG" -fn "$FONT"
