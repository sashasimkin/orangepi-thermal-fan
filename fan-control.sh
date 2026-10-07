#!/usr/bin/env bash
set -uo pipefail

CHIP="${CHIP:-gpiochip1}"
LINE="${LINE:-14}"
ON_TEMP="${ON_TEMP:-80000}"
OFF_TEMP="${OFF_TEMP:-70000}"
CHECK_INTERVAL="${CHECK_INTERVAL:-5}"
CONSUMER="${CONSUMER:-orangepi-thermal-fan}"
TEMP_PATH=/sys/class/thermal/thermal_zone0/temp
CURRENT_STATE=UNKNOWN
GPIO_PID=

echo "Starting orangepi-thermal-fan (chip=$CHIP line=$LINE on=${ON_TEMP}mC off=${OFF_TEMP}mC interval=${CHECK_INTERVAL}s)"

stop_gpio() {
  if [[ -n "$GPIO_PID" ]]; then
    kill "$GPIO_PID" 2>/dev/null || true
    wait "$GPIO_PID" 2>/dev/null || true
    GPIO_PID=
  fi
}

set_fan() {
  local value="$1"
  local state="$2"

  stop_gpio
  gpioset -C "$CONSUMER" -c "$CHIP" "$LINE=$value" &
  GPIO_PID=$!
  sleep 0.1
  if ! kill -0 "$GPIO_PID" 2>/dev/null; then
    wait "$GPIO_PID" || return 1
    echo "Error: gpioset exited before acquiring $CHIP line $LINE" >&2
    return 1
  fi

  CURRENT_STATE="$state"
  echo "Fan state changed to $CURRENT_STATE. CPU Temp: ${TEMP_C:-unknown}°C"
}

cleanup() {
  trap - EXIT INT TERM
  echo "Stopping fan controller."
  stop_gpio
  exit 0
}
trap cleanup EXIT INT TERM

while true; do
  if [[ ! -r "$TEMP_PATH" ]]; then
    echo "Cannot read $TEMP_PATH; keeping fan ON."
    TEMP_RAW=
  else
    IFS= read -r TEMP_RAW < "$TEMP_PATH" || TEMP_RAW=
  fi

  if [[ "$TEMP_RAW" =~ ^[0-9]+$ ]]; then
    TEMP_C=$((TEMP_RAW / 1000))
    if (( TEMP_RAW >= ON_TEMP )); then
      [[ "$CURRENT_STATE" == ON ]] || set_fan 1 ON
    elif (( TEMP_RAW < OFF_TEMP )); then
      [[ "$CURRENT_STATE" == OFF ]] || set_fan 0 OFF
    elif [[ "$CURRENT_STATE" == UNKNOWN ]]; then
      # In the hysteresis band, prefer active cooling on startup.
      set_fan 1 ON
    fi
  else
    TEMP_C=unknown
    [[ "$CURRENT_STATE" == ON ]] || set_fan 1 ON
  fi

  sleep "$CHECK_INTERVAL" &
  wait "$!"
done
