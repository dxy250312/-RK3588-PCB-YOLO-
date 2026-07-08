# 基于 RK3588 的 PCB 缺陷 YOLO 智能检测系统

本项目是一个面向 PCB 裸板缺陷检测的边缘 AI 系统，基于 YOLOv11、RK3588 NPU、RKNN 部署、GPIO 控制和桌面图形界面实现。工程包含模型训练配置、ONNX 导出、RKNN 转换、RK3588 端推理、光电传感器触发、蜂鸣器报警、摄像头预览/拍照以及 UI 显示等主要代码。

本仓库只开源主要工程代码，不包含数据集、标注文件、企业图片、训练输出日志、模型权重、ONNX 文件、RKNN 文件和运行结果图片。实际部署时，请将训练好的模型文件放入 `models/` 目录。

## 项目简介

系统的目标流程如下：

1. UI 启动后显示摄像头实时预览画面。
2. 光电传感器检测 PCB 到位。
3. 系统延时等待 PCB 稳定后触发拍照。
4. 对拍照图像进行基础增强处理。
5. 调用 RK3588 上的 RKNN 模型完成缺陷检测。
6. 输出带框检测图片 `result.jpg` 和文本结果 `result.txt`。
7. UI 显示检测图片、缺陷数量、缺陷类别和检测时间。
8. 如果检测到缺陷，可通过 GPIO 输出驱动蜂鸣器或报警模块。

当前缺陷类别为 5 类：

- `Mouse_bite`
- `Open_circuit`
- `Short`
- `Spur`
- `Spurious_copper`

检测数量和置信度均来自模型推理与标准后处理结果。

## 功能特点

- 提供 YOLOv11 PCB 缺陷检测训练入口。
- 提供 YOLOv11-P2 小目标检测模型结构配置。
- 提供 PCB 五类缺陷数据集 YAML 模板。
- 支持将训练权重导出为 ONNX。
- 支持将 ONNX 转换为 RK3588 可运行的 RKNN 模型。
- 提供 RKNNLite 推理脚本，输出 UI 需要的 `result.jpg` 和 `result.txt`。
- 提供 GPIO 输入/输出控制示例，用于光电传感器和报警模块。
- 提供 GTK4 + Vala 桌面 UI 工程源码，作为开发板实际 UI 主工程。
- 提供 Qt/C++ 参考 UI 工程，便于后续按 Qt 方案扩展。
- 仓库不包含图片数据、权重文件、日志文件和本地隐私路径。

## 硬件环境

推荐硬件组成：

- RK3588 开发板。
- 支持 Linux V4L2 的 USB 或 MIPI 摄像头。
- 光电传感器，用于检测 PCB 是否到位。
- 蜂鸣器、报警灯或继电器模块。
- 显示器和 Linux 桌面环境，用于运行图形界面。
- 可选传送带控制模块，用于组成完整检测流水线。

GPIO 示例配置位于：

```text
configs/deployment/rknn_runtime.yaml
```

实际使用时需要根据开发板接线修改 GPIO 芯片、GPIO 行号或 sysfs 编号。

## 软件环境

推荐软件环境：

- Python 3.10 或更新版本。
- PyTorch。
- Ultralytics YOLO。
- OpenCV。
- RKNN Toolkit 2，用于模型转换。
- RKNNLite runtime，用于 RK3588 端模型推理。
- GTK4、Vala、Meson、Ninja，用于编译 GTK UI。
- Qt 6、CMake，用于编译 Qt 参考 UI。

## 安装方法

克隆仓库：

```bash
git clone <repository_url>
cd pcb-defect-yolo-rk3588
```

创建 Python 环境并安装依赖：

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

RKNN Toolkit 2 和 RKNNLite runtime 请根据 Rockchip 官方 SDK 或开发板厂商文档安装。

## 模型训练

数据集需要使用 YOLO 格式，并放在仓库外部，例如：

```text
<dataset_root>/
  images/
    train/
    val/
  labels/
    train/
    val/
```

修改数据集配置：

```text
configs/pcb_dataset.yaml
```

训练 YOLOv11-P2 PCB 缺陷检测模型：

```bash
python src/training/train_p2.py \
  --model configs/models/yolo11n-p2-pcb.yaml \
  --data configs/pcb_dataset.yaml \
  --weights yolo11n.pt \
  --epochs 100 \
  --imgsz 640 \
  --batch 16
```

单张图片预测测试：

```bash
python src/training/predict_image.py \
  --weights <project_root>/weights/best.pt \
  --image <project_root>/samples/pcb.jpg \
  --output <project_root>/results/result_detect.jpg
```

说明：`weights/`、`samples/`、`results/` 仅为运行时目录示例，默认不提交到仓库。

## RKNN 部署

导出 ONNX：

```bash
python src/export/export_onnx.py \
  --weights <project_root>/weights/best.pt \
  --output <project_root>/export \
  --imgsz 640 \
  --opset 12
```

转换为 RKNN：

```bash
python src/export/onnx_to_rknn.py \
  --onnx <project_root>/export/best.onnx \
  --output <project_root>/models/best-rk3588.rknn \
  --target rk3588
```

在 RK3588 上运行推理：

```bash
python src/rknn/pcb_detect.py \
  --model <project_root>/models/best-rk3588.rknn \
  --image <project_root>/samples/pcb.jpg \
  --time_file <project_root>/runtime/capture_time.txt \
  --output_dir <project_root>/runtime/output \
  --conf 0.25
```

推理输出：

```text
runtime/output/result.jpg
runtime/output/result.txt
```

`result.txt` 固定为四行：

```text
YES 或 NO
缺陷数量
缺陷类型 置信度, ...
检测时间
```

## UI 工程

### GTK4 + Vala UI

GTK UI 位于：

```text
ui/gtk
```

安装依赖：

```bash
sudo apt install valac meson ninja-build libgtk-4-dev libjson-glib-dev libgdk-pixbuf-2.0-dev
```

编译：

```bash
cd ui/gtk
meson setup build
ninja -C build
```

运行：

```bash
./build/pcb-inspector-gtk
```

摄像头预览命令模板位于：

```text
configs/deployment/photo.txt
```

运行时模型、输出结果和临时文件默认放在：

```text
models/
runtime/
```

### Qt/C++ 参考 UI

Qt 参考工程位于：

```text
ui/qt
```

编译：

```bash
cd ui/qt
cmake -S . -B build
cmake --build build
```

## 项目结构

```text
.
|-- configs/
|   |-- pcb_dataset.yaml
|   |-- deployment/
|   |   |-- photo.txt
|   |   `-- rknn_runtime.yaml
|   `-- models/
|       `-- yolo11n-p2-pcb.yaml
|-- docs/
|   `-- RKNN_DEPLOYMENT.md
|-- src/
|   |-- export/
|   |   |-- export_onnx.py
|   |   `-- onnx_to_rknn.py
|   |-- gpio/
|   |   `-- gpio_control.py
|   |-- rknn/
|   |   `-- pcb_detect.py
|   `-- training/
|       |-- predict_image.py
|       `-- train_p2.py
|-- ui/
|   |-- gtk/
|   `-- qt/
|-- .gitignore
|-- LICENSE
|-- README.md
`-- requirements.txt
```

## License

本项目采用 MIT License，详见 `LICENSE`。

Ultralytics YOLO、RKNN Toolkit 及相关运行库属于第三方依赖，遵循其各自许可证。本仓库不内置 Ultralytics 源码，不发布训练数据和模型二进制文件。
