#!/usr/bin/env python3
"""Convert an ONNX model to RKNN format."""

from __future__ import annotations

import argparse
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert ONNX to RKNN.")
    parser.add_argument("--onnx", required=True, help="Input ONNX model")
    parser.add_argument("--output", required=True, help="Output RKNN model path")
    parser.add_argument("--target", default="rk3588", help="Rockchip target platform")
    parser.add_argument("--quantize", action="store_true", help="Enable quantization")
    parser.add_argument("--dataset", default="", help="Calibration dataset txt for quantization")
    parser.add_argument("--optimization-level", type=int, default=3, help="RKNN optimization level")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    from rknn.api import RKNN

    onnx_path = Path(args.onnx)
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    rknn = RKNN(verbose=False)
    rknn.config(
        mean_values=[[0, 0, 0]],
        std_values=[[255, 255, 255]],
        target_platform=args.target,
        optimization_level=args.optimization_level,
    )

    ret = rknn.load_onnx(model=str(onnx_path))
    if ret != 0:
        raise RuntimeError(f"load_onnx failed: {ret}")

    dataset = args.dataset or None
    ret = rknn.build(do_quantization=args.quantize, dataset=dataset)
    if ret != 0:
        raise RuntimeError(f"RKNN build failed: {ret}")

    ret = rknn.export_rknn(str(output_path))
    if ret != 0:
        raise RuntimeError(f"export_rknn failed: {ret}")

    rknn.release()
    print(f"Exported RKNN: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
