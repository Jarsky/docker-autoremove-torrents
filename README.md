# docker-autoremove-torrents

Docker image for the upstream `autoremove-torrents` PyPI package.

This wrapper installs the maintained upstream release directly from PyPI instead of cloning the older `patch-1` Git branch. It now also includes startup validation, an optional config bootstrap flow, explicit run modes, and a Docker health check.

## What Changed

- Uses `python:3.12-slim`
- Installs `autoremove-torrents==1.5.5` from PyPI
- Adds config validation before startup
- Adds `RUN_MODE=once|cron`
- Adds optional auto-creation of `config.yml`
- Adds a Docker `HEALTHCHECK`
- Documents common task layouts and Docker networking gotchas

## Build

```sh
git clone https://github.com/Jarsky/docker-autoremove-torrents.git
cd docker-autoremove-torrents
docker build -t auto-remove-torrents:latest .
```

If you want to override the packaged version:

```sh
docker build --build-arg AUTOREMOVE_TORRENTS_VERSION=1.5.5 -t auto-remove-torrents:latest .
```

## Runtime Behavior

On startup the container will:

1. Ensure a config file exists.
2. Optionally create `/app/config.yml` from the bundled example.
3. Validate the YAML structure and required task keys.
4. Print a short startup summary.
5. Run once or install a cron entry depending on `RUN_MODE`.

## Usage

The image expects a config file at `/app/config.yml` by default.

### docker run

```sh
docker run -d \
  --name auto-remove-torrents \
  -v /opt/autoremove-torrents/config.yml:/app/config.yml \
  -v /opt/autoremove-torrents/logs/autoremove-torrents.log:/var/log/autoremove-torrents.log \
  -e RUN_MODE=cron \
  -e CRON="*/5 * * * *" \
  auto-remove-torrents:latest
```

### docker compose

```yaml
services:
  autoremove-torrents:
    container_name: auto-remove-torrents
    image: auto-remove-torrents:latest
    volumes:
      - /opt/autoremove-torrents/config.yml:/app/config.yml
      - /opt/autoremove-torrents/logs/autoremove-torrents.log:/var/log/autoremove-torrents.log
    environment:
      RUN_MODE: "cron"
      CRON: "*/5 * * * *"
      OPTS: "-c /app/config.yml"
    restart: unless-stopped
```

## Environment Variables

- `RUN_MODE`
  - `cron` or `once`
  - Default: `cron`

- `CRON`
  - Cron schedule used when `RUN_MODE=cron`
  - Default: `*/5 * * * *`

- `OPTS`
  - Arguments passed to `autoremove-torrents`
  - Default: `-c /app/config.yml`

- `CONFIG_PATH`
  - Path to the config file used by validation and auto-bootstrap
  - Default: `/app/config.yml`

- `LOG_FILE`
  - Log file used by the wrapper and cron job
  - Default: `/var/log/autoremove-torrents.log`

- `AUTO_CREATE_CONFIG`
  - If `true`, create `CONFIG_PATH` from the bundled example when it is missing
  - Default: `true`

## Health Check

The image includes a Docker `HEALTHCHECK` that verifies:

- the config file exists and is readable
- the log file is writable
- the config passes validation
- `cron` is running when `RUN_MODE=cron`

It does not try to connect to qBittorrent directly, because temporary client outages should not automatically mark the container unhealthy.

## Configuration Notes

The bundled example file is [config.example.yml](/c:/Dev/Projects/docker-autoremove-torrents/config.example.yml:1).

Important for Docker users:

- `127.0.0.1` inside the container refers to the container itself, not your host or qBittorrent server.
- In most setups you should use:
  - a LAN IP like `http://192.168.1.100:8080`
  - a Docker service name if both containers share a network
  - or an explicit host mapping if you are connecting back to the Docker host

## Task Examples

### Simple qBittorrent task

```yaml
my_task:
  client: qbittorrent
  host: http://192.168.1.100:8080
  username: admin
  password: adminadmin
  strategies:
    keep_until_seeded:
      all_categories: true
      ratio: 1
      seeding_time: 604800
  delete_data: true
```

### Multiple tasks

```yaml
movies:
  client: qbittorrent
  host: http://qbittorrent:8080
  username: admin
  password: adminadmin
  strategies:
    movies_default:
      categories:
        - movies
      ratio: 1.5
      seeding_time: 1209600
  delete_data: true

tv:
  client: qbittorrent
  host: http://qbittorrent:8080
  username: admin
  password: adminadmin
  strategies:
    tv_default:
      categories:
        - tv
      seeding_time: 432000
  delete_data: false
```

### Category-based strategy split

```yaml
tracker_split:
  client: qbittorrent
  host: http://qbittorrent:8080
  username: admin
  password: adminadmin
  strategies:
    private_tracker:
      categories:
        - IPT
      ratio: 1
      seeding_time: 1209600
    everything_else:
      all_categories: true
      excluded_categories:
        - IPT
      seeding_time: 259200
  delete_data: true
```

### Dry-run example

```sh
docker run --rm \
  -v /opt/autoremove-torrents/config.yml:/app/config.yml \
  -e RUN_MODE=once \
  -e OPTS="-c /app/config.yml --view --debug" \
  auto-remove-torrents:latest
```

### `delete_data` behavior

- `delete_data: true`
  - Removes the torrent and its data when a strategy matches.

- `delete_data: false`
  - Removes the torrent from the client but leaves the downloaded data behind.

## Common Arguments

- `--view` or `-v`
  - Show what would be removed without deleting torrents.

- `--conf` or `-c`
  - Path to the configuration file.

- `--task` or `-t`
  - Run a specific task only.

- `--log` or `-l`
  - Path used by `autoremove-torrents` for log output.

- `--debug` or `-d`
  - Enables debug logging.
  - Writes debug log output and also enables debug messages on stdout/stderr.

## CLI Notes

- The packaged `autoremove-torrents` `1.5.5` parser supports exactly these flags:
  - `-v` / `--view`
  - `-c` / `--conf`
  - `-t` / `--task`
  - `-l` / `--log`
  - `-d` / `--debug`
- It does not provide a working `-h` or `--help` flag in this upstream version.

## Notes

- The container validates config structure before starting, but it does not validate live connectivity to qBittorrent.
- The auto-created config is only a starter template and must still be edited with your real client details.
- For scheduled use, `docker logs` will show the wrapper startup and the mounted log file will capture scheduled `autoremove-torrents` runs.
- PyPI package: https://pypi.org/project/autoremove-torrents/
