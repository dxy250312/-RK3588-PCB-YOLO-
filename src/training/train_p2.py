#!/usr/bin/env python3
"""Train a YOLOv11-P2 PCB defect detector."""

from __future__ import annotations

import argparse
from pathlib import Path

from ultralytics import YOLO


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Train a YOLOv11-P2 PCB defect model.")
    parser.add_argument("--model", default="configs/models/yolo11n-p2-pcb.yaml", help="Model YAML path")
    parser.add_argument("--data", default="configs/pcb_dataset.yaml", help="Dataset YAML path")
    parser.add_argument("--weights", default="", help="Optional pretrained weights, e.g. yolo11n.pt")
    parser.add_argument("--epochs", type=int, default=100)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--batch", type=int, default=16)
    parser.add_argument("--device", default="0", help="CUDA device id or cpu")
    parser.add_argument("--project", default="runs/train")
    parser.add_argument("--name", default="pcb_yolo11_p2")
    parser.add_argument("--lr0", type=float, default=0.01)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    model = YOLO(args.model)
    if args.weights:
        model = model.load(args.weights)

    model.train(
        data=args.data,
        epochs=args.epochs,
        imgsz=args.imgsz,
        batch=args.batch,
        device=args.device,
        project=args.project,
        name=args.name,
        lr0=args.lr0,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
