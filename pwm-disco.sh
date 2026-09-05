#!/bin/bash
# Hardware PWM fade on GPIO12 / GPIO13 + blink on GPIO16
#
# Raspberry Pi 4B
# Requires in /boot/firmware/config.txt:
#   dtoverlay=pwm-2chan,pin=12,func=4,pin2=13,func2=4
# then reboot.
#
# Wiring (BCM numbers):
#   GPIO12 (header pin 32) -> resistor -> LED -> GND
#   GPIO13 (header pin 33) -> resistor -> LED -> GND
#   GPIO16 (header pin 36) -> resistor -> LED -> GND
#
# Usage:
#   chmod +x pwm_demo.sh
#   ./pwm_demo.sh
#   Ctrl+C to stop

set -u

CHIP=/sys/class/pwm/pwmchip0
PERIOD=1000000
STEP=150000
SLEEP=0.02

sudo -v
sudo pinctrl set 12 a0
sudo pinctrl set 13 a0
sudo pinctrl set 16 op dl

export_ch() {
    if [ ! -d "$CHIP/pwm$1" ]; then
        echo "$1" | sudo tee "$CHIP/export" >/dev/null
        sleep 0.1
    fi
}

export_ch 0
export_ch 1

setup_pwm() {
    echo "$PERIOD" | sudo tee "$CHIP/pwm$1/period" >/dev/null
    echo 0         | sudo tee "$CHIP/pwm$1/duty_cycle" >/dev/null
    echo 1         | sudo tee "$CHIP/pwm$1/enable" >/dev/null
}

setup_pwm 0
setup_pwm 1

cleanup() {
    echo 0 | sudo tee "$CHIP/pwm0/enable" >/dev/null 2>&1 || true
    echo 0 | sudo tee "$CHIP/pwm1/enable" >/dev/null 2>&1 || true
    sudo pinctrl set 12 op dl
    sudo pinctrl set 13 op dl
    sudo pinctrl set 16 op dl
}

trap 'cleanup; exit 0' INT TERM
trap cleanup EXIT

duty=0
dir=1
tick=0
led16=0

echo "Running. Press Ctrl+C to stop."
while true; do
    echo "$duty" | sudo tee "$CHIP/pwm0/duty_cycle" >/dev/null
    echo $((PERIOD - duty)) | sudo tee "$CHIP/pwm1/duty_cycle" >/dev/null

    duty=$((duty + dir * STEP))
    if [ "$duty" -ge "$PERIOD" ]; then
        duty=$PERIOD
        dir=-1
    elif [ "$duty" -le 0 ]; then
        duty=0
        dir=1
    fi

    tick=$((tick + 1))
    if [ $((tick % 15)) -eq 0 ]; then
        if [ "$led16" -eq 0 ]; then
            sudo pinctrl set 16 op dh
            led16=1
        else
            sudo pinctrl set 16 op dl
            led16=0
        fi
    fi

    sleep "$SLEEP"
done
