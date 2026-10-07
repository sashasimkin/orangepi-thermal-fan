# orangepi-thermal-fan

Small systemd service for controlling the Orange Pi 5 fan from the SoC temperature.
It runs directly on Armbian, with no container runtime or Kubernetes resources.

The service is enabled in `sysinit.target` and ordered before `basic.target`, so it
starts during early boot as soon as the GPIO device and local filesystems are ready.
It sets the fan on immediately when the temperature sensor cannot be read, and
keeps it on when the initial temperature is between the on and off thresholds.

## Install

Install `gpioset` from libgpiod, then run:

```sh
sudo ./install.sh
```

To install and enable the unit without starting it yet (for a controlled handoff
from another GPIO owner):

```sh
sudo ./install.sh --install-only
sudo systemctl start orangepi-thermal-fan.service
```

The script and unit are installed under `/usr/local/lib/orangepi-thermal-fan/` and
`/etc/systemd/system/`. Logs are available with:

```sh
sudo journalctl -u orangepi-thermal-fan.service -f
```

## Configuration

Edit `/etc/default/orangepi-thermal-fan` and restart the service. Defaults:

| Variable | Default | Meaning |
| --- | --- | --- |
| `CHIP` | `gpiochip1` | GPIO chip |
| `LINE` | `14` | Fan GPIO line |
| `ON_TEMP` | `80000` | Turn fan on at or above this temperature, in millidegrees Celsius |
| `OFF_TEMP` | `70000` | Turn fan off below this temperature, in millidegrees Celsius |
| `CHECK_INTERVAL` | `5` | Seconds between temperature checks |
| `CONSUMER` | `orangepi-thermal-fan` | GPIO line consumer label |

```sh
sudo systemctl restart orangepi-thermal-fan.service
```

The temperature is read from `/sys/class/thermal/thermal_zone0/temp`.
