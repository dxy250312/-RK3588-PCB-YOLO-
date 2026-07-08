// =============================================================================
// 模块: services/hardware_service.vala — UI 硬件接口层
// =============================================================================
// 说明:
//   这里集中封装 GPIO、传送带、摄像头拍照和资源释放接口。
//   当前版本优先保证 UI 主控流程可验证；GPIO/传送带先使用 mock 状态，
//   Camera capture uses the same GStreamer style pipeline as the preview command.
// =============================================================================

namespace PcbInspector {

public enum SystemState {
    IDLE,
    PREVIEW,
    SENSOR_TRIGGERED,
    DELAY_WAIT,
    CAPTURING,
    INFERENCING,
    RESULT_SHOW,
    PASS,
    NG_STOP,
    MANUAL_RELEASE,
    ERROR
}

public class HardwareService : Object {

    private bool sensor_monitoring = false;
    private uint delay_timer_id = 0;
    private uint sensor_wait_timer_id = 0;
    private uint alarm_hold_timer_id = 0;
    private bool alarm_hold_active = false;
    private bool alarm_release_requested = false;

    public signal void sensor_high ();
    public signal void sensor_wait_failed (string message);
    public signal void status_changed (SystemState state, string message);

    public void start_sensor_monitor () {
        sensor_monitoring = true;
        status_changed (SystemState.PREVIEW, "传感器监听已启动，等待 PCB 到位");
    }

    public void stop_sensor_monitor () {
        sensor_monitoring = false;
        stop_wait_for_sensor_high ();
        status_changed (SystemState.IDLE, "传感器监听已停止");
    }

    public void start_wait_for_sensor_high () {
        if (sensor_wait_timer_id != 0) {
            status_changed (SystemState.PREVIEW, "正在等待 PCB 到位");
            return;
        }

        sensor_monitoring = true;
        status_changed (SystemState.PREVIEW, "等待 PCB 到位");

        string error_message = "";
        int level = read_sensor_level (out error_message);
        if (level == 1) {
            on_sensor_high ();
            return;
        }
        if (level < 0) {
            status_changed (SystemState.PREVIEW, "%s；继续等待 GPIO105 可读".printf (error_message));
        }

        sensor_wait_timer_id = Timeout.add ((uint) Config.SENSOR_POLL_INTERVAL_MS, () => {
            string poll_error = "";
            int poll_level = read_sensor_level (out poll_error);
            if (poll_level == 1) {
                sensor_wait_timer_id = 0;
                on_sensor_high ();
                return false;
            }
            if (poll_level < 0) {
                status_changed (SystemState.PREVIEW, "%s；继续等待 GPIO105 可读".printf (poll_error));
                return true;
            }
            return true;
        });
    }

    public void stop_wait_for_sensor_high () {
        if (sensor_wait_timer_id != 0) {
            Source.remove (sensor_wait_timer_id);
            sensor_wait_timer_id = 0;
        }
    }

    public void on_sensor_high () {
        stop_wait_for_sensor_high ();
        if (!sensor_monitoring) {
            status_changed (SystemState.SENSOR_TRIGGERED, "手动触发检测");
        } else {
            status_changed (SystemState.SENSOR_TRIGGERED, "PCB 已到位");
        }
        sensor_high ();
    }

    public bool start_conveyor () {
        if (alarm_hold_active) {
            alarm_release_requested = true;
            status_changed (SystemState.PASS, "传送带继续运行，报警保持中");
            return true;
        }

        set_alarm_output (false);
        status_changed (SystemState.PASS, "传送带继续运行，报警已关闭");
        return true;
    }

    public bool stop_conveyor () {
        start_alarm_hold ();
        status_changed (SystemState.NG_STOP, "检测到缺陷，报警已开启");
        return true;
    }

