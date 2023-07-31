#!/bin/sh
set -u

VERBOSE=0
PIN=""
SLEEP=1
GPIOS=""

while getopts "hvr:p:s:" OPT; do
    case "$OPT" in
    h)
        echo "Usage:   blink.sh [-hv] [-r PIN_RANGE_FROM-PIN_RANGE_TO] [-p PIN] [-s SLEEP_SEC]"
        echo "Example: blink.sh -r 0-10 -p 12"
        echo "         (blink from GPIO 0 to 10 and 12)"
        exit 0
        ;;
    v)
        VERBOSE=1
        ;;
    r)
        RE='^([0-9]+)-([0-9]+)$'
        if echo $OPTARG | grep -qvE $RE; then
            echo "Error: invalid range: $OPTARG"
            exit 1
        fi
        FROM=$(echo $OPTARG | sed -E "s/$RE/\\1/")
        TO=$(echo $OPTARG | sed -E "s/$RE/\\2/")
        GPIOS="$GPIOS$(seq -s " " $FROM $TO) "
        ;;
    p)
        if echo $OPTARG | grep -qvE "^[0-9]+$"; then
            echo "Error: invalid pin number: $OPTARG"
            exit 1
        fi
        GPIOS="$GPIOS$OPTARG "
        ;;
    s)
        if echo $OPTARG | grep -qvE "^[0-9]+$"; then
            echo "Error: invalid sleep duration: $OPTARG"
            exit 1
        fi
        SLEEP=$OPTARG
        ;;
    esac
done

if [ $VERBOSE -eq 1 ]; then
    echo "Pins to iterate over: $GPIOS"
fi

if [ "$(id -u)" -ne "0" ]; then
    echo "Error: please run as root"
    exit 1
fi

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

