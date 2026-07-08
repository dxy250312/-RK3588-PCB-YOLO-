// =============================================================================
// 模块: widgets/image_viewer.vala — 右侧预览/结果显示组件
// =============================================================================
// 说明:
//   拍照前读取 photo.txt 中的 GStreamer 摄像头命令，转换为 UI 可刷新的
//   JPEG 预览帧；拍照/检测完成后停止预览并显示标注结果图片。
// =============================================================================

namespace PcbInspector {

public class ImageViewer : Gtk.Box {

    private Gtk.Stack viewer_stack;
    private Gtk.Picture image_picture;
    private Gtk.Label placeholder_label;
    private Gtk.Label image_info_label;
    private Gtk.Label title_label;
    private Gtk.Label preview_status_label;
    private string? current_image_path = null;
    private bool preview_running = false;
    private Pid preview_pid = 0;
    private uint preview_refresh_id = 0;
    private uint preview_start_id = 0;
    private uint64 last_preview_mtime = 0;
    private string preview_frame_path;

    public ImageViewer () {
        this.orientation = Gtk.Orientation.VERTICAL;
        this.spacing = 8;
        this.margin_start = 12;
        this.margin_end = 12;
        this.margin_top = 12;
        this.margin_bottom = 12;
        this.hexpand = true;
        this.vexpand = true;

        build_title ();
        build_display_area ();
        build_info_bar ();
        preview_frame_path = Path.build_filename (Config.get_data_dir (), "camera_preview.jpg");

        start_video_preview ();
    }

    private void build_title () {
        title_label = new Gtk.Label ("<b>拍照前视频预览</b>");
        title_label.use_markup = true;
        title_label.halign = Gtk.Align.START;
        title_label.margin_bottom = 4;
        title_label.add_css_class ("viewer-title");

        this.append (title_label);
        this.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
    }

    private void build_display_area () {
        viewer_stack = new Gtk.Stack ();
        viewer_stack.set_transition_type (Gtk.StackTransitionType.CROSSFADE);
        viewer_stack.set_transition_duration (220);
        viewer_stack.vexpand = true;
        viewer_stack.hexpand = true;

        viewer_stack.add_named (build_preview_page (), "preview");
        viewer_stack.add_named (build_placeholder_page (), "placeholder");
        viewer_stack.add_named (build_image_page (), "image");

        this.append (viewer_stack);
    }

    private Gtk.Widget build_preview_page () {
        var outer = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        outer.hexpand = true;
        outer.vexpand = true;
        outer.halign = Gtk.Align.FILL;
        outer.valign = Gtk.Align.FILL;
        outer.add_css_class ("preview-shell");

        var preview_frame = new Gtk.Box (Gtk.Orientation.VERTICAL, 14);
        preview_frame.hexpand = true;
        preview_frame.vexpand = true;
        preview_frame.halign = Gtk.Align.FILL;
        preview_frame.valign = Gtk.Align.FILL;
        preview_frame.margin_top = 18;
        preview_frame.margin_bottom = 18;
        preview_frame.margin_start = 18;
        preview_frame.margin_end = 18;
        preview_frame.add_css_class ("preview-frame");

        var live_tag = new Gtk.Label ("LIVE");
        live_tag.halign = Gtk.Align.START;
        live_tag.add_css_class ("preview-live-tag");
        preview_frame.append (live_tag);

        var center = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
        center.hexpand = true;
        center.vexpand = true;
        center.halign = Gtk.Align.CENTER;
        center.valign = Gtk.Align.CENTER;

        var icon = new Gtk.Label ("▣");
        icon.add_css_class ("preview-icon");
        center.append (icon);

        var title = new Gtk.Label ("实时视频流预览区");
        title.add_css_class ("preview-title");
        center.append (title);

        preview_status_label = new Gtk.Label ("正在准备摄像头视频流");
        preview_status_label.add_css_class ("preview-subtitle");
        center.append (preview_status_label);

        preview_frame.append (center);

        var bottom = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        bottom.halign = Gtk.Align.FILL;
        bottom.add_css_class ("preview-bottom-bar");

        var device = new Gtk.Label ("Camera: %s".printf (Config.CAMERA_DEVICE));
        device.halign = Gtk.Align.START;
        device.hexpand = true;
        bottom.append (device);

        var format = new Gtk.Label ("%dx%d · %dfps".printf (
            Config.PREVIEW_WIDTH,
            Config.PREVIEW_HEIGHT,
            Config.PREVIEW_FPS
        ));
        format.halign = Gtk.Align.END;
        bottom.append (format);

        preview_frame.append (bottom);
        outer.append (preview_frame);
        return outer;
    }

