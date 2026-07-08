// =============================================================================
// 模块: services/storage_service.vala — 历史记录存储服务（纯软件）
// =============================================================================
// 内容说明:
//   负责检测记录的持久化存储和读取，不需要任何硬件接口。
//   功能包括：
//   - 将单次检测记录追加写入 JSON 文件
//   - 从 JSON 文件读取全部历史记录
//   - 删除指定记录
//   - 获取历史统计信息（总次数、各类缺陷出现总次数、合格率等）
//
//   存储格式: JSON 数组，每个元素是一条 DetectionRecord
//   文件路径: {data_dir}/detection_history.json
//
// 依赖: models/detection_record.vala, config.vala, json-glib-1.0
// =============================================================================

namespace PcbInspector {

/**
 * 历史记录存储服务
 * 使用 JSON 文件进行持久化存储，无需外部接口
 */
public class StorageService : Object {

    private string data_dir;
    private string history_file_path;
    private string image_dir;

    /** 信号：当历史记录发生变化时触发（新增/删除） */
    public signal void history_changed ();

    /**
     * 构造函数
     * 初始化存储目录和文件路径
     */
    public StorageService () {
        data_dir          = Config.get_data_dir ();
        history_file_path = Path.build_filename (data_dir, Config.HISTORY_FILENAME);
        image_dir         = Path.build_filename (data_dir, Config.IMAGE_SAVE_DIR);

        // 确保目录存在
        ensure_directories ();
    }

    /**
     * 确保数据和图像存储目录存在
     */
    private void ensure_directories () {
        try {
            var data_file = File.new_for_path (data_dir);
            if (!data_file.query_exists ()) {
                data_file.make_directory_with_parents ();
            }

            var img_file = File.new_for_path (image_dir);
            if (!img_file.query_exists ()) {
                img_file.make_directory_with_parents ();
            }
        } catch (Error e) {
            critical ("无法创建存储目录: %s", e.message);
        }
    }

    /**
     * 保存一条检测记录到历史文件
     * 以 JSON 数组格式追加存储
     *
     * @param record 检测记录对象
     * @return 是否保存成功
     */
    public bool save_record (DetectionRecord record) {
        try {
            archive_record_image (record);

            // 读取现有记录
            var records = load_all_records ();
            records.append (record);

            // 序列化全部记录为 JSON 数组并写入文件
            var root_array = new Json.Array ();
            foreach (var r in records) {
                root_array.add_element (r.to_json_node ());
            }

            var root_node = new Json.Node (Json.NodeType.ARRAY);
            root_node.set_array (root_array);

            var generator = new Json.Generator ();
            generator.set_root (root_node);
            generator.pretty = true;
            string json_str = generator.to_data (null);

            // 写入文件
            var file = File.new_for_path (history_file_path);
            var output_stream = file.replace (null, false, FileCreateFlags.NONE);
            var data_stream = new DataOutputStream (output_stream);
            data_stream.put_string (json_str);

            message ("检测记录已保存: %s", record.record_id);
            history_changed ();  // 通知 UI 更新
            return true;

        } catch (Error e) {
            critical ("保存检测记录失败: %s", e.message);
            return false;
        }
    }

    private void archive_record_image (DetectionRecord record) {
        if (record.annotated_image_path == null || record.annotated_image_path.strip () == "") {
            return;
        }

        try {
            var source = File.new_for_path (record.annotated_image_path);
            if (!source.query_exists ()) {
                return;
            }

            string archived_name = "%s-result.jpg".printf (record.record_id);
            string archived_path = Path.build_filename (image_dir, archived_name);

            if (record.annotated_image_path == archived_path) {
                return;
            }

            var dest = File.new_for_path (archived_path);
            source.copy (dest, FileCopyFlags.OVERWRITE);
            record.annotated_image_path = archived_path;
        } catch (Error e) {
            warning ("归档历史图片失败: %s", e.message);
        }
    }

