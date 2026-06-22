#!/usr/bin/env bash


NAME=$(basename $0)
PREHELP="Try $NAME -h for more information."
HELP="Usage: $NAME [GLOBAL OPTIONS] [COMMAND] [COMMAND OPTIONS] [ARGUMENT]

options:
    -h    show this help

commands:
    help                   show this help

    set                    set the percentage threshold
        options:
            -p    enable threshold persistance
        arguments:
            percentage    the value [1-100] to set the percentage threshold to

    get                    get the current session's percentage threshold
        options:
            -p    get persisted percentage threshold

    disable-persist, dp    disable percentage threshold persistance
"
THRESHOLD_PATH="/sys/class/power_supply/BAT0/charge_control_end_threshold"
SERVICE_NAME="battery-threshold.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"

opt_error() {
    echo "Error: invalid option: -$1"
}


while getopts ":h" opt; do
    case "$opt" in 
        "h")
            echo "$HELP"
            exit
            ;;
        *)
            opt_error "$OPTARG"
            echo "$PREHELP"
            exit 1
            ;;
    esac
done
shift $(($OPTIND - 1))

COMMAND="$1"
if [[ "$#" -eq 0 ]] || [[ "$COMMAND" = "help" ]]; then
    echo "$HELP"
    exit
elif [[ "$COMMAND" = "set" ]] || [[ "$COMMAND" = "get" ]]; then
    OPTS="p"
elif [[ "$COMMAND" = "disable-persist" ]] || [[ "$COMMAND" = "dp" ]]; then
    sudo systemctl disable "$SERVICE_NAME"
    sudo trash "$SERVICE_PATH"
    echo "Persistance has been disabled."
    exit 0
else 
    echo "Error: Invalid command: $COMMAND"
    echo "$PREHELP"
    exit 1
fi
shift 1

PERSIST=false
while getopts ":$OPTS" opt; do
    case "$opt" in 
        "p")
            PERSIST=true
            ;;
        *)
            opt_error $OPTARG
            echo "$PREHELP"
            exit 1
            ;;
    esac
done
shift $(($OPTIND - 1))

if [[ "$COMMAND" = "set" ]]; then
    PERCENTAGE="$1"
    if [[ "$PERCENTAGE" -le 0 ]] || [[ "$PERCENTAGE" -gt 100 ]]; then
        echo "Error: invalid percentage"
        exit 1
    fi
    shift 1
fi

# done again to parse options after arguments
while getopts ":$OPTS" opt; do
    case "$opt" in 
        "p")
            PERSIST=true
            ;;
        *)
            opt_error $OPTARG
            echo "$PREHELP"
            exit 1
            ;;
    esac
done
shift $(($OPTIND - 1))

if [[ "$COMMAND" = "set" ]]; then
    echo $PERCENTAGE | sudo tee "$THRESHOLD_PATH" > /dev/null
    echo "Session battery percentage threshold has been set to $PERCENTAGE."

    # https://github.com/sreejithag/battery-charging-limiter-linux
    if "$PERSIST"; then
        echo "[Unit]
Description=Persist battery percentage threshold
After=multi-user.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo $PERCENTAGE > $THRESHOLD_PATH'

[Install]
WantedBy=multi-user.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
" | sudo tee "$SERVICE_PATH" > /dev/null
        
        sudo systemctl enable "$SERVICE_NAME"
        echo "Persistance has been enabled with a percentage threshold of $PERCENTAGE."
    fi
elif [[ "$COMMAND" = "get" ]]; then
    echo "Battery percentage threshold is set to $(cat "$THRESHOLD_PATH")."
    if $PERSIST; then
        ENABLED=$(systemctl is-enabled "$SERVICE_NAME")
        if [[ ! -e "$SERVICE_PATH" ]] || [[ "$ENABLED" != "enabled" ]]; then
            echo "Persistence is not enabled."
        else
            PERCENTAGE=$(
                cat "$SERVICE_PATH" \
                | grep -o "echo [0-9]*" \
                | awk '{ print $2 }' \
            )
            echo "Persistence is enabled with a percentage threshold of $PERCENTAGE."
        fi
    fi
fi