    private Gtk.Widget build_placeholder_page () {
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        box.valign = Gtk.Align.CENTER;
        box.halign = Gtk.Align.CENTER;

        var icon_label = new Gtk.Label ("□");
        icon_label.add_css_class ("placeholder-icon");

        placeholder_label = new Gtk.Label ("暂无检测图片");
        placeholder_label.justify = Gtk.Justification.CENTER;
        placeholder_label.wrap = true;
        placeholder_label.add_css_class ("placeholder-text");

        box.append (icon_label);
        box.append (placeholder_label);
        return box;
    }

    private Gtk.Widget build_image_page () {
        var image_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        image_box.hexpand = true;
        image_box.vexpand = true;
        image_box.valign = Gtk.Align.FILL;
        image_box.halign = Gtk.Align.FILL;

        image_picture = new Gtk.Picture ();
        image_picture.hexpand = true;
        image_picture.vexpand = true;
        image_picture.halign = Gtk.Align.FILL;
        image_picture.valign = Gtk.Align.FILL;
        image_picture.can_shrink = true;
        image_picture.keep_aspect_ratio = true;

        image_box.append (image_picture);
        return image_box;
    }

    private void build_info_bar () {
        var info_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        info_box.margin_top = 4;
        info_box.add_css_class ("image-info-bar");

        image_info_label = new Gtk.Label ("");
        image_info_label.halign = Gtk.Align.START;
        image_info_label.ellipsize = Pango.EllipsizeMode.MIDDLE;
        image_info_label.add_css_class ("image-info-text");
        info_box.append (image_info_label);

        this.append (info_box);
    }

    public void load_image (string image_path, string record_id, string timestamp) {
        try {
            stop_video_preview ();

            var file = File.new_for_path (image_path);
            if (!file.query_exists ()) {
                warning ("图像文件不存在: %s", image_path);
                show_placeholder ("结果图片不存在");
                return;
            }

            var texture = Gdk.Texture.from_filename (image_path);
            image_picture.set_paintable (texture);
            current_image_path = image_path;

            title_label.set_markup ("<b>检测结果图片</b>");
            image_info_label.label = "记录: %s | 时间: %s | 文件: %s".printf (
                record_id,
                timestamp,
                Path.get_basename (image_path)
            );
            viewer_stack.visible_child_name = "image";

        } catch (Error e) {
            critical ("加载图像失败: %s", e.message);
            show_placeholder ("结果图片加载失败");
        }
    }

    public void show_placeholder (string message = "暂无检测图片") {
        stop_video_preview ();
        placeholder_label.label = message;
        viewer_stack.visible_child_name = "placeholder";
        current_image_path = null;
        image_info_label.label = "";
    }

    public void start_video_preview () {
        current_image_path = null;
        title_label.set_markup ("<b>拍照前视频预览</b>");
        viewer_stack.visible_child_name = "preview";

        if (preview_running) {
            return;
        }

        if (preview_start_id == 0) {
            preview_start_id = Timeout.add (80, begin_video_preview_when_ready);
        }
    }