    public bool set_alarm_output (bool enabled) {
        string error_message = "";
        if (!write_sysfs_gpio_value (Config.ALARM_SYSFS_GPIO, enabled, out error_message)) {
            status_changed (SystemState.ERROR, "GPIO3_A7 报警输出失败: %s".printf (error_message));
            return false;
        }
        message ("GPIO3_A7 报警输出: %s", enabled ? "高电平" : "低电平");
        return true;
    }

    public string capture_image () throws Error {
        ensure_dir (Config.CAPTURE_DIR);

        string timestamp = new DateTime.now_local ().format ("%y%m%d%H%M%S");
        string image_path = Path.build_filename (Config.CAPTURE_DIR, "%s.jpg".printf (timestamp));

        string command =
            "timeout 8s gst-launch-1.0 -q v4l2src device=%s num-buffers=1 "
            + "! video/x-raw,format=NV12,width=%d,height=%d,framerate=30/1 "
            + "! jpegenc ! filesink location=%s";

        string[] argv = {
            "/bin/sh",
            "-c",
            command.printf (
                shell_quote (Config.CAMERA_DEVICE),
                Config.CAPTURE_WIDTH,
                Config.CAPTURE_HEIGHT,
                shell_quote (image_path)
            )
        };

        int exit_status = 0;
        string stdout_text;
        string stderr_text;
        Process.spawn_sync (
            null,
            argv,
            null,
            SpawnFlags.SEARCH_PATH,
            null,
            out stdout_text,
            out stderr_text,
            out exit_status
        );

        if (exit_status == 124) {
            throw new IOError.FAILED ("拍照超时，摄像头可能被占用或驱动未返回图像");
        }

        if (exit_status != 0 || !FileUtils.test (image_path, FileTest.EXISTS)) {
            throw new IOError.FAILED ("拍照失败: %s".printf (stderr_text.strip ()));
        }

        enhance_capture_image (image_path);
        write_capture_time_json (timestamp, image_path);
        return image_path;
    }

    public void release_camera () {
        status_changed (SystemState.PREVIEW, "摄像头拍照资源已释放");
    }

    public void release_detection_resources () {
        status_changed (SystemState.RESULT_SHOW, "本轮检测临时资源已释放");
    }

    public void release_gpio_resources () {
        clear_alarm_hold_timer ();
        set_alarm_output (false);
        status_changed (SystemState.IDLE, "GPIO 资源释放接口已调用");
    }

    public void release_cycle_resources () {
        if (delay_timer_id != 0) {
            Source.remove (delay_timer_id);
            delay_timer_id = 0;
        }
        stop_wait_for_sensor_high ();
        release_camera ();
        release_detection_resources ();
    }

    public void set_delay_timer_id (uint timer_id) {
        delay_timer_id = timer_id;
    }

    public void clear_delay_timer_id () {
        delay_timer_id = 0;
    }

    public void save_delay_ms (int delay_ms) throws Error {
        ensure_dir (Path.get_dirname (Config.SETTINGS_FILE));
        FileUtils.set_contents (Config.SETTINGS_FILE, "delay_ms=%d\n".printf (delay_ms));
    }

    private void write_capture_time_json (string timestamp, string image_path) {
        try {
            FileUtils.set_contents (
                Config.CAPTURE_TIME_JSON,
                "{\n  \"timestamp\": \"%s\",\n  \"filepath\": \"%s\"\n}\n".printf (
                    timestamp,
                    image_path
                )
            );
        } catch (Error e) {
            warning ("写入拍照 time.json 失败: %s", e.message);
        }
    }

    private void start_alarm_hold () {
        clear_alarm_hold_timer ();
        alarm_hold_active = true;
        alarm_release_requested = false;

        if (!set_alarm_output (true)) {
            alarm_hold_active = false;
            return;
        }

        alarm_hold_timer_id = Timeout.add ((uint) Config.ALARM_MIN_HOLD_MS, () => {
            alarm_hold_timer_id = 0;
            alarm_hold_active = false;

            if (alarm_release_requested) {
                alarm_release_requested = false;
                set_alarm_output (false);
                status_changed (SystemState.PASS, "报警保持结束，已关闭");
            }

            return false;
        });
    }

