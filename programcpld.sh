#!/bin/sh
#
# This script requires xc3sprog to be in your path
# Change CABLE to reflect your programming hardware
#

CABLE=arm-usb-tiny-h

detectchain -c ${CABLE}
xc3sprog -c ${CABLE} -v -p 0 k1208_main/k1208_main.jed
xc3sprog -c ${CABLE} -v -p 1 k1208_mux/k1208_mux.jed
