#!/usr/bin/env sh
set -eu

CONFIG_PATH="${CONFIG_PATH:-/app/config.yml}"
LOG_FILE="${LOG_FILE:-/var/log/autoremove-torrents.log}"
RUN_MODE="${RUN_MODE:-cron}"

[ -r "$CONFIG_PATH" ] || exit 1
[ -w "$LOG_FILE" ] || exit 1
python /usr/local/bin/validate_config.py "$CONFIG_PATH" >/dev/null 2>&1 || exit 1

if [ "$RUN_MODE" = "cron" ]; then
    pgrep -x cron >/dev/null 2>&1 || exit 1
fi

exit 0
