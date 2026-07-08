// =============================================================================
// 模块: config.vala — 系统配置常量
// =============================================================================
// 内容说明:
//   1. 缺陷类型枚举 (DefectType) 及其与中文名称、描述的映射
//   2. 应用全局常量：窗口尺寸、数据存储路径、检测图像目录等
//   3. 缺陷类型的颜色标识（用于 UI 高亮显示）
//
// 依赖: 无外部接口依赖，纯常量定义
// =============================================================================

namespace PcbInspector {

/**
 * 缺陷类型枚举
 * 对应 YOLO 模型能检测的 5 种 PCB 缺陷
 */
public enum DefectType {
    MOUSE_BITE,       // 鼠咬 — 板边不规则的凹口，形似老鼠咬痕
    OPEN_CIRCUIT,     // 开路 — 导线断开，电路不导通
    SHORT,            // 短路 — 两导体意外相连
    SPUR,             // 毛刺 — 导线边缘伸出的尖刺状铜箔
    SPURIOUS_COPPER;  // 残铜 — 不该有铜的区域残留了铜箔

    /**
     * 获取缺陷类型的中文名称
     * @return 中文名称字符串
     */
    public string to_chinese () {
        switch (this) {
            case MOUSE_BITE:      return "鼠咬";
            case OPEN_CIRCUIT:    return "开路";
            case SHORT:           return "短路";
            case SPUR:            return "毛刺";
            case SPURIOUS_COPPER: return "残铜";
            default:              return "未知";
        }
    }

    /**
     * 获取缺陷类型的详细描述
     * @return 描述字符串
     */
    public string description () {
        switch (this) {
            case MOUSE_BITE:
                return "板边出现不规则的凹口缺陷，形似鼠咬痕迹，可能影响电路完整性。";
            case OPEN_CIRCUIT:
                return "导线或焊盘处出现断开，导致电路无法导通。";
            case SHORT:
                return "两条本应绝缘的导线或焊盘之间发生意外连接。";
            case SPUR:
                return "导线边缘伸出多余的尖刺状铜箔，可能引起信号干扰或短路。";
            case SPURIOUS_COPPER:
                return "在不应有铜箔的区域残留了多余的铜箔，可能导致意外连接。";
            default:
                return "未定义的缺陷类型。";
        }
    }

    /**
     * 获取缺陷类型对应的 CSS 颜色类名（用于 UI 着色）
     * @return CSS 颜色值
     */
    public string color () {
        switch (this) {
            case MOUSE_BITE:      return "#e74c3c";  // 红色
            case OPEN_CIRCUIT:    return "#e67e22";  // 橙色
            case SHORT:           return "#c0392b";  // 深红
            case SPUR:            return "#f39c12";  // 黄色
            case SPURIOUS_COPPER: return "#8e44ad";  // 紫色
            default:              return "#95a5a6";  // 灰色
        }
    }

    /**
     * 从 YOLO 模型输出的英文标签字符串转换为枚举值
     * @param label YOLO 标签名（如 "Mouse_bite"）
     * @return 对应的缺陷类型枚举
     */
    public static DefectType from_label (string label) {
        switch (label.down ()) {
            case "mouse_bite":      return DefectType.MOUSE_BITE;
            case "open_circuit":    return DefectType.OPEN_CIRCUIT;
            case "short":           return DefectType.SHORT;
            case "spur":            return DefectType.SPUR;
            case "spurious_copper": return DefectType.SPURIOUS_COPPER;
            default:
                warning ("未知的缺陷标签: %s", label);
                return DefectType.MOUSE_BITE;
        }
    }
}

/**
 * 应用全局配置常量
 */
namespace Config {
    // ---- 窗口设置 ----
    /** 主窗口默认宽度 (px) */
    public const int WINDOW_WIDTH  = 1280;
    /** 主窗口默认高度 (px) */
    public const int WINDOW_HEIGHT = 800;
    /** 主窗口最小宽度 (px) */
    public const int WINDOW_MIN_WIDTH  = 1024;
    /** 主窗口最小高度 (px) */
    public const int WINDOW_MIN_HEIGHT = 600;
    /** 应用程序标题 */
    public const string APP_TITLE = "PCB缺陷检测系统";

    // ---- 数据存储 ----
    /** 历史记录 JSON 文件名 */
    public const string HISTORY_FILENAME = "detection_history.json";
    /** 检测图像保存目录名 */
    public const string IMAGE_SAVE_DIR   = "detection_images";

