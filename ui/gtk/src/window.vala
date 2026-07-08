// =============================================================================
// 模块: window.vala — 主窗口与 UI 主控流程
// =============================================================================

namespace PcbInspector {

public class MainWindow : Gtk.ApplicationWindow {

    private StorageService storage_service;
    private PipelineService pipeline;
    private HardwareService hardware;
    private DetectorRunner detector;

    private Gtk.HeaderBar header_bar;
    private Gtk.Stack main_stack;
    private Gtk.Button history_button;
    private DefectListPanel defect_panel;
    private ImageViewer image_viewer;
    private Gtk.Paned detect_paned;
    private HistoryPanel history_panel;

    private bool is_detecting = false;

    public MainWindow (Gtk.Application app) {
        Object (application: app);

        storage_service = new StorageService ();
        pipeline = new PipelineService ();
        hardware = new HardwareService ();
        detector = new DetectorRunner ();

        this.title = Config.APP_TITLE;
        this.set_default_size (Config.WINDOW_WIDTH, Config.WINDOW_HEIGHT);
        this.set_size_request (Config.WINDOW_MIN_WIDTH, Config.WINDOW_MIN_HEIGHT);

        build_header_bar ();
        build_main_content ();
        load_custom_css ();
        connect_signals ();

        defect_panel.set_ready_state ();
        image_viewer.start_video_preview ();
        hardware.start_sensor_monitor ();
    }

    public PipelineService get_pipeline () {
        return pipeline;
    }

    private void connect_signals () {
        defect_panel.start_clicked.connect (() => {
            defect_panel.set_sensor_waiting_state ();
            hardware.start_wait_for_sensor_high ();
        });

        defect_panel.release_clicked.connect (() => {
            hardware.start_conveyor ();
            is_detecting = false;
            defect_panel.set_ready_state ();
            image_viewer.start_video_preview ();
        });

        defect_panel.save_settings_clicked.connect ((delay_ms) => {
            try {
                hardware.save_delay_ms (delay_ms);
                defect_panel.set_status_bar_message ("delay_ms 已保存: %d".printf (delay_ms));
            } catch (Error e) {
                defect_panel.set_error_state ("保存设置失败: %s".printf (e.message));
            }
        });

        hardware.sensor_high.connect (() => {
            run_one_detection_cycle ();
        });
        hardware.sensor_wait_failed.connect ((message_text) => {
            defect_panel.set_error_state (message_text);
            is_detecting = false;
        });

        hardware.status_changed.connect ((state, message_text) => {
            defect_panel.set_flow_status (message_text);
        });

        pipeline.result_received.connect (on_result_received);
        detector.detection_finished.connect ((record, result_image_path) => {
            on_result_received (record, result_image_path);
        });
        detector.detection_failed.connect ((message_text) => {
            defect_panel.set_error_state (message_text);
            hardware.release_cycle_resources ();
            image_viewer.start_video_preview ();
            is_detecting = false;
        });

        history_panel.back_clicked.connect (() => {
            main_stack.visible_child_name = "detect";
            history_button.visible = true;
        });
    }

    private void build_header_bar () {
        header_bar = new Gtk.HeaderBar ();
        header_bar.set_show_title_buttons (false);

        var title_widget = new Gtk.Label ("<b>PCB缺陷检测系统</b>");
        title_widget.use_markup = true;
        header_bar.set_title_widget (title_widget);

        history_button = new Gtk.Button.with_label ("历史");
        history_button.clicked.connect (() => {
            main_stack.visible_child_name = "history";
            history_button.visible = false;
            history_panel.refresh_data ();
        });
        header_bar.pack_end (history_button);

        var exit_button = new Gtk.Button.with_label ("退出");
        exit_button.clicked.connect (() => {
            close ();
        });
        header_bar.pack_end (exit_button);

        this.set_titlebar (header_bar);
    }

    private void build_main_content () {
        main_stack = new Gtk.Stack ();
        main_stack.set_transition_type (Gtk.StackTransitionType.CROSSFADE);
        main_stack.set_transition_duration (240);

        detect_paned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        detect_paned.set_position (400);
        detect_paned.set_wide_handle (true);

        defect_panel = new DefectListPanel ();
        defect_panel.set_size_request (380, -1);
        detect_paned.set_start_child (defect_panel);

        image_viewer = new ImageViewer ();
        detect_paned.set_end_child (image_viewer);

        main_stack.add_named (detect_paned, "detect");

        history_panel = new HistoryPanel (storage_service);
        main_stack.add_named (history_panel, "history");

        main_stack.visible_child_name = "detect";
        this.set_child (main_stack);
    }

    private void run_one_detection_cycle () {
        if (is_detecting) {
            defect_panel.set_flow_status ("正在检测中，已忽略重复触发");
            return;
        }

        is_detecting = true;
        int delay_ms = defect_panel.get_delay_ms ();
        defect_panel.set_waiting_state ();
        defect_panel.set_flow_status ("检测触发，延时等待 %d ms".printf (delay_ms));

        uint timer_id = Timeout.add ((uint) delay_ms, () => {
            hardware.clear_delay_timer_id ();
            capture_then_start_detection ();
            return false;
        });
        hardware.set_delay_timer_id (timer_id);
    }

