#!/bin/bash
# --------------------------------------------------------------------------
# Sample implementation of WARN-hook
#
# This script is executed if the USV-state changes to WARN
#
# Author: Bernhard Bablok
# License: GPL3
#
# Website: https://github.com/bablokb/pi-usv
#
# --------------------------------------------------------------------------

WALL_TEXT="Akkustand ist niedrig"

logger -t "pi-usv" "running $0"

old="$1"
new="$2"

# warn users
wall -t 5 "$WALL_TEXT" &

if [ "$old" = 'O' ]; then
  logger -t "pi-usv" "state changed from OK to WARN"

  logger -t "pi-usv" "remounting filesystems with sync-option"
  mount -o remount,sync /
  mount -o remount,sync /boot
else
  logger -t "pi-usv" "state changed from CRIT to WARN"
fi