    private void clear_alarm_hold_timer () {
        if (alarm_hold_timer_id != 0) {
            Source.remove (alarm_hold_timer_id);
            alarm_hold_timer_id = 0;
        }
        alarm_hold_active = false;
        alarm_release_requested = false;
    }

    private int read_sensor_level (out string error_message) {
        error_message = "";
        string sysfs_value_path = "/sys/class/gpio/gpio%d/value".printf (Config.SENSOR_SYSFS_GPIO);
        if (FileUtils.test (sysfs_value_path, FileTest.EXISTS)) {
            try {
                string contents;
                FileUtils.get_contents (sysfs_value_path, out contents);
                string value = contents.strip ();
                if (value == "0" || value == "1") {
                    return int.parse (value);
                }
                error_message = "GPIO3_B1 读取值异常: %s".printf (value);
                return -1;
            } catch (Error e) {
                error_message = "读取 GPIO3_B1 失败: %s".printf (e.message);
                return -1;
            }
        }

        string[] argv = {
            "gpioget",
            Config.SENSOR_GPIO_CHIP,
            Config.SENSOR_GPIO_LINE.to_string ()
        };

        int exit_status = 0;
        string stdout_text;
        string stderr_text;
        try {
            Process.spawn_sync (
                null,
                argv,
                null,
                SpawnFlags.SEARCH_PATH,
                null,
                out stdout_text,
                out stderr_text,
                out exit_status
            );
        } catch (Error e) {
            error_message = "无法执行 gpioget 读取 GPIO3_B1: %s".printf (e.message);
            return -1;
        }

        if (exit_status != 0) {
            error_message = "GPIO3_B1 读取失败: %s。请先按官方方式导出 GPIO105，或用有 GPIO 权限的用户运行 UI。".printf (stderr_text.strip ());
            return -1;
        }

        string value = stdout_text.strip ();
        if (value == "0" || value == "1") {
            return int.parse (value);
        }

        error_message = "GPIO3_B1 读取值异常: %s".printf (value);
        return -1;
    }

    private bool write_sysfs_gpio_value (int gpio_number, bool high, out string error_message) {
        error_message = "";
        string value_path = "/sys/class/gpio/gpio%d/value".printf (gpio_number);
        if (!FileUtils.test (value_path, FileTest.EXISTS)) {
            error_message = "/sys/class/gpio/gpio%d/value 不存在".printf (gpio_number);
            return false;
        }

        string[] argv = {
            "/bin/sh",
            "-c",
            "printf %s > %s".printf (high ? "1" : "0", shell_quote (value_path))
        };

        int exit_status = 0;
        string stdout_text;
        string stderr_text;
        try {
            Process.spawn_sync (
                null,
                argv,
                null,
                SpawnFlags.SEARCH_PATH,
                null,
                out stdout_text,
                out stderr_text,
                out exit_status
            );
        } catch (Error e) {
            error_message = e.message;
            return false;
        }

        if (exit_status != 0) {
            error_message = stderr_text.strip ();
            return false;
        }

        return true;
    }

    private void enhance_capture_image (string image_path) throws Error {
        var source = new Gdk.Pixbuf.from_file (image_path);
        var adjusted = source.copy ();
        var enhanced = source.copy ();
        if (adjusted == null || enhanced == null) {
            throw new IOError.FAILED ("照片增强失败: 无法复制图像缓冲区");
        }

        int width = source.width;
        int height = source.height;
        int rowstride = source.rowstride;
        int n_channels = source.n_channels;

        if (width < 3 || height < 3 || n_channels < 3) {
            return;
        }

        unowned uint8[] src = source.get_pixels ();
        unowned uint8[] adjusted_pixels = adjusted.get_pixels ();
        unowned uint8[] enhanced_pixels = enhanced.get_pixels ();

        int[] histogram = new int[256 * 3];
        int total_pixels = width * height;

        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                int offset = y * rowstride + x * n_channels;
                histogram[(int) src[offset]]++;
                histogram[256 + (int) src[offset + 1]]++;
                histogram[512 + (int) src[offset + 2]]++;
            }
        }

