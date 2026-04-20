FROM python:3.12-slim

ARG AUTOREMOVE_TORRENTS_VERSION=1.5.5

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    CONFIG_PATH="/app/config.yml" \
    LOG_FILE="/var/log/autoremove-torrents.log" \
    OPTS="-c /app/config.yml" \
    RUN_MODE="cron" \
    CRON="*/5 * * * *" \
    AUTO_CREATE_CONFIG="true"

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends cron procps \
    && python -m pip install --no-cache-dir "autoremove-torrents==${AUTOREMOVE_TORRENTS_VERSION}" \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY cron.sh /usr/bin/cron.sh
COPY healthcheck.sh /usr/bin/healthcheck.sh
COPY validate_config.py /usr/local/bin/validate_config.py
RUN chmod +x /usr/bin/cron.sh /usr/bin/healthcheck.sh /usr/local/bin/validate_config.py \
    && touch /var/log/autoremove-torrents.log

COPY config.example.yml /app/config.example.yml
COPY config.example.yml /app/config.yml

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 CMD ["/bin/sh", "/usr/bin/healthcheck.sh"]

ENTRYPOINT ["/bin/sh", "/usr/bin/cron.sh"]
