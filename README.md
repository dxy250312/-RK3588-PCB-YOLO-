# PCB Defect YOLO Intelligent Inspection System on RK3588

## Project Introduction

This project is an edge AI solution for bare PCB defect inspection based on YOLOv11 and Rockchip RK3588. It covers model training, dataset configuration, ONNX export, RKNN conversion, RK3588-side inference, GPIO triggering, alarm control, and a lightweight Qt desktop interface.

The target workflow is:

1. Preview the PCB image before capture.
2. Wait for a photoelectric sensor trigger.
3. Capture and enhance one PCB image.
4. Run RKNN inference on the RK3588 NPU.
5. Generate a labeled result image and a four-line result text file.
6. Display the result in the UI and save inspection history.
7. Use GPIO output to drive an alarm when a defect is detected.

No dataset, private image, trained weight, RKNN model, log file, board address, or credential is included in this repository.

## Features

- YOLOv11 PCB defect training scripts.
- P2 shallow detection head configuration for small PCB defects.
- PCB dataset YAML template with five common defect classes.
- ONNX export helper for RKNN conversion.
- RKNN conversion helper for RK3588.
- RK3588 inference script producing `result.jpg` and `result.txt`.
- GPIO helper for photoelectric sensor input and buzzer/alarm output.
- Qt/C++ reference UI for image preview, detection execution, and result display.
- Privacy scan script for pre-release repository checks.

## Hardware

Recommended hardware:

- Rockchip RK3588 development board.
- USB or MIPI camera supported by Linux V4L2.
- Photoelectric sensor connected to an input GPIO.
- Buzzer or alarm module connected to an output GPIO.
- Conveyor controller or relay module if used by the production line.
- HDMI display or Linux desktop environment for the Qt UI.

The default example GPIO mapping is:

| Function | Example GPIO | Direction |
| --- | --- | --- |
| PCB arrival sensor | GPIO3_B1 | Input |
| Defect alarm | GPIO3_A7 | Output |

Adjust the GPIO numbers in `configs/deployment/rknn_runtime.yaml` for your board.

## Software

Recommended software environment:

- Python 3.10+
- PyTorch and Ultralytics YOLO
- OpenCV
- RKNN Toolkit 2 on the conversion host
- RKNNLite runtime on RK3588
- Qt 6 for the reference desktop UI
- CMake 3.16+

## Installation

Clone the repository:

```bash
git clone <repository_url>
cd pcb-defect-yolo-rk3588
```

Create a Python environment:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Install RKNN Toolkit 2 on the model conversion host according to the official Rockchip package for your platform. Install RKNNLite runtime on RK3588 according to the board vendor documentation.

## Training

Prepare your dataset in YOLO format outside this repository:

```text
<dataset_root>/
  images/
    train/
    val/
  labels/
    train/
    val/
```

Edit `configs/pcb_dataset.yaml` and replace `<dataset_root>` with your local dataset path.

Train the P2-head YOLOv11 model:

```bash
python src/training/train_p2.py \
  --model configs/models/yolo11n-p2-pcb.yaml \
  --data configs/pcb_dataset.yaml \
  --weights yolo11n.pt \
  --epochs 100 \
  --imgsz 640 \
  --batch 16
```

Run a single-image prediction test:

```bash
python src/training/predict_image.py \
  --weights <project_root>/weights/best.pt \
  --image <project_root>/samples/pcb.jpg \
  --output <project_root>/results/result_detect.jpg
```

The repository intentionally does not include datasets, labels, or trained weights.

## RKNN Deployment

Export PyTorch weights to ONNX:

```bash
python src/export/export_onnx.py \
  --weights <project_root>/weights/best.pt \
  --output <project_root>/export \
  --imgsz 640 \
  --opset 12
```

Convert ONNX to RKNN for RK3588:

```bash
python src/export/onnx_to_rknn.py \
  --onnx <project_root>/export/best.onnx \
  --output <project_root>/export/best-rk3588.rknn \
  --target rk3588
```

Run inference on RK3588:

```bash
python src/rknn/pcb_detect.py \
  --model <project_root>/models/best-rk3588.rknn \
  --image <project_root>/samples/pcb.jpg \
  --time_file <project_root>/runtime/capture_time.txt \
  --output_dir <project_root>/runtime/output \
  --conf 0.25
```

The inference script writes:

```text
result.jpg
result.txt
```

`result.txt` uses exactly four lines. The detection count and confidence values come directly from model post-processing and are not manually forced:

```text
YES or NO
defect_count
defect_type confidence, ...
detection_time
```

## Project Structure

```text
.
├── configs/
│   ├── pcb_dataset.yaml
│   ├── deployment/
│   │   └── rknn_runtime.yaml
│   └── models/
│       └── yolo11n-p2-pcb.yaml
├── docs/
│   └── RKNN_DEPLOYMENT.md
├── scripts/
│   └── privacy_scan.py
├── src/
│   ├── export/
│   │   ├── export_onnx.py
│   │   └── onnx_to_rknn.py
│   ├── gpio/
│   │   └── gpio_control.py
│   ├── rknn/
│   │   └── pcb_detect.py
│   └── training/
│       ├── predict_image.py
│       └── train_p2.py
└── ui/
    └── qt/
        ├── CMakeLists.txt
        └── src/
```

## License

This repository is released under the MIT License. See `LICENSE` for details.

Ultralytics YOLO and RKNN Toolkit are third-party dependencies and are governed by their own licenses. This repository does not vendor the Ultralytics source tree.
