#!/usr/bin/env python3
"""Run PCB defect detection with an RKNN model on RK3588.

The script implements standard YOLO post-processing:
confidence thresholding, per-class NMS, box drawing, and result file export.
Displayed confidence values are the model scores after post-processing.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np
from rknnlite.api import RKNNLite


CLASS_NAMES = [
    "Mouse_bite",
    "Open_circuit",
    "Short",
    "Spur",
    "Spurious_copper",
]

COLORS = [
    (40, 180, 255),
    (255, 80, 80),
    (80, 220, 220),
    (80, 180, 255),
    (120, 255, 120),
    (220, 120, 255),
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run RKNN PCB defect detection.")
    parser.add_argument("--model", required=True, help="RKNN model path")
    parser.add_argument("--image", required=True, help="Input PCB image")
    parser.add_argument("--time_file", default="", help="Optional timestamp file")
    parser.add_argument("--output_dir", required=True, help="Output directory")
    parser.add_argument("--conf", type=float, default=0.25, help="Confidence threshold")
    parser.add_argument("--iou", type=float, default=0.45, help="NMS IoU threshold")
    parser.add_argument("--imgsz", type=int, default=640, help="Model input size")
    return parser.parse_args()


def letterbox(image: np.ndarray, size: int) -> tuple[np.ndarray, float, tuple[float, float]]:
    height, width = image.shape[:2]
    gain = min(size / width, size / height)
    new_width = int(round(width * gain))
    new_height = int(round(height * gain))
    pad_x = (size - new_width) / 2
    pad_y = (size - new_height) / 2

    resized = cv2.resize(image, (new_width, new_height), interpolation=cv2.INTER_LINEAR)
    canvas = np.full((size, size, 3), 114, dtype=np.uint8)
    left = int(round(pad_x - 0.1))
    top = int(round(pad_y - 0.1))
    canvas[top : top + new_height, left : left + new_width] = resized
    return canvas, gain, (pad_x, pad_y)


def normalize_output(outputs: list[np.ndarray]) -> np.ndarray:
    if not outputs:
        raise RuntimeError("RKNN inference returned no outputs")

    pred = np.squeeze(np.asarray(outputs[0]))
    if pred.ndim != 2:
        raise RuntimeError(f"Unsupported RKNN output shape: {outputs[0].shape}")

    expected_channels = 4 + len(CLASS_NAMES)
    if pred.shape[0] == expected_channels:
        pred = pred.T
    elif pred.shape[1] != expected_channels:
        raise RuntimeError(f"Unexpected YOLO output shape: {outputs[0].shape}")
    return pred.astype(np.float32, copy=False)


def xywh_to_xyxy(boxes: np.ndarray) -> np.ndarray:
    xyxy = np.empty_like(boxes)
    xyxy[:, 0] = boxes[:, 0] - boxes[:, 2] / 2
    xyxy[:, 1] = boxes[:, 1] - boxes[:, 3] / 2
    xyxy[:, 2] = boxes[:, 0] + boxes[:, 2] / 2
    xyxy[:, 3] = boxes[:, 1] + boxes[:, 3] / 2
    return xyxy


def nms_xyxy(boxes: np.ndarray, scores: np.ndarray, iou_threshold: float) -> list[int]:
    if len(boxes) == 0:
        return []
    x1, y1, x2, y2 = boxes.T
    areas = np.maximum(0, x2 - x1) * np.maximum(0, y2 - y1)
    order = scores.argsort()[::-1]
    keep: list[int] = []

    while order.size > 0:
        i = int(order[0])
        keep.append(i)
        if order.size == 1:
            break

        xx1 = np.maximum(x1[i], x1[order[1:]])
        yy1 = np.maximum(y1[i], y1[order[1:]])
        xx2 = np.minimum(x2[i], x2[order[1:]])
        yy2 = np.minimum(y2[i], y2[order[1:]])

        inter = np.maximum(0, xx2 - xx1) * np.maximum(0, yy2 - yy1)
        union = areas[i] + areas[order[1:]] - inter
        iou = inter / np.maximum(union, 1e-6)
        order = order[1:][iou <= iou_threshold]
    return keep


def postprocess(
    pred: np.ndarray,
    conf_threshold: float,
    iou_threshold: float,
    image_shape: tuple[int, int],
    gain: float,
    pad: tuple[float, float],
    input_size: int,
) -> list[dict]:
    boxes_xywh = pred[:, :4].copy()
    scores_all = pred[:, 4:]

    if np.nanmax(boxes_xywh) <= 2.0:
        boxes_xywh *= input_size

    boxes = xywh_to_xyxy(boxes_xywh)
    pad_x, pad_y = pad
    boxes[:, [0, 2]] = (boxes[:, [0, 2]] - pad_x) / gain
    boxes[:, [1, 3]] = (boxes[:, [1, 3]] - pad_y) / gain

    image_h, image_w = image_shape
    boxes[:, [0, 2]] = np.clip(boxes[:, [0, 2]], 0, image_w - 1)
    boxes[:, [1, 3]] = np.clip(boxes[:, [1, 3]], 0, image_h - 1)

    class_ids = scores_all.argmax(axis=1)
    scores = scores_all.max(axis=1)
    detections: list[dict] = []

    for cls_id in range(len(CLASS_NAMES)):
        mask = (class_ids == cls_id) & (scores >= conf_threshold)
        if not np.any(mask):
            continue
        cls_indices = np.nonzero(mask)[0]
        keep = nms_xyxy(boxes[cls_indices], scores[cls_indices], iou_threshold)
        for local_idx in keep:
            idx = int(cls_indices[local_idx])
            detections.append(
                {
                    "class_id": cls_id,
                    "class_name": CLASS_NAMES[cls_id],
                    "confidence": float(scores[idx]),
                    "box": boxes[idx].round().astype(int).tolist(),
                }
            )

    detections.sort(key=lambda item: item["confidence"], reverse=True)
    return detections


def draw_detections(image: np.ndarray, detections: list[dict]) -> np.ndarray:
    output = image.copy()
    for det in detections:
        x1, y1, x2, y2 = det["box"]
        color = COLORS[det["class_id"] % len(COLORS)]
        label = f"{det['class_name']} {det['confidence']:.2f}"
        cv2.rectangle(output, (x1, y1), (x2, y2), color, 2)
        cv2.putText(output, label, (x1, max(20, y1 - 5)), cv2.FONT_HERSHEY_SIMPLEX, 0.6, color, 2)
    return output


def read_timestamp(time_file: str) -> str:
    if not time_file:
        return "Unknown"
    path = Path(time_file)
    if not path.exists():
        return "Unknown"
    text = path.read_text(encoding="utf-8", errors="ignore").strip()
    return text or "Unknown"


def write_result_txt(path: Path, detections: list[dict], timestamp: str) -> None:
    if detections:
        flag = "YES"
        count = str(len(detections))
        detail = ", ".join(f"{det['class_name']} {det['confidence']:.2f}" for det in detections)
    else:
        flag = "NO"
        count = "0"
        detail = "None"
    path.write_text(f"{flag}\n{count}\n{detail}\n{timestamp}\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    image_bgr = cv2.imread(args.image)
    if image_bgr is None:
        raise FileNotFoundError(args.image)

    input_bgr, gain, pad = letterbox(image_bgr, args.imgsz)
    input_rgb = cv2.cvtColor(input_bgr, cv2.COLOR_BGR2RGB)
    input_tensor = np.expand_dims(input_rgb, axis=0)

    rknn = RKNNLite()
    ret = rknn.load_rknn(args.model)
    if ret != 0:
        raise RuntimeError(f"load_rknn failed: {ret}")
    ret = rknn.init_runtime(core_mask=RKNNLite.NPU_CORE_AUTO)
    if ret != 0:
        rknn.release()
        raise RuntimeError(f"init_runtime failed: {ret}")

    try:
        outputs = rknn.inference(inputs=[input_tensor])
    finally:
        rknn.release()

    pred = normalize_output(outputs)
    detections = postprocess(pred, args.conf, args.iou, image_bgr.shape[:2], gain, pad, args.imgsz)
    result_image = draw_detections(image_bgr, detections)

    result_image_path = output_dir / "result.jpg"
    result_txt_path = output_dir / "result.txt"
    cv2.imwrite(str(result_image_path), result_image)
    write_result_txt(result_txt_path, detections, read_timestamp(args.time_file))

    print(f"Detections: {len(detections)}")
    print(f"Saved image: {result_image_path}")
    print(f"Saved text: {result_txt_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