        int[] low = new int[3];
        int[] high = new int[3];
        int low_target = total_pixels / 200;
        int high_target = (total_pixels * 995) / 1000;

        for (int c = 0; c < 3; c++) {
            low[c] = find_histogram_floor (histogram, c, low_target);
            high[c] = find_histogram_floor (histogram, c, high_target);
            if (high[c] <= low[c] + 8) {
                low[c] = 0;
                high[c] = 255;
            }
        }

        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                int offset = y * rowstride + x * n_channels;

                int r = auto_level_channel ((int) src[offset], low[0], high[0]);
                int g = auto_level_channel ((int) src[offset + 1], low[1], high[1]);
                int b = auto_level_channel ((int) src[offset + 2], low[2], high[2]);

                double luminance = 0.299 * r + 0.587 * g + 0.114 * b;
                r = clamp_double_to_byte (luminance + (r - luminance) * 1.12 + 6.0);
                g = clamp_double_to_byte (luminance + (g - luminance) * 1.12 + 6.0);
                b = clamp_double_to_byte (luminance + (b - luminance) * 1.12 + 6.0);

                adjusted_pixels[offset] = (uint8) r;
                adjusted_pixels[offset + 1] = (uint8) g;
                adjusted_pixels[offset + 2] = (uint8) b;
                enhanced_pixels[offset] = (uint8) r;
                enhanced_pixels[offset + 1] = (uint8) g;
                enhanced_pixels[offset + 2] = (uint8) b;
                if (n_channels == 4) {
                    adjusted_pixels[offset + 3] = src[offset + 3];
                    enhanced_pixels[offset + 3] = src[offset + 3];
                }
            }
        }

        for (int y = 1; y < height - 1; y++) {
            for (int x = 1; x < width - 1; x++) {
                int center = y * rowstride + x * n_channels;
                int up = (y - 1) * rowstride + x * n_channels;
                int down = (y + 1) * rowstride + x * n_channels;
                int left = y * rowstride + (x - 1) * n_channels;
                int right = y * rowstride + (x + 1) * n_channels;

                for (int c = 0; c < 3; c++) {
                    double edge = ((double) adjusted_pixels[center + c] * 4.0)
                        - (double) adjusted_pixels[up + c]
                        - (double) adjusted_pixels[down + c]
                        - (double) adjusted_pixels[left + c]
                        - (double) adjusted_pixels[right + c];
                    enhanced_pixels[center + c] = (uint8) clamp_double_to_byte (
                        (double) adjusted_pixels[center + c] + edge * 0.45
                    );
                }
            }
        }

        string[] option_keys = { "quality" };
        string[] option_values = { "95" };
        enhanced.savev (image_path, "jpeg", option_keys, option_values);
    }

    private int find_histogram_floor (int[] histogram, int channel, int target_count) {
        int running = 0;
        int base_index = channel * 256;
        for (int i = 0; i < 256; i++) {
            running += histogram[base_index + i];
            if (running >= target_count) {
                return i;
            }
        }
        return 255;
    }

    private int auto_level_channel (int value, int low, int high) {
        double normalized = ((double) (value - low)) / ((double) (high - low));
        return clamp_double_to_byte (normalized * 255.0);
    }

    private int clamp_double_to_byte (double value) {
        if (value < 0.0) {
            return 0;
        }
        if (value > 255.0) {
            return 255;
        }
        return (int) (value + 0.5);
    }

    private void ensure_dir (string path) throws Error {
        var dir = File.new_for_path (path);
        if (!dir.query_exists ()) {
            dir.make_directory_with_parents ();
        }
    }

    private string shell_quote (string text) {
        return "'%s'".printf (text.replace ("'", "'\\''"));
    }
}

} // namespace PcbInspector
