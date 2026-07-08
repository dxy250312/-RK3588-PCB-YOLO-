# RKNN Deployment Notes

This project uses RKNN Toolkit 2 to convert ONNX models for RK3588.

## 1. Export ONNX

```bash
python src/export/export_onnx.py \
  --weights <project_root>/weights/best.pt \
  --output <project_root>/export \
  --imgsz 640 \
  --opset 12
```

## 2. Convert to RKNN

If a local ONNX model has already been exported, place it at:

```text
<project_root>/export/best.onnx
```

The ONNX model is a local input file for conversion and should not be committed.

```bash
python src/export/onnx_to_rknn.py \
  --onnx <project_root>/export/best.onnx \
  --output <project_root>/export/best-rk3588.rknn \
  --target rk3588
```

For FP16 deployment, keep `--quantize` disabled. For INT8 deployment, provide a calibration list with `--dataset`.

## 3. Run on RK3588

```bash
python src/rknn/pcb_detect.py \
  --model <project_root>/models/best-rk3588.rknn \
  --image <project_root>/samples/pcb.jpg \
  --output_dir <project_root>/runtime/output
```

## 4. Output Contract

The inference script writes:

- `result.jpg`: image with predicted boxes.
- `result.txt`: four-line UI interface file.

`result.txt` format:

```text
YES or NO
defect_count
defect_type confidence, ...
detection_time
```

The defect count is the actual number of detections after confidence filtering and NMS.
