#!/bin/sh

# MQTT Broker settings
BROKER_ADDR="193.169.2.1"
PORT=1883
USERNAME="thingino"
PASSWORD="brokerpass"
TOPIC="camera"

# Commands
BUSYBOX_BINARY="busybox"
MOTOR_BINARY="motors"
MQTT_BINARY="mosquitto_sub"
IRCUT_CMD="ircut"
IRLED_CMD="irled"
COLOR_CMD="color"
DAYNIGHT_CMD="daynight"
IAC_CMD="iac"
IMP_CMD="imp-control"
PTZ_PRESET_CMD="ptz_presets"

# Night vision and IR commands
process_ir_command() {
	case "$1" in
		"night-on") echo "Switching to night mode"; $IRCUT_CMD on ;;
		"night-off") echo "Switching to day mode"; $IRCUT_CMD off ;;
		"night-toggle") echo "Toggling night/day mode"; $IRCUT_CMD toggle ;;
		"ir850-on") echo "IR850 on"; $IRLED_CMD on ir850 ;;
		"ir850-off") echo "IR850 off"; $IRLED_CMD off ir850 ;;
		"ir850-toggle") echo "IR850 toggle"; $IRLED_CMD toggle ir850 ;;
		"ir940-on") echo "IR940 on"; $IRLED_CMD on ir940 ;;
		"ir940-off") echo "IR940 off"; $IRLED_CMD off ir940 ;;
		"ir940-toggle") echo "IR940 toggle"; $IRLED_CMD toggle ir940 ;;
		"irwhite-on") echo "White IR on"; $IRLED_CMD on white ;;
		"irwhite-off") echo "White IR off"; $IRLED_CMD off white ;;
		"irwhite-toggle") echo "White IR toggle"; $IRLED_CMD toggle white ;;
		"color-on") echo "Color mode on"; $COLOR_CMD on ;;
		"color-off") echo "Color mode off"; $COLOR_CMD off ;;
		"color-toggle") echo "Toggling color mode"; $COLOR_CMD toggle ;;
		"daynight-day") echo "Switching to day mode"; $DAYNIGHT_CMD day ;;
		"daynight-night") echo "Switching to night mode"; $DAYNIGHT_CMD night ;;
		"daynight-toggle") echo "Toggling day/night mode"; $DAYNIGHT_CMD toggle ;;
		*) echo "Unknown IR command: $1" ;;
	esac
}

# Image adjustments
process_image_command() {
	case "$1" in
		"flip-none") echo "Disable image flip"; $IMP_CMD 0 ;;
		"flip-mirror") echo "Image mirror"; $IMP_CMD 1 ;;
		"flip-flip") echo "Image flip"; $IMP_CMD 2 ;;
		"flip-flip_and_mirror") echo "image flip and mirror"; $IMP_CMD 3 ;;
		*) echo "Unknown Image command: $1" ;;
	esac
}

# General commands
process_general_command() {
	case "$1" in
		"reboot") echo "Restarting..."; $BUSYBOX_BINARY reboot -d 1 -f ;;
		"siren-on") echo "Activating Siren"; $IAC_CMD -f file.pcm;;
		"siren-off") echo "Killing Siren"; kill pid;;
		*) echo "Unknown general command: $1" ;;
	esac
}

# PTZ movement commands
process_ptz_command() {
	local direction speed stepx stepy
	direction=$(echo "$1" | cut -d':' -f1)
	speed=$(echo "$1" | cut -d':' -f2)
	stepx=$(echo "$1" | cut -d':' -f3)
	stepy=$(echo "$1" | cut -d':' -f4)

	case "$direction" in
		"ptz-topleft") echo "Moving top-left"; $MOTOR_BINARY -s "$speed" -d g -x "$stepx" -y "$stepy" ;;
		"ptz-left") echo "Moving left"; $MOTOR_BINARY -s "$speed" -d g -x "$stepx" ;;
		"ptz-bottomleft") echo "Moving bottom-left"; $MOTOR_BINARY -s "$speed" -d g -x "$stepx" -y "$stepy" ;;
		"ptz-topright") echo "Moving top-right"; $MOTOR_BINARY -s "$speed" -d g -x "$stepx" -y "$stepy" ;;
		"ptz-right") echo "Moving right"; $MOTOR_BINARY -s "$speed" -d g -x "$stepx" ;;
		"ptz-bottomright") echo "Moving bottom-right"; $MOTOR_BINARY -s "$speed" -d g -x "$stepx" -y "$stepy" ;;
		"ptz-up") echo "Moving up"; $MOTOR_BINARY -s "$speed" -d g -y "$stepy" ;;
		"ptz-down") echo "Moving down"; $MOTOR_BINARY -s "$speed" -d g -y "$stepy" ;;
		"ptz-home") echo "Moving to home"; $MOTOR_BINARY -s "$speed" -d b ;;
		"ptz-preset") echo "Moving to preset"; $MOTOR_BINARY -s "$speed" -d h -x "$stepx" -y "$stepy" ;;
		"ptz-reset") echo "Resetting PTZ"; $MOTOR_BINARY -r ;;
		*) echo "Unknown PTZ command: $direction" ;;
	esac
}

# Main processing function for MQTT messages
process_command() {
	case "$2" in
		"camera/$1/night") process_ir_command "$3" ;;
		"camera/$1/image") process_image_command "$3" ;;
		"camera/$1/general") process_general_command "$3" ;;
		"camera/$1/ptz") process_ptz_command "$3" ;;
		*) echo "Unknown topic: $2" ;;
	esac
}

# Main loop to read MQTT messages
main_loop() {
	local device_name="$1"
	local debug="$2"

	echo "Starting MQTT subscription loop for device: $device_name"
	while true; do
		$MQTT_BINARY -v -h "$BROKER_ADDR" -p "$PORT" -u "$USERNAME" -P "$PASSWORD" -t "$TOPIC/$1/#" |
		while read -r line; do
			topic=$(echo "$line" | cut -d' ' -f1)
			payload=$(echo "$line" | cut -d' ' -f2-)

			[ "$debug" = "debug" ] && echo "Received: topic=$topic, payload=$payload"

			# Split and process each command in payload
			while [ -n "$payload" ]; do
				command=$(echo "$payload" | cut -d';' -f1)
				payload=$(echo "$payload" | sed "s/^$command;*//")

				[ "$debug" = "debug" ] && echo "Processing command: $command"
				process_command "$device_name" "$topic" "$command"
			done
		done
		sleep 10
	done
}

# Entry point
if [ -z "$1" ]; then
    echo "Usage: $0 <device_name> [debug]"
    echo "Description:"
    echo "  device_name - The name of the device to register with the MQTT broker for receiving commands."
    echo "  debug       - Optional. If specified, the script runs in the foreground and displays debug information."
    echo ""
    echo "Example Commands:"
    echo "  $0 my-camera1-name               # Runs in the background without debug output"
    echo "  $0 my-camera1-name debug          # Runs in the foreground with debug output"
    echo ""
    echo "Command format in payload:"
    echo "  <command> or <command1>;<command2>  # Multiple commands can be separated by semicolons"
    exit 1
fi

main_loop "$1" "$2"