    private bool begin_video_preview_when_ready () {
        int target_width = get_preview_width ();
        int target_height = get_preview_height ();

        if (target_width < 160 || target_height < 120) {
            return true;
        }

        preview_start_id = 0;

        try {
            string command = build_preview_command (target_width, target_height);
            string[] argv = { "/bin/sh", "-c", "exec " + command };

            Process.spawn_async (
                null,
                argv,
                null,
                SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                null,
                out preview_pid
            );

            preview_running = true;
            preview_status_label.label = "视频流已接入 UI";
            image_info_label.label = "预览尺寸: %dx%d | 命令: %s".printf (
                target_width,
                target_height,
                Path.get_basename (Config.PHOTO_COMMAND_FILE)
            );
            preview_refresh_id = Timeout.add (100, refresh_preview_frame);

        } catch (Error e) {
            preview_running = false;
            preview_pid = 0;
            preview_status_label.label = "摄像头预览启动失败";
            image_info_label.label = e.message;
        }

        return false;
    }

    public void stop_video_preview () {
        if (preview_start_id != 0) {
            Source.remove (preview_start_id);
            preview_start_id = 0;
        }

        if (preview_refresh_id != 0) {
            Source.remove (preview_refresh_id);
            preview_refresh_id = 0;
        }

        if (preview_pid != 0) {
            Posix.kill ((Posix.pid_t) preview_pid, Posix.Signal.TERM);
            Process.close_pid (preview_pid);
            preview_pid = 0;
        }

        preview_running = false;
    }

    private string build_preview_command (int target_width, int target_height) throws Error {
        string content;
        FileUtils.get_contents (Config.PHOTO_COMMAND_FILE, out content);

        string gst_command = "";
        foreach (string raw_line in content.replace ("\r", "").split ("\n")) {
            string line = raw_line.strip ();
            if (line.has_prefix ("gst-launch-1.0")) {
                gst_command = line;
                break;
            }
        }

        if (gst_command == "") {
            throw new IOError.FAILED ("photo.txt 中没有找到 gst-launch-1.0 命令");
        }

        string sink = "videoscale ! video/x-raw,width=%d,height=%d ! videoconvert ! jpegenc ! multifilesink location=%s".printf (
            target_width,
            target_height,
            preview_frame_path
        );
        if (gst_command.contains ("! autovideosink")) {
            return gst_command.replace ("! autovideosink", "! " + sink);
        }

        return gst_command + " ! " + sink;
    }

    private int get_preview_width () {
        int width = viewer_stack.get_allocated_width ();
        if (width <= 0) {
            width = image_picture.get_allocated_width ();
        }
        if (width <= 0) {
            width = Config.PREVIEW_WIDTH;
        }
        return make_even (width * 108 / 100);
    }

    private int get_preview_height () {
        int height = viewer_stack.get_allocated_height ();
        if (height <= 0) {
            height = image_picture.get_allocated_height ();
        }
        if (height <= 0) {
            height = Config.PREVIEW_HEIGHT;
        }
        return make_even (height * 108 / 100);
    }

    private int make_even (int value) {
        if (value < 2) {
            return 2;
        }
        return value - (value % 2);
    }

    private bool refresh_preview_frame () {
        if (!preview_running) {
            return false;
        }

        uint64 mtime = get_file_mtime_us (preview_frame_path);
        if (mtime == 0 || mtime == last_preview_mtime) {
            return true;
        }

        last_preview_mtime = mtime;
        try {
            var texture = Gdk.Texture.from_filename (preview_frame_path);
            image_picture.set_paintable (texture);
            viewer_stack.visible_child_name = "image";
            title_label.set_markup ("<b>拍照前视频预览</b>");
        } catch (Error e) {
            warning ("刷新视频预览帧失败: %s", e.message);
        }

        return true;
    }

    private uint64 get_file_mtime_us (string path) {
        try {
            var file = File.new_for_path (path);
            var info = file.query_info (
                "time::modified,time::modified-usec",
                FileQueryInfoFlags.NONE
            );
            uint64 sec = info.get_attribute_uint64 ("time::modified");
            uint32 usec = info.get_attribute_uint32 ("time::modified-usec");
            return sec * 1000000 + usec;
        } catch (Error e) {
            return 0;
        }
    }

    public bool is_preview_running () {
        return preview_running;
    }

    public string? get_current_image_path () {
        return current_image_path;
    }

    public void set_title (string title) {
        title_label.set_markup ("<b>%s</b>".printf (title));
    }
}

} // namespace PcbInspector
