// =============================================================================
// 模块: widgets/defect_list.vala — 左侧检测控制与结果面板
// =============================================================================

namespace PcbInspector {

public class DefectListPanel : Gtk.Box {

    private Gtk.Label status_label;
    private Gtk.Label status_icon;
    private Gtk.ListBox defect_listbox;
    private Gtk.Label total_defects_label;
    private Gtk.Button start_button;
    private Gtk.Button release_button;
    private Gtk.SpinButton delay_spin;
    private Gtk.Label status_bar_label;
    private Gtk.Spinner spinner;
    private Gtk.Stack status_stack;

    public signal void start_clicked ();
    public signal void release_clicked ();
    public signal void save_settings_clicked (int delay_ms);

    public DefectListPanel () {
        this.orientation = Gtk.Orientation.VERTICAL;
        this.spacing = 10;
        this.margin_start = 12;
        this.margin_end = 12;
        this.margin_top = 12;
        this.margin_bottom = 12;
        this.hexpand = false;
        this.width_request = 380;

        build_header ();
        build_status_section ();
        build_delay_settings ();
        build_defect_list ();
        build_summary ();
        build_start_button ();
        build_release_button ();
        build_status_bar ();

        set_ready_state ();
    }

    private void build_header () {
        var label = new Gtk.Label ("<b>检测结果</b>");
        label.use_markup = true;
        label.halign = Gtk.Align.START;
        label.margin_bottom = 8;
        label.add_css_class ("panel-header");
        this.append (label);
        this.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
    }

    private void build_status_section () {
        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        box.halign = Gtk.Align.CENTER;
        box.margin_top = 8;
        box.margin_bottom = 8;
        box.add_css_class ("status-section");

        status_stack = new Gtk.Stack ();
        status_stack.set_transition_type (Gtk.StackTransitionType.CROSSFADE);
        status_stack.set_transition_duration (200);

        status_icon = new Gtk.Label ("");
        status_icon.add_css_class ("status-icon");

        spinner = new Gtk.Spinner ();
        spinner.set_size_request (32, 32);

        status_stack.add_named (status_icon, "icon");
        status_stack.add_named (spinner, "spinner");
        status_stack.visible_child_name = "icon";
        box.append (status_stack);

        status_label = new Gtk.Label ("<b>预览中，等待触发</b>");
        status_label.use_markup = true;
        status_label.add_css_class ("status-text");
        box.append (status_label);

        this.append (box);
    }

    private void build_delay_settings () {
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        box.margin_top = 8;
        box.margin_bottom = 4;
        box.add_css_class ("settings-box");

        var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        var label = new Gtk.Label ("delay_ms:");
        label.halign = Gtk.Align.START;
        row.append (label);

        delay_spin = new Gtk.SpinButton.with_range (0, 5000, 50);
        delay_spin.value = Config.DEFAULT_DELAY_MS;
        delay_spin.hexpand = true;
        row.append (delay_spin);

        var save_button = new Gtk.Button.with_label ("保存设置");
        save_button.clicked.connect (() => {
            save_settings_clicked (get_delay_ms ());
        });
        row.append (save_button);

        box.append (row);
        this.append (box);
    }

    private void build_defect_list () {
        var title = new Gtk.Label ("<b>缺陷明细</b>");
        title.use_markup = true;
        title.halign = Gtk.Align.START;
        title.margin_top = 8;
        this.append (title);

        var scrolled = new Gtk.ScrolledWindow ();
        scrolled.vexpand = true;
        scrolled.set_size_request (-1, 220);

        defect_listbox = new Gtk.ListBox ();
        defect_listbox.selection_mode = Gtk.SelectionMode.NONE;
        defect_listbox.add_css_class ("defect-list");

        scrolled.set_child (defect_listbox);
        this.append (scrolled);
    }

    private void build_summary () {
        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        box.halign = Gtk.Align.CENTER;
        box.margin_top = 4;

        var title = new Gtk.Label ("<b>缺陷总数：</b>");
        title.use_markup = true;
        box.append (title);

        total_defects_label = new Gtk.Label ("-");
        total_defects_label.add_css_class ("defect-count");
        box.append (total_defects_label);

        this.append (box);
    }

    private void build_start_button () {
        start_button = new Gtk.Button.with_label ("手动触发检测");
        start_button.add_css_class ("start-button");
        start_button.add_css_class ("suggested-action");
        start_button.margin_top = 12;
        start_button.set_size_request (-1, 48);

        start_button.clicked.connect (() => {
            start_button.sensitive = false;
            start_button.label = "检测流程中...";
            set_status_bar_message ("等待 PCB 到位...");
            start_clicked ();
        });

        this.append (start_button);
    }

    private void build_release_button () {
        release_button = new Gtk.Button.with_label ("继续/放行，重新预览");
        release_button.sensitive = false;
        release_button.margin_top = 6;
        release_button.clicked.connect (() => {
            release_clicked ();
        });
        this.append (release_button);
    }

