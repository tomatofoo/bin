#!/usr/bin/env bash


NAME=$(basename $0)
PREHELP="Try $NAME -h for more information."
HELP="Usage: $NAME [OPTIONS]

options:
    -h             show this help
    -d <device>    set which device to use (default wlp3s0)

"

opt_error() {
    echo "Error: invalid option: -$1"
}


DEVICE="wlp3s0"
while getopts ":hd:" opt; do
    case "$opt" in 
        "h")
            echo "$HELP"
            exit
            ;;
        "d")
            DEVICE="$OPTARG"
            ;;
        *)
            opt_error "$OPTARG"
            echo "$PREHELP"
            exit 1
            ;;
    esac
done
shift $(($OPTIND - 1))

echo "Randomizing MAC address on $DEVICE..."
sudo ifconfig "$DEVICE" down
sudo macchanger -r "$DEVICE"
sudo ifconfig "$DEVICE" up

