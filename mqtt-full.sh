#!/bin/sh

# MQTT Broker settings
BROKER="193.169.2.1"
PORT=1883
USERNAME="openipc"
PASSWORD="brokerpass"
SUB_TOPIC="camera/$1/#"
MOTOR_BINARY="ingenic-motor"
MQTT_BINARY="mosquitto_sub"

process_command() {
    local device_name=$1
    local topic=$2
    local command=$3

    case "$topic" in
        "camera/$device_name/night")
            case "$command" in
                "night-on")
                    echo "Switching to night mode"
                    /usr/sbin/ircut.sh on
                    ;;
                "night-off")
                    echo "Switching to day mode"
                    /usr/sbin/ircut.sh off
                    ;;
                "night-toggle")
                    echo "Toggling night/day mode"
                    /usr/sbin/ircut.sh toggle
                    ;;
                "ir850-on")
                    echo "IR1 on"
                    /usr/sbin/irled.sh on ir850
                    ;;
                "ir850-off")
                    echo "IR1 off"
                    /usr/sbin/irled.sh off ir850
                    ;;
                "ir850-toggle")
                    echo "IR1 off"
                    /usr/sbin/irled.sh toggle ir850
                    ;;
                "ir940-on")
                    echo "IR1 on"
                    /usr/sbin/irled.sh on ir940
                    ;;
                "ir940-off")
                    echo "IR1 off"
                    /usr/sbin/irled.sh off ir940
                    ;;
                "ir940-toggle")
                    echo "IR1 off"
                    /usr/sbin/irled.sh toggle ir940
                    ;;
                "irwhite-on")
                    echo "IR1 on"
                    /usr/sbin/irled.sh on white
                    ;;
                "irwhite-off")
                    echo "IR1 off"
                    /usr/sbin/irled.sh off white
                    ;;
                "irwhite-toggle")
                    echo "IR1 off"
                    /usr/sbin/irled.sh toggle white
                    ;;
                "color-on")
                    echo "IR1 on"
                    /usr/sbin/color.sh on
                    ;;
                "color-off")
                    echo "IR1 off"
                    /usr/sbin/color.sh off
                    ;;
                "daynight-day")
                    echo "day"
                    /usr/sbin/daynight.sh day
                    ;;
                "daynight-night")
                    echo "night"
                    /usr/sbin/daynight.sh night
                    ;;
                "daynight-toggle")
                    echo "daynight toggle"
                    /usr/sbin/daynight.sh toggle
                    ;;
                *)
                    echo "Unknown night command: $command"
                    ;;
            esac
            ;;
        "camera/$device_name/general")
            case "$command" in
                "reboot")
                    echo "rebooting"
                    /busybox reboot -d 1 -f
                    ;;
                "siren-on")
                    echo "Siren ON"
                    /usr/bin/iac 
                    ;;
                *)
                    echo "Unknown night command: $command"
                    ;;
            esac
            ;;
        "camera/$device_name/ptz")
            direction=$(echo "$command" | cut -d':' -f1)
            speed=$(echo "$command" | cut -d':' -f2)
            stepx=$(echo "$command" | cut -d':' -f3)
            stepy=$(echo "$command" | cut -d':' -f4)
            case "$direction" in
                "ptz-left")
                    echo "PTZ moving left with speed $speed and step $stepx"
                    $MOTOR_BINARY -s $speed -d g -x $stepx
                    ;;
                "ptz-topleft")
                    echo "PTZ moving top left with speed $speed, stepx $stepx, stepy $stepy"
                    $MOTOR_BINARY -s $speed -d g -x $stepx -y $stepy
                    ;;
                "ptz-topright")
                    echo "PTZ moving top right with speed $speed, stepx $stepx, stepy $stepy"
                    $MOTOR_BINARY -s $speed -d g -x $stepx -y $stepy
                    ;;
                "ptz-right")
                    echo "PTZ moving right with speed $speed and step $stepx"
                    $MOTOR_BINARY -s $speed -d g -x $stepx
                    ;;
                "ptz-bottomleft")
                    echo "PTZ moving bottom left with speed $speed, stepx $stepx, stepy $stepy"
                    $MOTOR_BINARY -s $speed -d g -x $stepx -y $stepy
                    ;;
                "ptz-bottomright")
                    echo "PTZ moving bottom right with speed $speed, stepx $stepx, stepy $stepy"
                    $MOTOR_BINARY -s $speed -d g -x $stepx -y $stepy
                    ;;
                "ptz-down")
                    echo "PTZ moving down with speed $speed and step $stepy"
                    $MOTOR_BINARY -s $speed -d g -y $stepy
                    ;;
                "ptz-up")
                    echo "PTZ moving up with speed $speed and step $stepy"
                    $MOTOR_BINARY -s $speed -d g -y $stepy
                    ;;
                "ptz-center")
                    echo "PTZ moving to center with speed $speed"
                    $MOTOR_BINARY -s $speed -d h -x 1270 -y 360
                    ;;
                "ptz-preset")
                    echo "PTZ moving to preset with speed $speed"
                    $MOTOR_BINARY -s $speed -d h -x $stepx -y $stepy 
                    ;;
                "ptz-reset")
                    echo "PTZ reset"
                    $MOTOR_BINARY -r
                    ;;
                *)
                    echo "Unknown PTZ direction: $direction"
                    ;;
            esac
            ;;
        *)
            echo "Unknown topic: $topic"
            ;;
    esac
}

main_loop() {
    echo "Starting main loop"
    local device_name="$1"
    local debug="$2"

    while true; do
        $MQTT_BINARY -v -h "$BROKER" -p "$PORT" -u "$USERNAME" -P "$PASSWORD" -t "$SUB_TOPIC" | while read -r line; do
            topic=$(echo "$line" | cut -d' ' -f1)
            payload=$(echo "$line" | cut -d' ' -f2-)

            if [[ "$2" == "debug" ]]; then 
                echo "Received topic: $topic, payload: $payload"
            fi

            # Split payload into commands and process each command
            while [ -n "$payload" ]; do
                command=$(echo "$payload" | cut -d';' -f1)
                # Update payload to remove the processed command
                payload=$(echo "$payload" | sed "s/^$command;*//")

                if [ -n "$command" ]; then
                    if [[ "$2" == "debug" ]]; then
                        echo "Processing command: $command"
                    fi
                    process_command "$device_name" "$topic" "$command"
                fi
            done
        done
        sleep 10
    done
}

if [ -z "$1" ]; then
    echo "Please specify a device name for broker registration"
    echo "Payload format: <command> or <command1>;<command2>"
elif [ "$2" == "debug" ]; then
    main_loop "$1" debug
else
    main_loop "$1" &
fi
