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

# we could add some sanity checks (e.g. "$new" = "O")

logger -t "pi-usv" "remounting filesystems with async-option"
mount -o remount,async /
mount -o remount,async /boot
