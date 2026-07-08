// =============================================================================
// 模块: widgets/history_panel.vala — 历史记录面板
// =============================================================================
// 内容说明:
//   显示所有历史检测记录的面板，作为独立页面（通过 Stack 切换）。
//   功能包括：
//   - 历史记录列表（按时间倒序排列）
//   - 每条记录显示：时间、ID、是否合格、缺陷数
//   - 点击记录可展开查看详情（各类缺陷统计）
//   - 统计信息概览区域（总次数、合格率、各类缺陷累计）
//   - 删除选中记录功能
//   - 返回主检测页面按钮
//
// 依赖: config.vala, models/detection_record.vala, services/storage_service.vala
// =============================================================================

namespace PcbInspector {

/**
 * 历史记录面板
 */
public class HistoryPanel : Gtk.Box {

    // ---- 服务依赖 ----
    private StorageService storage_service;

    // ---- UI 组件 ----
    private Gtk.Label       stats_label;          // 统计信息
    private Gtk.ListBox     history_listbox;      // 历史记录列表
    private Gtk.Button      delete_button;        // 删除按钮
    private Gtk.Button      refresh_button;       // 刷新按钮
    private Gtk.Button      back_button;          // 返回按钮
    private Gtk.Stack       detail_stack;         // 详情/列表切换
    private Gtk.Label       detail_label;         // 详情文字
    private Gtk.Label       detail_title;         // 详情标题
    private Gtk.Picture     detail_picture;       // 历史图片预览
    private Gtk.Label       detail_image_label;   // 历史图片状态

    /** 当前选中的记录 ID */
    private string? selected_record_id = null;

    /** 信号: 请求返回主检测页面 */
    public signal void back_clicked ();

    /**
     * 构造函数
     * @param storage 存储服务实例
     */
    public HistoryPanel (StorageService storage) {
        this.storage_service = storage;
        this.orientation = Gtk.Orientation.VERTICAL;
        this.spacing = 8;
        this.margin_start = 16;
        this.margin_end = 16;
        this.margin_top = 12;
        this.margin_bottom = 12;

        build_header ();
        build_stats_section ();
        build_toolbar ();
        build_content_area ();

        // 初始加载数据
        refresh_data ();

        // 监听存储变化
        storage_service.history_changed.connect (refresh_data);
    }

    /**
     * 构建顶部标题栏
     */
    private void build_header () {
        var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        header_box.margin_bottom = 4;

        var title = new Gtk.Label ("<b>📊 检测历史记录</b>");
        title.use_markup = true;
        title.halign = Gtk.Align.START;
        title.hexpand = true;
        title.add_css_class ("history-header");
        header_box.append (title);

        // 返回按钮
        back_button = new Gtk.Button.with_label ("← 返回检测");
        back_button.add_css_class ("back-button");
        back_button.clicked.connect (() => {
            // 如果正在查看详情，先返回列表
            if (detail_stack.visible_child_name == "detail") {
                detail_stack.visible_child_name = "list";
            } else {
                back_clicked ();
            }
        });
        header_box.append (back_button);

        var separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);

        this.append (header_box);
        this.append (separator);
    }

    /**
     * 构建统计概览区域
     */
    private void build_stats_section () {
        var stats_frame = new Gtk.Frame (null);
        stats_frame.add_css_class ("stats-frame");

        var scrolled = new Gtk.ScrolledWindow ();
        scrolled.set_size_request (-1, 160);
        scrolled.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);

        stats_label = new Gtk.Label ("");
        stats_label.use_markup = true;
        stats_label.halign = Gtk.Align.START;
        stats_label.valign = Gtk.Align.START;
        stats_label.margin_start = 12;
        stats_label.margin_end = 12;
        stats_label.margin_top = 8;
        stats_label.margin_bottom = 8;
        stats_label.wrap = true;
        stats_label.xalign = 0;
        stats_label.add_css_class ("stats-label");

        scrolled.set_child (stats_label);
        stats_frame.set_child (scrolled);

