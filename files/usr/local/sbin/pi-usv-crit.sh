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

logger -t "pi-usv" "running $0"

old="$1"
new="$2"

WALL_TEXT="running on very low power, shutdown expected shortly"
WALL_TEXT="Akkuspannung ist sehr niedrig, Shutdown in Kürze"

# setup desktop notification
DESKTOP_USER=$(ps -C "notification-daemon" --no-headers -o "%U")
if [ -n "$DESKTOP_USER" ]; then
  export DISPLAY=":0.0"
  export XAUTHORITY="/home/$DESKTOP_USER/.Xauthority"
fi

# warn users
if [ -n "$DESKTOP_USER" ]; then
  su - $DESKTOP_USER -c 'notify-send -u critical "$WALL_TEXT"'
else
  wall -t 5 "$WALL_TEXT" &
fi

if [ "$old" = 'W' ]; then
  logger -t "pi-usv" "state changed from WARN to CRITICAL"
elif [ "$old" = 'O' ]; then
  logger -t "pi-usv" "state changed from OK to CRITICAL"
  logger -t "pi-usv" "remounting filesystems with sync-option"
  mount -o remount,sync /
  mount -o remount,sync /boot
fi
