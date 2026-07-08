// =============================================================================
// 模块: services/detector_runner.vala — 直接调用 RKNN/Python 检测脚本
// =============================================================================

namespace PcbInspector {

public class DetectorRunner : Object {

    private bool running = false;

    public signal void detection_finished (DetectionRecord record, string result_image_path);
    public signal void detection_failed (string message);

    public bool is_running () {
        return running;
    }

    public void start_detection (string image_path) {
        if (running) {
            detection_failed ("模型正在运行，忽略重复请求");
            return;
        }

        running = true;

        try {
            ensure_dir (Config.DETECTOR_OUTPUT_DIR);
            ensure_dir (Path.get_dirname (Config.DETECTOR_TIME_FILE));
            FileUtils.set_contents (
                Config.DETECTOR_TIME_FILE,
                new DateTime.now_local ().format ("%Y-%m-%d %H:%M:%S")
            );

            string log_path = Path.build_filename (Config.get_data_dir (), "detector.log");
            string command =
                "python3 %s --model %s --image %s --time_file %s --output_dir %s --conf %.2f > %s 2>&1";

            string[] argv = {
                "/bin/sh",
                "-c",
                command.printf (
                    shell_quote (Config.DETECTOR_SCRIPT),
                    shell_quote (Config.MODEL_PATH),
                    shell_quote (image_path),
                    shell_quote (Config.DETECTOR_TIME_FILE),
                    shell_quote (Config.DETECTOR_OUTPUT_DIR),
                    Config.CONF_THRESHOLD,
                    shell_quote (log_path)
                )
            };

            Pid pid;
            Process.spawn_async (
                null,
                argv,
                null,
                SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                null,
                out pid
            );

            ChildWatch.add (pid, (child_pid, status) => {
                Process.close_pid (child_pid);
                on_detection_process_done (status);
            });

        } catch (Error e) {
            running = false;
            detection_failed ("启动模型失败: %s".printf (e.message));
        }
    }

    private void on_detection_process_done (int status) {
        running = false;

        try {
            Process.check_exit_status (status);
        } catch (Error e) {
            detection_failed ("模型检测失败，请查看 data/detector.log: %s".printf (e.message));
            return;
        }

        try {
            DetectionRecord record = parse_result_txt ();
            record.annotated_image_path = Config.RESULT_IMAGE;
            detection_finished (record, Config.RESULT_IMAGE);
        } catch (Error e) {
            detection_failed ("解析检测结果失败: %s".printf (e.message));
        }
    }

    private DetectionRecord parse_result_txt () throws Error {
        string content;
        FileUtils.get_contents (Config.RESULT_TXT, out content);
        string[] raw_lines = content.replace ("\r", "").split ("\n");

        string[] lines = {};
        foreach (string raw in raw_lines) {
            if (raw.strip () != "" && lines.length < 4) {
                lines += raw.strip ();
            }
        }

        if (lines.length < 4) {
            throw new IOError.FAILED ("result.txt 格式错误，应为四行");
        }

        var record = new DetectionRecord ();
        record.timestamp = lines[3];
        record.annotated_image_path = Config.RESULT_IMAGE;

        if (lines[0] == "YES" && lines[2] != "None") {
            foreach (string item in lines[2].split (",")) {
                add_defect_from_text (record, item.strip ());
            }
        } else if (lines[0] != "NO") {
            throw new IOError.FAILED ("result.txt 第一行必须是 YES 或 NO");
        }

        return record;
    }

    private void add_defect_from_text (DetectionRecord record, string text) {
        string[] parts = text.split (" ");
        if (parts.length < 2) {
            return;
        }

        string confidence_text = parts[parts.length - 1];
        double confidence = 0.0;
        double.try_parse (confidence_text, out confidence);

        var type_builder = new StringBuilder ();
        for (int i = 0; i < parts.length - 1; i++) {
            if (i > 0) {
                type_builder.append ("_");
            }
            type_builder.append (parts[i]);
        }

        record.add_defect (new DefectInfo (
            DefectType.from_label (type_builder.str),
            0.5,
            0.5,
            0.1,
            0.1,
            confidence
        ));
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