    // ---- 检测设置 ----
    /** 检测图像在界面中的最大显示宽度 */
    public const int IMAGE_DISPLAY_MAX_WIDTH  = 800;
    /** 检测图像在界面中的最大显示高度 */
    public const int IMAGE_DISPLAY_MAX_HEIGHT = 600;
    /** 缺陷列表每页最大条数 */
    public const int MAX_DEFECTS_PER_PAGE = 100;

    // ---- 摄像头预览 ----
    /** 摄像头设备路径 */
    public const string CAMERA_DEVICE = "/dev/video11";
    /** 摄像头驱动命令文件，UI 从这里读取预览管线 */
    public const string PHOTO_COMMAND_FILE = "../../configs/deployment/photo.txt";
    /** UI 设置保存文件 */
    public const string SETTINGS_FILE = "../../runtime/settings.conf";
    /** RKNN 检测脚本 */
    public const string DETECTOR_SCRIPT = "../../src/rknn/pcb_detect.py";
    /** RKNN 模型路径 */
    public const string MODEL_PATH = "../../models/best-rk3588.rknn";
    /** 检测输出目录，pcb_detect.py 会写 result.jpg/result.txt */
    public const string DETECTOR_OUTPUT_DIR = "../../runtime/output";
    public const string RESULT_IMAGE = "../../runtime/output/result.jpg";
    public const string RESULT_TXT = "../../runtime/output/result.txt";
    /** pcb_detect.py 需要纯文本时间文件，不能传 JSON */
    public const string DETECTOR_TIME_FILE = "../../runtime/capture_time.txt";
    public const double CONF_THRESHOLD = 0.25;
    /** port/end.c 参考拍照输出目录 */
    public const string CAPTURE_DIR = "../../runtime/photos";
    /** port/end.c 参考 time.json 输出 */
    public const string CAPTURE_TIME_JSON = "../../runtime/time.json";
    /** GPIO chip path for RK3588 GPIO3. */
    public const string SENSOR_GPIO_CHIP = "/dev/gpiochip3";
    public const int SENSOR_GPIO_LINE = 9;
    /** 官方 sysfs 编号: GPIO3_B1 = 3 * 32 + 1 * 8 + 1 = 105 */
    public const int SENSOR_SYSFS_GPIO = 105;
    public const int SENSOR_POLL_INTERVAL_MS = 100;
    public const string CONVEYOR_GPIO_CHIP = "/dev/gpiochip3";
    public const int CONVEYOR_GPIO_A5_LINE = 5;
    public const int CONVEYOR_GPIO_A7_LINE = 7;
    /** 官方 sysfs 编号: GPIO3_A7 = 3 * 32 + 0 * 8 + 7 = 103 */
    public const int ALARM_SYSFS_GPIO = 103;
    /** 缺陷报警最短保持时间，避免蜂鸣器被立即放行动作关掉 */
    public const int ALARM_MIN_HOLD_MS = 3000;
    /** 默认触发后延时 */
    public const int DEFAULT_DELAY_MS = 500;
    /** UI 预览帧宽度，实际显示会继续随窗口自适应 */
    public const int PREVIEW_WIDTH = 640;
    /** UI 预览帧高度，实际显示会继续随窗口自适应 */
    public const int PREVIEW_HEIGHT = 480;
    /** UI 预览帧率 */
    public const int PREVIEW_FPS = 30;
    /** 拍照分辨率，沿用 port/end.c 当前可用参数 */
    public const int CAPTURE_WIDTH = 640;
    public const int CAPTURE_HEIGHT = 480;

    // ---- 定时器 ----
    /** 状态栏消息显示时长（秒） */
    public const double STATUS_MESSAGE_DURATION = 5.0;

    /**
     * 获取应用数据目录路径
     * 优先使用 XDG 数据目录，回退到当前目录下的 data/
     */
    public string get_data_dir () {
        string? xdg_data = Environment.get_variable ("XDG_DATA_HOME");
        if (xdg_data != null && xdg_data != "") {
            string dir = Path.build_filename (xdg_data, "pcb-inspector");
            ensure_dir (dir);
            return dir;
        }
        string dir = Path.build_filename (Environment.get_current_dir (), "data");
        ensure_dir (dir);
        return dir;
    }

    /** 确保目录存在 */
    private void ensure_dir (string path) {
        var file = File.new_for_path (path);
        if (!file.query_exists ()) {
            try {
                file.make_directory_with_parents ();
            } catch (Error e) {
                warning ("无法创建目录 %s: %s", path, e.message);
            }
        }
    }
}

} // namespace PcbInspector
