#!/usr/bin/env python3
"""Run a single-image YOLO prediction test."""

from __future__ import annotations

import argparse
from pathlib import Path

import cv2
from ultralytics import YOLO


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run YOLO prediction on one PCB image.")
    parser.add_argument("--weights", required=True, help="Trained .pt model")
    parser.add_argument("--image", required=True, help="Input image")
    parser.add_argument("--output", default="results/result_detect.jpg", help="Output image path")
    parser.add_argument("--conf", type=float, default=0.25)
    parser.add_argument("--iou", type=float, default=0.70)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--augment", action="store_true", help="Enable test-time augmentation")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    model = YOLO(args.weights)
    result = model.predict(
        source=args.image,
        conf=args.conf,
        iou=args.iou,
        imgsz=args.imgsz,
        augment=args.augment,
        verbose=False,
    )[0]

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    plotted = result.plot()
    cv2.imwrite(str(output_path), plotted)

    boxes = result.boxes
    count = 0 if boxes is None else len(boxes)
    print(f"Detections: {count}")
    print(f"Saved: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