    /**
     * 从 JSON 文件加载所有历史记录
     * @return 检测记录列表（按时间顺序）
     */
    public List<DetectionRecord> load_all_records () {
        var records = new List<DetectionRecord> ();

        try {
            var file = File.new_for_path (history_file_path);
            if (!file.query_exists ()) {
                return records;  // 文件不存在，返回空列表
            }

            // 读取文件内容
            uint8[] raw_contents;
            string? etag;
            file.load_contents (null, out raw_contents, out etag);

            string content = (string) raw_contents;

            if (content == null || content.strip () == "") {
                return records;
            }

            // 解析 JSON
            var parser = new Json.Parser ();
            parser.load_from_data (content);

            var root_node = parser.get_root ();
            if (root_node == null) return records;

            var root_array = root_node.get_array ();
            if (root_array == null) return records;

            // 遍历 JSON 数组，解析每条记录
            for (uint i = 0; i < root_array.get_length (); i++) {
                var element = root_array.get_element (i);
                if (element != null) {
                    var record = DetectionRecord.from_json_node (element);
                    records.append (record);
                }
            }

            message ("已加载 %u 条历史记录", root_array.get_length ());

        } catch (Error e) {
            warning ("加载历史记录失败: %s", e.message);
        }

        return records;
    }

    /**
     * 删除指定 ID 的记录
     * @param record_id 记录 ID
     * @return 是否删除成功
     */
    public bool delete_record (string record_id) {
        try {
            var records = load_all_records ();
            bool found = false;

            // 过滤掉要删除的记录
            var remaining = new List<DetectionRecord> ();
            foreach (var r in records) {
                if (r.record_id == record_id) {
                    found = true;
                } else {
                    remaining.append (r);
                }
            }

            if (!found) {
                warning ("未找到要删除的记录: %s", record_id);
                return false;
            }

            // 重新序列化并写入
            var root_array = new Json.Array ();
            foreach (var r in remaining) {
                root_array.add_element (r.to_json_node ());
            }

            var root_node = new Json.Node (Json.NodeType.ARRAY);
            root_node.set_array (root_array);

            var generator = new Json.Generator ();
            generator.set_root (root_node);
            generator.pretty = true;

            var file = File.new_for_path (history_file_path);
            var output_stream = file.replace (null, false, FileCreateFlags.NONE);
            var data_stream = new DataOutputStream (output_stream);
            data_stream.put_string (generator.to_data (null));

            message ("已删除记录: %s", record_id);
            history_changed ();
            return true;

        } catch (Error e) {
            critical ("删除记录失败: %s", e.message);
            return false;
        }
    }

    /**
     * 获取历史统计信息
     * @return 格式化的统计摘要字符串（多行，支持 Markup）
     */
    public string get_statistics () {
        var records = load_all_records ();
        var builder = new StringBuilder ();

        int total = (int) records.length ();
        int defective_count = 0;
        int total_defects = 0;

        // 各类缺陷累计次数
        int[] defect_sums = new int[5];  // 按 DefectType 枚举顺序
        for (int i = 0; i < 5; i++) {
            defect_sums[i] = 0;
        }

        foreach (var r in records) {
            if (r.has_defect) {
                defective_count++;
            }
            total_defects += r.total_defect_count;

            defect_sums[0] += r.get_defect_count (DefectType.MOUSE_BITE);
            defect_sums[1] += r.get_defect_count (DefectType.OPEN_CIRCUIT);
            defect_sums[2] += r.get_defect_count (DefectType.SHORT);
            defect_sums[3] += r.get_defect_count (DefectType.SPUR);
            defect_sums[4] += r.get_defect_count (DefectType.SPURIOUS_COPPER);
        }

        double pass_rate = (total > 0)
            ? (double) (total - defective_count) / total * 100.0
            : 100.0;

        builder.append ("<b>=== 历史统计 ===</b>\n\n");
        builder.append_printf ("总检测次数: %d\n", total);
        builder.append_printf ("不合格次数: %d\n", defective_count);
        builder.append_printf ("合格率:     %.1f%%\n", pass_rate);
        builder.append_printf ("累计缺陷数: %d\n\n", total_defects);

        DefectType[] all_types = {
            DefectType.MOUSE_BITE,
            DefectType.OPEN_CIRCUIT,
            DefectType.SHORT,
            DefectType.SPUR,
            DefectType.SPURIOUS_COPPER
        };

        builder.append ("--- 各类缺陷出现总次数 ---\n");
        for (int i = 0; i < all_types.length; i++) {
            builder.append_printf ("  %s: %d 次\n",
                all_types[i].to_chinese (), defect_sums[i]);
        }

        return builder.str;
    }

    /**
     * 获取图像保存目录路径
     * @return 图像目录绝对路径
     */
    public string get_image_dir () {
        return image_dir;
    }
}

} // namespace PcbInspector