        this.append (stats_frame);
    }

    /**
     * 构建工具栏（刷新 & 删除）
     */
    private void build_toolbar () {
        var toolbar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);

        var toolbar_label = new Gtk.Label ("<b>记录列表</b>");
        toolbar_label.use_markup = true;
        toolbar_label.halign = Gtk.Align.START;
        toolbar_label.hexpand = true;
        toolbar_label.add_css_class ("toolbar-label");
        toolbar.append (toolbar_label);

        // 刷新按钮
        refresh_button = new Gtk.Button.with_label ("🔄 刷新");
        refresh_button.clicked.connect (refresh_data);
        toolbar.append (refresh_button);

        // 删除按钮
        delete_button = new Gtk.Button.with_label ("🗑 删除选中");
        delete_button.add_css_class ("destructive-action");
        delete_button.sensitive = false;
        delete_button.clicked.connect (on_delete_clicked);
        toolbar.append (delete_button);

        this.append (toolbar);
    }

    /**
     * 构建内容区域（列表 + 详情 Stack）
     */
    private void build_content_area () {
        detail_stack = new Gtk.Stack ();
        detail_stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
        detail_stack.set_transition_duration (250);
        detail_stack.vexpand = true;

        // ---- 页面1: 记录列表 ----
        var list_scrolled = new Gtk.ScrolledWindow ();
        list_scrolled.vexpand = true;

        history_listbox = new Gtk.ListBox ();
        history_listbox.selection_mode = Gtk.SelectionMode.SINGLE;
        history_listbox.add_css_class ("history-list");
        history_listbox.row_selected.connect (on_row_selected);
        history_listbox.row_activated.connect (on_row_activated);

        list_scrolled.set_child (history_listbox);
        detail_stack.add_named (list_scrolled, "list");

        // ---- 页面2: 记录详情 ----
        var detail_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
        detail_box.margin_start = 12;
        detail_box.margin_end = 12;
        detail_box.margin_top = 8;
        detail_box.margin_bottom = 8;

        detail_title = new Gtk.Label ("");
        detail_title.use_markup = true;
        detail_title.halign = Gtk.Align.START;
        detail_title.add_css_class ("detail-title");
        detail_box.append (detail_title);

        var detail_sep = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        detail_box.append (detail_sep);

        var image_frame = new Gtk.Frame (null);
        image_frame.set_size_request (-1, 360);
        image_frame.vexpand = false;

        var image_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        image_box.margin_start = 8;
        image_box.margin_end = 8;
        image_box.margin_top = 8;
        image_box.margin_bottom = 8;

        detail_picture = new Gtk.Picture ();
        detail_picture.hexpand = true;
        detail_picture.vexpand = true;
        detail_picture.halign = Gtk.Align.FILL;
        detail_picture.valign = Gtk.Align.FILL;
        detail_picture.can_shrink = true;
        detail_picture.keep_aspect_ratio = true;
        image_box.append (detail_picture);

        detail_image_label = new Gtk.Label ("");
        detail_image_label.halign = Gtk.Align.START;
        detail_image_label.ellipsize = Pango.EllipsizeMode.MIDDLE;
        detail_image_label.add_css_class ("image-info-text");
        image_box.append (detail_image_label);

        image_frame.set_child (image_box);
        detail_box.append (image_frame);

        var detail_scrolled = new Gtk.ScrolledWindow ();
        detail_scrolled.vexpand = true;

        detail_label = new Gtk.Label ("");
        detail_label.use_markup = true;
        detail_label.halign = Gtk.Align.START;
        detail_label.valign = Gtk.Align.START;
        detail_label.xalign = 0;
        detail_label.wrap = true;
        detail_label.margin_top = 4;
        detail_label.add_css_class ("detail-text");

        detail_scrolled.set_child (detail_label);
        detail_box.append (detail_scrolled);

        // 返回列表按钮
        var back_to_list_btn = new Gtk.Button.with_label ("← 返回列表");
        back_to_list_btn.halign = Gtk.Align.START;
        back_to_list_btn.clicked.connect (() => {
            detail_stack.visible_child_name = "list";
        });
        detail_box.append (back_to_list_btn);

        detail_stack.add_named (detail_box, "detail");

        this.append (detail_stack);
    }

    /**
     * 刷新所有数据（统计 + 列表）
     */
    public void refresh_data () {
        update_statistics ();
        populate_history_list ();
        delete_button.sensitive = false;
        selected_record_id = null;
    }

    /**
     * 更新统计概览
     */
    private void update_statistics () {
        string stats = storage_service.get_statistics ();
        stats_label.set_markup (stats);
    }

    /**
     * 填充历史记录列表
     * 按时间倒序显示
     */
    private void populate_history_list () {
        // 清空现有列表
        Gtk.Widget? child = null;
        while ((child = history_listbox.get_first_child ()) != null) {
            history_listbox.remove (child);
        }

        var records = storage_service.load_all_records ();

        // 反转列表（最新在前）
        var reversed = new List<DetectionRecord> ();
        foreach (var r in records) {
            reversed.prepend (r);
        }

        if (reversed.length () == 0) {
            // 空状态
            var empty_row = new Gtk.Label ("暂无历史检测记录");
            empty_row.margin_top = 24;
            empty_row.margin_bottom = 24;
            empty_row.halign = Gtk.Align.CENTER;
            empty_row.add_css_class ("empty-text");
            history_listbox.append (empty_row);
            return;
        }

        foreach (var record in reversed) {
            var row = create_history_row (record);
            history_listbox.append (row);
        }
    }

    /**
     * 创建一条历史记录行（增强版：突出时间戳 + 图标）
     * @param record 检测记录
     * @return 行 Widget
     */
    private Gtk.Widget create_history_row (DetectionRecord record) {
        var row_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        row_box.margin_start = 8;
        row_box.margin_end = 8;
        row_box.margin_top = 8;
        row_box.margin_bottom = 8;

        // ---- 左侧: 大图标 ----
        string icon = record.has_defect ? "❌" : "✅";
        var icon_label = new Gtk.Label (icon);
        icon_label.add_css_class ("history-icon");
        icon_label.valign = Gtk.Align.CENTER;
        icon_label.set_size_request (36, -1);
        row_box.append (icon_label);

        // ---- 中间: 时间戳（主）+ 记录ID（副）+ 缺陷摘要 ----
        var info_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 3);
        info_box.hexpand = true;
        info_box.valign = Gtk.Align.CENTER;

        // 格式化时间戳为更可读的形式
        string display_time = record.timestamp;
        var dt = new DateTime.from_iso8601 (record.timestamp, null);
        if (dt != null) {
            display_time = dt.format ("%Y-%m-%d %H:%M:%S");
        }

        var time_label = new Gtk.Label (display_time);
        time_label.halign = Gtk.Align.START;
        time_label.add_css_class ("history-time");
        info_box.append (time_label);

        var id_label = new Gtk.Label (record.record_id);
        id_label.halign = Gtk.Align.START;
        id_label.add_css_class ("history-id");
        info_box.append (id_label);

        row_box.append (info_box);

        // ---- 右侧: 缺陷计数 + 状态 ----
        var right_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 3);
        right_box.valign = Gtk.Align.CENTER;
        right_box.halign = Gtk.Align.END;

        string status_text;
        if (record.has_defect) {
            status_text = "<span foreground='#e74c3c'><b>%d 处缺陷</b></span>"
                .printf (record.total_defect_count);
        } else {
            status_text = "<span foreground='#27ae60'><b>合格</b></span>";
        }
        var status_label = new Gtk.Label ("");
        status_label.use_markup = true;
        status_label.set_markup (status_text);
        status_label.halign = Gtk.Align.END;
        right_box.append (status_label);

        row_box.append (right_box);

        // 存储数据
        row_box.set_data<string> ("record_id", record.record_id);
        row_box.set_data<DetectionRecord> ("record", record);

        return row_box;
    }

    /**
     * 选中行变化回调
     */
    private void on_row_selected (Gtk.ListBoxRow? row) {
        if (row == null) {
            delete_button.sensitive = false;
            selected_record_id = null;
            return;
        }

        var child = row.get_child ();
        if (child == null) {
            delete_button.sensitive = false;
            return;
        }

        string? rid = child.get_data<string> ("record_id");
        if (rid != null) {
            selected_record_id = rid;
            delete_button.sensitive = true;
        } else {
            delete_button.sensitive = false;
        }
    }

    /**
     * 双击/激活行回调 — 查看详情
     */
    private void on_row_activated (Gtk.ListBoxRow row) {
        var child = row.get_child ();
        if (child == null) return;

        DetectionRecord? record = child.get_data<DetectionRecord> ("record");
        if (record == null) return;

        show_record_detail (record);
    }

    /**
     * 显示选中记录的详情
     */
    private void show_record_detail (DetectionRecord record) {
        detail_title.set_markup (
            "<b>📝 记录详情: %s</b>".printf (record.record_id)
        );

        var builder = new StringBuilder ();
        builder.append ("<b>记录编号：</b>%s\n".printf (record.record_id));
        builder.append ("<b>检测时间：</b>%s\n".printf (record.timestamp));
        builder.append ("<b>原始图像：</b>%s\n".printf (
            Path.get_basename (record.original_image_path)
        ));
        builder.append ("<b>标注图像：</b>%s\n".printf (
            Path.get_basename (record.annotated_image_path)
        ));
        builder.append ("\n<b>--- 判定结果 ---</b>\n");

        if (record.has_defect) {
            builder.append (
                "<span foreground='#e74c3c'><b>⚠ 不合格</b></span>\n\n"
            );
        } else {
            builder.append (
                "<span foreground='#27ae60'><b>✓ 合格</b></span>\n\n"
            );
        }

        builder.append ("<b>--- 各类缺陷明细 ---</b>\n");

        DefectType[] all_types = {
            DefectType.MOUSE_BITE,
            DefectType.OPEN_CIRCUIT,
            DefectType.SHORT,
            DefectType.SPUR,
            DefectType.SPURIOUS_COPPER
        };

        foreach (var type in all_types) {
            int count = record.get_defect_count (type);
            if (count > 0) {
                builder.append_printf (
                    "  <span foreground='%s'>●</span> %s: <b>%d 处</b>\n",
                    type.color (),
                    type.to_chinese (),
                    count
                );
            } else {
                builder.append_printf (
                    "  <span foreground='#95a5a6'>○</span> %s: 无\n",
                    type.to_chinese ()
                );
            }

            // 列出该类型的每个具体缺陷信息
            foreach (var d in record.defects) {
                if (d.defect_type == type) {
                    builder.append_printf (
                        "      └ 置信度: %.1f%%, 位置: (%.2f, %.2f)\n",
                        d.confidence * 100, d.center_x, d.center_y
                    );
                }
            }
        }

        detail_label.set_markup (builder.str);
        load_record_image (record);
        detail_stack.visible_child_name = "detail";
    }

    private void load_record_image (DetectionRecord record) {
        string image_path = record.annotated_image_path;
        if (image_path == null || image_path.strip () == "") {
            detail_picture.set_paintable (null);
            detail_image_label.label = "历史图片不存在";
            return;
        }

        try {
            var file = File.new_for_path (image_path);
            if (!file.query_exists ()) {
                detail_picture.set_paintable (null);
                detail_image_label.label = "历史图片文件不存在: %s".printf (image_path);
                return;
            }

            var texture = Gdk.Texture.from_filename (image_path);
            detail_picture.set_paintable (texture);
            detail_image_label.label = "历史图片: %s".printf (image_path);
        } catch (Error e) {
            detail_picture.set_paintable (null);
            detail_image_label.label = "历史图片加载失败: %s".printf (e.message);
        }
    }

    /**
     * 删除按钮点击回调
     */
    private void on_delete_clicked () {
        if (selected_record_id == null) {
            return;
        }

        // 显示确认对话框
        var dialog = new Gtk.MessageDialog (
            (Gtk.Window) this.get_root (),
            Gtk.DialogFlags.MODAL,
            Gtk.MessageType.QUESTION,
            Gtk.ButtonsType.YES_NO,
            "确认删除记录 %s？\n此操作不可撤销。".printf (selected_record_id)
        );

        dialog.response.connect ((response_id) => {
            if (response_id == Gtk.ResponseType.YES) {
                storage_service.delete_record (selected_record_id);
                selected_record_id = null;
                delete_button.sensitive = false;
            }
            dialog.destroy ();
        });

        dialog.show ();
    }
}

} // namespace PcbInspector
