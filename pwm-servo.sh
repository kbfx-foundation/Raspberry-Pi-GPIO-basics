#!/bin/bash
# SG90 sweep on GPIO13 (header pin 33), hardware PWM1
# Requires: dtoverlay=pwm-2chan,pin=12,func=4,pin2=13,func2=4
#
# Usage:
#   chmod +x pwm-servo.sh
#   ./pwm-servo.sh
#   Ctrl+C to stop (returns to center, then disables PWM)

set -u

CHIP=/sys/class/pwm/pwmchip0
CH=1
PERIOD=20000000
MIN=600000
MAX=2400000
CENTER=1500000
STEP=20000
SLEEP=0.02

sudo -v
sudo pinctrl set 13 a0

if [ ! -d "$CHIP/pwm$CH" ]; then
    echo "$CH" | sudo tee "$CHIP/export" >/dev/null
    sleep 0.1
fi

echo "$PERIOD" | sudo tee "$CHIP/pwm$CH/period" >/dev/null
echo "$CENTER" | sudo tee "$CHIP/pwm$CH/duty_cycle" >/dev/null
echo 1         | sudo tee "$CHIP/pwm$CH/enable" >/dev/null

cleanup() {
    echo "$CENTER" | sudo tee "$CHIP/pwm$CH/duty_cycle" >/dev/null 2>&1 || true
    sleep 0.4
    echo 0 | sudo tee "$CHIP/pwm$CH/enable" >/dev/null 2>&1 || true
}

trap 'cleanup; exit 0' INT TERM
trap cleanup EXIT

duty=$MIN
dir=1

echo "Sweeping $MIN..$MAX ns on GPIO13. Ctrl+C to stop."
while true; do
    echo "$duty" | sudo tee "$CHIP/pwm$CH/duty_cycle" >/dev/null

    duty=$((duty + dir * STEP))
    if [ "$duty" -ge "$MAX" ]; then
        duty=$MAX
        dir=-1
    elif [ "$duty" -le "$MIN" ]; then
        duty=$MIN
        dir=1
    fi

    sleep "$SLEEP"
done
