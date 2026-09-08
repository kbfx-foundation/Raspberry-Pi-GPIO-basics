#!/usr/bin/env bash
# Usage:
#   chmod +x ds18b20_poll.sh
#   ./ds18b20_poll.sh
#   Ctrl+C to stop
#
# Note: factory default is 12-bit (~750 ms conversion).
# The kernel w1_therm driver blocks on each read for that conversion,
# so INTERVAL below is a *minimum* gap after the read returns,
# not a guaranteed 2 Hz sample rate.

set -euo pipefail

DEVICE="28-00001065f40e"
W1_SLAVE="/sys/bus/w1/devices/${DEVICE}/w1_slave"
INTERVAL="0.5"   # seconds after each successful/failed read

if [[ ! -r "$W1_SLAVE" ]]; then
  echo "error: cannot read $W1_SLAVE" >&2
  exit 1
fi

# Ctrl+C / SIGTERM: print newline and exit 0
trap 'echo; exit 0' INT TERM

while true; do
  # w1_slave is two lines. Second line ends with t=milliC if CRC passed.
  raw="$(cat "$W1_SLAVE" 2>/dev/null || true)"

  if [[ "$raw" == *"YES"* ]]; then
    milli="$(printf '%s\n' "$raw" | sed -n 's/.*t=\([-0-9][0-9]*\).*/\1/p')"
    if [[ -n "$milli" ]]; then
      # milliC -> C with 3 decimal places (12-bit is 0.0625 C)
      awk -v m="$milli" 'BEGIN { printf "%.3f C\n", m/1000.0 }'
    else
      echo "error: CRC ok but no t= field"
    fi
  elif [[ "$raw" == *"NO"* ]]; then
    echo "error: CRC fail (pull-up / wiring / noise)"
  else
    echo "error: empty or unreadable w1_slave"
  fi

  sleep "$INTERVAL"
done
