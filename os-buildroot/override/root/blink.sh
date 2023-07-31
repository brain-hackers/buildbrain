#!/bin/sh

set -u

if [ $# -ne 3 ]; then
    echo "Usage: blink.sh RANGE_FROM RANGE_TO SLEEP"
    exit 1
fi

if [ "$(id -u)" -ne "0" ]; then
    echo "Error: please run as root"
    exit 1
fi

FROM=$1
TO=$2
SLEEP=$3
GPIOS=$(seq $FROM $TO)
AVAILABLE_GPIOS=""

export_gpio() {
    echo $1 > /sys/class/gpio/export
}

set_direction() {
    echo out > /sys/class/gpio/gpio$1/direction
}

set_value() {
    echo $2 > /sys/class/gpio/gpio$1/value
}

for i in $GPIOS; do
    if [ ! -e "/sys/class/gpio/gpio$i" ]; then
        export_gpio $i 2>/dev/null
        if [ $? -ne 0 ]; then
            echo "Error: failed to export the pin $i"
            continue
        fi
    fi

    set_direction $i 2>/dev/null
    if [ $? -ne 0 ]; then
        # Ignore the failure if the actual direction is out
        if grep -vq "out" /dsys/class/gpio/gpio$i/direction; then
            echo "Error: failed to set the direction of the pin $i to out"
            continue
        fi
    fi

    AVAILABLE_GPIOS="$AVAILABLE_GPIOS$i "
done

echo "Available GPIOs: $AVAILABLE_GPIOS"

while [ 1 ]; do
    for i in $AVAILABLE_GPIOS; do
        set_value $i 1 2>/dev/null
        if [ $? -ne 0 ]; then
            echo "Warning: failed to set the value of the pin $i to high"
        fi
    done

    sleep $SLEEP

    for i in $AVAILABLE_GPIOS; do
        set_value $i 0 2>/dev/null
        if [ $? -ne 0 ]; then
            echo "Warning: failed to set the value of the pin $i to low"
        fi
    done

    sleep $SLEEP
done
