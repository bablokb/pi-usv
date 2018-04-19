#!/bin/bash
# --------------------------------------------------------------------------
# Sample implementation of shutdown-hook
#
# This script is executed if the USV-state changes to SDOWN
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

# we could add some sanity checks (e.g. "$new" = "S")

logger -t "pi-usv" "processing shutdown request"
halt -p
