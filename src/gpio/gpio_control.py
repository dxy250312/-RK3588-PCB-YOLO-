#!/usr/bin/env python3
"""Small GPIO helper for RK3588 sysfs GPIO prototyping."""

from __future__ import annotations

import argparse
from pathlib import Path
from time import sleep


SYSFS_GPIO = Path("/sys/class/gpio")


def export_gpio(number: int) -> None:
    path = SYSFS_GPIO / f"gpio{number}"
    if path.exists():
        return
    (SYSFS_GPIO / "export").write_text(str(number), encoding="utf-8")


def set_direction(number: int, direction: str) -> None:
    (SYSFS_GPIO / f"gpio{number}" / "direction").write_text(direction, encoding="utf-8")


def read_value(number: int) -> int:
    value = (SYSFS_GPIO / f"gpio{number}" / "value").read_text(encoding="utf-8").strip()
    return int(value)


def write_value(number: int, value: int) -> None:
    (SYSFS_GPIO / f"gpio{number}" / "value").write_text(str(int(bool(value))), encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Read or write sysfs GPIO.")
    parser.add_argument("--gpio", type=int, required=True, help="sysfs GPIO number")
    parser.add_argument("--direction", choices=["in", "out"], required=True)
    parser.add_argument("--value", type=int, choices=[0, 1], help="Output value")
    parser.add_argument("--hold-ms", type=int, default=0, help="Hold output high/low then return to 0")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    export_gpio(args.gpio)
    set_direction(args.gpio, args.direction)

    if args.direction == "in":
        print(read_value(args.gpio))
        return 0

    value = 0 if args.value is None else args.value
    write_value(args.gpio, value)
    if args.hold_ms > 0:
        sleep(args.hold_ms / 1000.0)
        write_value(args.gpio, 0)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
