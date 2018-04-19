#!/bin/bash
# --------------------------------------------------------------------------
# Sample implementation of CRIT-hook
#
# This script is executed if the USV-state changes to CRITICAL
#
# Author: Bernhard Bablok
# License: GPL3
#
# Website: https://github.com/bablokb/pi-usv
#
# --------------------------------------------------------------------------

WALL_TEXT="running on very low power, shutdown expected shortly"
WALL_TEXT="Akkustand ist sehr niedrig, Shutdown in Kürze"

logger -t "pi-usv" "running $0"

old="$1"
new="$2"

# warn users
wall -t 5 "$WALL_TEXT" &

if [ "$old" = 'W' ]; then
  logger -t "pi-usv" "state changed from WARN to CRITICAL"
elif [ "$old" = 'O' ]; then
  logger -t "pi-usv" "state changed from OK to CRITICAL"
  logger -t "pi-usv" "remounting filesystems with sync-option"
  mount -o remount,sync /
  mount -o remount,sync /boot
fi