    private void build_status_bar () {
        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
        box.margin_top = 10;
        box.add_css_class ("status-bar");

        status_bar_label = new Gtk.Label ("系统就绪");
        status_bar_label.halign = Gtk.Align.START;
        status_bar_label.ellipsize = Pango.EllipsizeMode.END;
        box.append (status_bar_label);

        this.append (box);
    }

    public void set_ready_state () {
        status_icon.label = "○";
        status_label.set_markup ("<b>预览中，等待触发</b>");
        status_stack.visible_child_name = "icon";
        spinner.stop ();
        start_button.sensitive = true;
        start_button.label = "手动触发检测";
        release_button.sensitive = false;
        start_button.remove_css_class ("destructive-action");
        start_button.add_css_class ("suggested-action");

        clear_defect_list ();
        total_defects_label.label = "-";
        total_defects_label.remove_css_class ("defect-count-bad");
        set_status_bar_message ("视频预览中，等待 PCB 到位");
    }

    public void set_waiting_state () {
        status_icon.label = "...";
        status_label.set_markup ("<b>检测流程运行中</b>");
        status_stack.visible_child_name = "spinner";
        spinner.start ();
        start_button.sensitive = false;
        start_button.label = "检测流程中...";
        release_button.sensitive = false;
        clear_defect_list ();
        total_defects_label.label = "-";
    }

    public void set_sensor_waiting_state () {
        status_icon.label = "...";
        status_label.set_markup ("<b>预览中，等待 PCB 到位</b>");
        status_stack.visible_child_name = "spinner";
        spinner.start ();
        start_button.sensitive = false;
        start_button.label = "等待 PCB...";
        release_button.sensitive = false;
        set_status_bar_message ("等待 PCB 到位...");
    }

    public void update_detection_result (DetectionRecord record, string? image_path = null) {
        spinner.stop ();
        status_stack.visible_child_name = "icon";

        clear_defect_list ();
        populate_defect_list (record);

        if (record.has_defect) {
            status_icon.label = "NG";
            status_label.set_markup ("<b><span foreground='#e74c3c'>有缺陷，等待处理</span></b>");
            total_defects_label.label = record.total_defect_count.to_string ();
            total_defects_label.add_css_class ("defect-count-bad");
            release_button.sensitive = true;
            set_status_bar_message ("有缺陷，传送带已停止，等待人工处理");
        } else {
            status_icon.label = "OK";
            status_label.set_markup ("<b><span foreground='#27ae60'>无缺陷，自动放行</span></b>");
            total_defects_label.label = "0";
            total_defects_label.remove_css_class ("defect-count-bad");
            release_button.sensitive = false;
            set_status_bar_message ("无缺陷，已自动放行");
        }

        start_button.sensitive = true;
        start_button.label = "手动触发检测";
        start_button.grab_focus ();
    }

    public void set_error_state (string msg) {
        spinner.stop ();
        status_stack.visible_child_name = "icon";
        status_icon.label = "!";
        status_label.set_markup ("<b><span foreground='#e67e22'>异常</span></b>");
        start_button.sensitive = true;
        start_button.label = "重试";
        release_button.sensitive = true;
        set_status_bar_message (msg);
    }

    private void populate_defect_list (DetectionRecord record) {
        DefectType[] all_types = {
            DefectType.MOUSE_BITE,
            DefectType.OPEN_CIRCUIT,
            DefectType.SHORT,
            DefectType.SPUR,
            DefectType.SPURIOUS_COPPER
        };

        foreach (var type in all_types) {
            int count = record.get_defect_count (type);
            var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            row.margin_start = 8;
            row.margin_end = 8;
            row.margin_top = 4;
            row.margin_bottom = 4;

            var dot = new Gtk.Label ("");
            dot.set_markup ("<span foreground='%s' size='large'>●</span>".printf (type.color ()));
            row.append (dot);

            var name_label = new Gtk.Label (type.to_chinese ());
            name_label.halign = Gtk.Align.START;
            name_label.hexpand = true;
            name_label.add_css_class ("defect-row-name");
            row.append (name_label);

            var count_label = new Gtk.Label (null);
            if (count > 0) {
                count_label.set_markup ("<span foreground='#e74c3c'><b>%d 处</b></span>".printf (count));
            } else {
                count_label.set_markup ("<span foreground='#27ae60'>无</span>");
            }
            row.append (count_label);

            defect_listbox.append (row);
        }
    }

    private void clear_defect_list () {
        Gtk.Widget? child = null;
        while ((child = defect_listbox.get_first_child ()) != null) {
            defect_listbox.remove (child);
        }
    }

    public int get_delay_ms () {
        return (int) delay_spin.get_value ();
    }

    public void set_flow_status (string message) {
        set_status_bar_message (message);
    }

    public void set_release_enabled (bool enabled) {
        release_button.sensitive = enabled;
    }

    public void set_status_bar_message (string message) {
        status_bar_label.label = message;
    }
}

} // namespace PcbInspector
