#!/bin/bash

# Configuration (from Environment Variables with Defaults)
CHIP="${CHIP:-gpiochip1}"
LINE="${LINE:-14}"
ON_TEMP="${ON_TEMP:-70000}"       # 70°C
OFF_TEMP="${OFF_TEMP:-50000}"      # 50°C
CHECK_INTERVAL="${CHECK_INTERVAL:-30}"   # Seconds
CONSUMER="${CONSUMER:-opi5-fan}"

echo "Starting Fan Control script with configuration:"
echo "  CHIP: $CHIP"
echo "  LINE: $LINE"
echo "  ON_TEMP: $ON_TEMP"
echo "  OFF_TEMP: $OFF_TEMP"
echo "  CHECK_INTERVAL: $CHECK_INTERVAL"
echo "  CONSUMER: $CONSUMER"

# State tracking
CURRENT_STATE="UNKNOWN"

# Kill any existing fan control processes on start
pkill -f "$CONSUMER" > /dev/null 2>&1

# Trap termination signals to ensure the fan is left in a safe state (ON) or OFF based on preference,
# let's leave it as it is or ensure we kill gpioset
cleanup() {
    echo "Received termination signal. Stopping fan..."
    pkill -f "$CONSUMER" > /dev/null 2>&1
    # Sink to GND
    gpioset -z -C "$CONSUMER" -c "$CHIP" "$LINE=0"
    exit 0
}

trap cleanup SIGINT SIGTERM

while true; do
    if [ ! -f /sys/class/thermal/thermal_zone0/temp ]; then
        echo "Error: Cannot read temperature from /sys/class/thermal/thermal_zone0/temp"
        sleep "$CHECK_INTERVAL"
        continue
    fi

    TEMP_RAW=$(cat /sys/class/thermal/thermal_zone0/temp)
    TEMP_C=$((TEMP_RAW / 1000))

    if [ "$TEMP_RAW" -gt "$ON_TEMP" ] && [ "$CURRENT_STATE" != "ON" ]; then
        # Kill the 'OFF' process, then start 'ON'
        pkill -f "$CONSUMER" > /dev/null 2>&1
        gpioset -z -C "$CONSUMER" -c "$CHIP" "$LINE=1"
        CURRENT_STATE="ON"
        echo "Fan state changed to ON. CPU Temp: ${TEMP_C}°C"

    elif [ "$TEMP_RAW" -lt "$OFF_TEMP" ] && [ "$CURRENT_STATE" != "OFF" ]; then
        # Kill the 'ON' process, then start 'OFF' (to sink the pin to GND)
        pkill -f "$CONSUMER" > /dev/null 2>&1
        gpioset -z -C "$CONSUMER" -c "$CHIP" "$LINE=0"
        CURRENT_STATE="OFF"
        echo "Fan state changed to OFF. CPU Temp: ${TEMP_C}°C"
    fi

    # sleep in background and wait allows trap to interrupt sleep immediately
    sleep "$CHECK_INTERVAL" &
    wait $!
done