    private void capture_then_start_detection () {
        try {
            defect_panel.set_flow_status ("正在拍照...");
            image_viewer.stop_video_preview ();

            string image_path = hardware.capture_image ();
            image_viewer.load_image (
                image_path,
                "拍照图像",
                new DateTime.now_local ().format ("%Y-%m-%d %H:%M:%S")
            );

            defect_panel.set_flow_status ("正在模型检测...");
            detector.start_detection (image_path);

        } catch (Error e) {
            defect_panel.set_error_state ("拍照失败: %s".printf (e.message));
            hardware.release_cycle_resources ();
            image_viewer.start_video_preview ();
            is_detecting = false;
        }
    }

    private void on_result_received (DetectionRecord record, string image_path) {
        defect_panel.update_detection_result (record, image_path);
        image_viewer.stop_video_preview ();
        image_viewer.load_image (image_path, record.record_id, record.timestamp);
        storage_service.save_record (record);

        if (record.has_defect) {
            hardware.stop_conveyor ();
            defect_panel.set_release_enabled (true);
        } else {
            hardware.start_conveyor ();
            defect_panel.set_release_enabled (false);
            is_detecting = false;
        }

        hardware.release_cycle_resources ();
    }

    public void stop_preview () {
        image_viewer.stop_video_preview ();
        hardware.stop_sensor_monitor ();
        hardware.release_camera ();
        hardware.release_gpio_resources ();
    }

    private void load_custom_css () {
        var css_provider = new Gtk.CssProvider ();
        string css = """
            window {
                background-color: #F5F5F8;
                color: #2D2D3A;
            }
            headerbar {
                background: linear-gradient(to bottom, #4747B2, #3B3B9E);
                color: #FFFFFF;
                border-bottom: 1px solid #33338A;
                min-height: 44px;
                padding: 0 8px;
            }
            headerbar label { color: #FFFFFF; }
            headerbar button {
                background: #FFFFFF;
                color: #111111;
                border: 1px solid rgba(0,0,0,0.18);
                border-radius: 6px;
                padding: 4px 14px;
                font-weight: 700;
            }
            headerbar button label {
                color: #111111;
            }
            headerbar button:hover {
                background: #F0F0F6;
                color: #000000;
            }
            headerbar button:hover label {
                color: #000000;
            }
            button {
                border-radius: 6px;
                padding: 4px 14px;
                font-weight: 500;
                background: #FFFFFF;
                color: #3D3D50;
                border: 1px solid #D0D0DA;
            }
            button.suggested-action {
                background: #4747B2;
                color: #FFFFFF;
                border-color: #3A3A9A;
                font-weight: 700;
            }
            button.suggested-action label { color: #FFFFFF; }
            .panel-header, .viewer-title {
                font-size: 15px;
                font-weight: 700;
                color: #4747B2;
            }
            .status-section {
                padding: 10px;
                background: #FFFFFF;
                border-radius: 8px;
                border: 1px solid #E4E4EC;
            }
            .status-icon {
                font-weight: 800;
                color: #4747B2;
                min-width: 34px;
            }
            .status-text {
                font-size: 15px;
                font-weight: 700;
            }
            .settings-box, .status-bar, .image-info-bar {
                padding: 8px 10px;
                background: #FFFFFF;
                border-radius: 8px;
                border: 1px solid #E4E4EC;
            }
            .defect-list row {
                border-bottom: 1px solid #ECECF2;
            }
            .defect-count {
                font-size: 24px;
                font-weight: 800;
                color: #4747B2;
            }
            .defect-count-bad {
                color: #E74C3C;
            }
            .preview-shell {
                background: #EEF0F7;
                border: 1px solid #D9DCE8;
                border-radius: 8px;
            }
            .preview-frame {
                background: #171927;
                border: 1px solid #343852;
                border-radius: 8px;
                color: #FFFFFF;
            }
            .preview-live-tag {
                background: #E74C3C;
                color: #FFFFFF;
                border-radius: 4px;
                padding: 2px 8px;
                font-weight: 700;
                font-size: 11px;
            }
            .preview-icon {
                color: #8EA4FF;
                font-size: 72px;
            }
            .preview-title {
                color: #FFFFFF;
                font-size: 24px;
                font-weight: 700;
            }
            .preview-subtitle {
                color: #B9C0D8;
                font-size: 14px;
            }
            .preview-bottom-bar {
                background: rgba(255,255,255,0.08);
                border-radius: 6px;
                padding: 8px 12px;
                color: #DDE3FF;
                font-size: 12px;
            }
            .image-info-text {
                font-size: 11px;
                color: #7A7A92;
            }
        """;

        css_provider.load_from_data (css.data);
        Gtk.StyleContext.add_provider_for_display (
            Gdk.Display.get_default (),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
    }
}

} // namespace PcbInspector
