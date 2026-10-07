#!/usr/bin/env bash
set -euo pipefail

INSTALL_ONLY=false
case "${1:-}" in
  "") ;;
  --install-only) INSTALL_ONLY=true ;;
  *) echo "Usage: $0 [--install-only]" >&2; exit 2 ;;
esac

if (( EUID != 0 )); then
  echo "Run this installer as root (for example: sudo $0)." >&2
  exit 1
fi

if ! command -v gpioset >/dev/null 2>&1; then
  echo "gpioset is required. Install the libgpiod tools package first." >&2
  exit 1
fi

SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR=/usr/local/lib/orangepi-thermal-fan

install -d -m 0755 "$INSTALL_DIR"
install -m 0755 "$SOURCE_DIR/fan-control.sh" "$INSTALL_DIR/fan-control.sh"
install -m 0644 "$SOURCE_DIR/orangepi-thermal-fan.service" /etc/systemd/system/orangepi-thermal-fan.service

if [[ ! -e /etc/default/orangepi-thermal-fan ]]; then
  install -m 0644 "$SOURCE_DIR/orangepi-thermal-fan.default" /etc/default/orangepi-thermal-fan
fi

systemctl daemon-reload
systemctl enable orangepi-thermal-fan.service

if [[ "$INSTALL_ONLY" == true ]]; then
  echo "Installed and enabled. Start the service after the previous GPIO owner has stopped."
else
  systemctl restart --no-block orangepi-thermal-fan.service || systemctl start orangepi-thermal-fan.service
  echo "Installed and enabled orangepi-thermal-fan.service."
fi
