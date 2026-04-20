#!/usr/bin/env sh
set -eu

APP_DIR="/app"
CONFIG_PATH="${CONFIG_PATH:-$APP_DIR/config.yml}"
DEFAULT_CONFIG_PATH="$APP_DIR/config.example.yml"
LOG_FILE="${LOG_FILE:-/var/log/autoremove-torrents.log}"
CRON_FILE="/tmp/autoremove-torrents.cron"
DEFAULT_OPTS="-c $CONFIG_PATH"
RUN_OPTS="${OPTS:-$DEFAULT_OPTS}"
RUN_MODE="${RUN_MODE:-cron}"
AUTO_CREATE_CONFIG="${AUTO_CREATE_CONFIG:-true}"

touch "$LOG_FILE"

bootstrap_config() {
    if [ -f "$CONFIG_PATH" ]; then
        return 0
    fi

    if [ "$AUTO_CREATE_CONFIG" = "true" ]; then
        echo "INFO: Config not found at $CONFIG_PATH. Creating it from $DEFAULT_CONFIG_PATH."
        cp "$DEFAULT_CONFIG_PATH" "$CONFIG_PATH"
        echo "WARN: The generated config is only a starter template and still needs your real torrent client settings."
        return 0
    fi

    echo "ERROR: Config file not found at $CONFIG_PATH and AUTO_CREATE_CONFIG is disabled." >&2
    exit 1
}

print_startup_summary() {
    echo "INFO: autoremove-torrents version: $(python -c "from autoremovetorrents.version import __version__; print(__version__)")"
    echo "INFO: run mode: $RUN_MODE"
    echo "INFO: config path: $CONFIG_PATH"
    echo "INFO: run options: $RUN_OPTS"
}

bootstrap_config
python /usr/local/bin/validate_config.py "$CONFIG_PATH"
print_startup_summary

case "$RUN_MODE" in
    once)
        echo "INFO: Running autoremove-torrents once."
        exec /bin/sh -c "/usr/local/bin/autoremove-torrents $RUN_OPTS"
        ;;
    cron)
        if [ -z "${CRON:-}" ]; then
            echo "ERROR: RUN_MODE=cron requires CRON to be set." >&2
            exit 1
        fi

        echo "INFO: Installing cron schedule: $CRON"
        echo "$CRON /usr/local/bin/autoremove-torrents $RUN_OPTS >> $LOG_FILE 2>&1" > "$CRON_FILE"
        crontab "$CRON_FILE"
        rm -f "$CRON_FILE"

        echo "INFO: Starting cron ..."
        cron
        echo "INFO: cron started"

        exec tail -F "$LOG_FILE"
        ;;
    *)
        echo "ERROR: Unsupported RUN_MODE '$RUN_MODE'. Use 'once' or 'cron'." >&2
        exit 1
        ;;
esac
