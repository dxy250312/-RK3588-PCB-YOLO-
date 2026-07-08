# 数据集说明 / Dataset

本仓库不包含任何训练数据、标注文件、企业图片或运行采集图片。数据集需要用户自行准备，并按 YOLO 检测任务格式组织。

This repository does not include datasets, labels, enterprise images, or captured runtime images. Users should prepare their own datasets in YOLO detection format.

## 可选数据来源 / Optional Data Sources

### DeepPCB

DeepPCB 是常见的 PCB 缺陷检测公开数据集，可用于 PCB 缺陷检测算法验证。使用前请确认其授权条款、引用要求和数据使用范围。

DeepPCB is a commonly used public PCB defect dataset. Check its license, citation requirements, and usage scope before use.

### PKU-PCB

PKU-PCB 也是 PCB 缺陷检测方向常见的数据来源之一，可用于模型训练或算法对比。使用前请确认数据来源和版权要求。

PKU-PCB is another common data source for PCB defect detection research. Verify its source and license before training or redistribution.

### 自制 PCB 数据集 / Custom PCB Dataset

实际工程中通常需要采集自制 PCB 图片并进行人工标注。由于版权、企业合作和数据安全原因，本项目不公开自制数据集。

In real projects, custom PCB images are usually collected and annotated manually. This project does not publish custom datasets because of copyright, business, and data security constraints.

## 推荐目录 / Recommended Layout

```text
<dataset_root>/
  images/
    train/
    val/
    test/
  labels/
    train/
    val/
    test/
```

## 类别 / Classes

```text
0 Mouse_bite
1 Open_circuit
2 Short
3 Spur
4 Spurious_copper
```

## 示例配置 / Example YAML

See `example_dataset.yaml` in the repository root. All paths are placeholders and must be replaced locally.
