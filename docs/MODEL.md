# 模型说明 / Model

本仓库不上传模型二进制文件，包括：

- `.pt`
- `.onnx`
- `.rknn`
- `.engine`
- `.weights`

这些文件通常较大，并且可能包含训练数据分布、企业样本特征或实验资产信息。用户需要自行训练、导出和转换模型。

This repository does not upload model binaries. Users should train, export, and convert models locally.

## 模型结构 / Model Architecture

模型结构配置位于：

```text
configs/models/yolo11n-p2-pcb.yaml
```

该配置在 YOLOv11n 基础上加入 P2 浅层检测头，用于提升小尺寸 PCB 缺陷的检测能力。

## 训练命令 / Training

```bash
python src/training/train_p2.py \
  --model configs/models/yolo11n-p2-pcb.yaml \
  --data configs/pcb_dataset.yaml \
  --weights yolo11n.pt \
  --epochs 100 \
  --imgsz 640 \
  --batch 16
```

训练完成后，通常会得到本地权重文件：

```text
weights/best.pt
```

请不要将该文件提交到 Git 仓库。

## ONNX 导出 / ONNX Export

```bash
python src/export/export_onnx.py \
  --weights <project_root>/weights/best.pt \
  --output <project_root>/export \
  --imgsz 640 \
  --opset 12
```

如果已经有本地 ONNX 文件，可以直接将其放在：

```text
export/best.onnx
```

本项目使用的 ONNX 文件应作为本地转换输入，不提交到仓库。

## RKNN 转换 / RKNN Conversion

```bash
python src/export/onnx_to_rknn.py \
  --onnx <project_root>/export/best.onnx \
  --output <project_root>/models/best-rk3588.rknn \
  --target rk3588
```

转换得到的 RKNN 文件请放在本地：

```text
models/best-rk3588.rknn
```

不要将 RKNN 文件提交到 Git 仓库。
