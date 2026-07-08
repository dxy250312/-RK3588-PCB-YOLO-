#!/usr/bin/env python3
"""Export YOLO weights to ONNX for RKNN conversion."""

from __future__ import annotations

import argparse
from pathlib import Path

from ultralytics import YOLO


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export YOLO .pt weights to ONNX.")
    parser.add_argument("--weights", required=True, help="Input .pt weights")
    parser.add_argument("--output", default="export", help="Output directory")
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--opset", type=int, default=12)
    parser.add_argument("--simplify", action="store_true", default=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    model = YOLO(args.weights)
    exported = model.export(
        format="onnx",
        imgsz=args.imgsz,
        opset=args.opset,
        simplify=args.simplify,
        dynamic=False,
        project=str(output_dir),
    )
    print(f"Exported ONNX: {exported}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
