#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import sys
from typing import Any

import yaml


def fail(message: str) -> int:
    print(f"ERROR: {message}", file=sys.stderr)
    return 1


def validate_strategy(task_name: str, strategy_name: str, strategy_cfg: Any) -> None:
    if not isinstance(strategy_cfg, dict):
        raise ValueError(f"Task '{task_name}' strategy '{strategy_name}' must be a mapping.")

    supported_conditions = {
        "ratio",
        "seeding_time",
        "leeching_time",
        "upload_speed",
        "download_speed",
        "maximum_number",
        "minimum_seeders",
        "maximum_seeders",
        "minimum_size",
        "maximum_size",
        "free_space",
    }

    if not any(key in strategy_cfg for key in supported_conditions):
        raise ValueError(
            f"Task '{task_name}' strategy '{strategy_name}' does not define a remove condition. "
            f"Expected one of: {', '.join(sorted(supported_conditions))}."
        )


def validate_task(task_name: str, task_cfg: Any) -> None:
    if not isinstance(task_cfg, dict):
        raise ValueError(f"Task '{task_name}' must be a mapping.")

    required_keys = ("client", "host", "strategies")
    missing = [key for key in required_keys if key not in task_cfg]
    if missing:
        raise ValueError(f"Task '{task_name}' is missing required keys: {', '.join(missing)}.")

    strategies = task_cfg["strategies"]
    if not isinstance(strategies, dict) or not strategies:
        raise ValueError(f"Task '{task_name}' must define at least one strategy.")

    for strategy_name, strategy_cfg in strategies.items():
        validate_strategy(task_name, strategy_name, strategy_cfg)


def validate_config(path: Path) -> int:
    if not path.exists():
        return fail(f"Config file not found: {path}")
    if not path.is_file():
        return fail(f"Config path is not a file: {path}")

    try:
        with path.open("r", encoding="utf-8") as fh:
            config = yaml.safe_load(fh)
    except yaml.YAMLError as exc:
        return fail(f"YAML parsing failed for {path}: {exc}")
    except OSError as exc:
        return fail(f"Unable to read config file {path}: {exc}")

    if not isinstance(config, dict) or not config:
        return fail("Config file must define at least one task at the top level.")

    try:
        for task_name, task_cfg in config.items():
            validate_task(str(task_name), task_cfg)
    except ValueError as exc:
        return fail(str(exc))

    print(f"INFO: Config validation succeeded for {path} with {len(config)} task(s).")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate autoremove-torrents config.")
    parser.add_argument("config_path", help="Path to config.yml")
    args = parser.parse_args()
    return validate_config(Path(args.config_path))


if __name__ == "__main__":
    sys.exit(main())
