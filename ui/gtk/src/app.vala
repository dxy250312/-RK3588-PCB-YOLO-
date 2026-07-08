// =============================================================================
// 模块: app.vala — 应用程序类（重构版）
// =============================================================================
// 内容说明:
//   重构后职责大幅简化：
//   - 不再创建和注入 Detection/Camera/Conveyor 服务
//   - 仅创建 MainWindow，MainWindow 内部自行管理 PipelineService
//   - 外部系统可通过 D-Bus 等方式获取 PipelineService 引用
//
//   外部集成方式:
//   1. 启动本应用
//   2. 外部程序获取 PipelineService 的 D-Bus 对象路径
//   3. 用户在 UI 点击"开始检测" → start_requested 信号发出
//   4. 外部程序完成检测后调用 submit_result(json, image_path)
//   5. UI 自动更新
//
// 依赖: window.vala
// =============================================================================

namespace PcbInspector {

public class App : Gtk.Application {

    private MainWindow? main_window = null;

    public App () {
        Object (
            application_id: "com.pcb-inspector.app",
            flags: ApplicationFlags.NON_UNIQUE
        );
    }

    public override void activate () {
        if (main_window == null) {
            main_window = new MainWindow (this);

            main_window.close_request.connect (() => {
                main_window.stop_preview ();
                main_window = null;
                return false;
            });
        }

        main_window.present ();
    }

    public override void startup () {
        base.startup ();

        message ("PCB 缺陷检测系统正在启动...");
        message ("平台: RK3588 / ARM64");
        message ("架构: GTK4 + Vala");
        message ("通信: PipelineService (D-Bus / 文件监控)");
    }

    public override void shutdown () {
        message ("PCB 缺陷检测系统正在关闭...");
        base.shutdown ();
    }
}

} // namespace PcbInspector
