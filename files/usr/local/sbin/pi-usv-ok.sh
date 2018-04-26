#!/bin/bash
# --------------------------------------------------------------------------
# Sample implementation of OK-hook
#
# This script is executed if the USV-state changes to OK
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

WALL_TEXT="INFO: power is back to normal!"
WALL_TEXT="INFO: Akkuspannung ist normal"

# setup desktop notification
DESKTOP_USER=$(ps -C "notification-daemon" --no-headers -o "%U")
if [ -n "$DESKTOP_USER" ]; then
  export DISPLAY=":0.0"
  export XAUTHORITY="/home/$DESKTOP_USER/.Xauthority"
fi

# warn users
if [ -n "$DESKTOP_USER" ]; then
  su - $DESKTOP_USER -c "notify-send -u normal \"$WALL_TEXT\""
else
  wall -t 5 "$WALL_TEXT" &
fi

# we could add some sanity checks (e.g. "$new" = "O")

logger -t "pi-usv" "remounting filesystems with async-option"
mount -o remount,async /
mount -o remount,async /boot
