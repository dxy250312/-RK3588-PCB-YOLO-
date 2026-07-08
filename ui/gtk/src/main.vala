// =============================================================================
// 模块: main.vala — 程序入口
// =============================================================================
// 内容说明:
//   应用程序入口点。创建 App 实例并启动 GTK 主循环。
//   这是整个程序的最外层，负责将控制权交给 GTK 事件循环。
//
//   编译方式:
//     meson setup build && ninja -C build
//   运行:
//     ./build/pcb-inspector
//
//   或直接用 valac 编译:
//     valac --pkg gtk4 --pkg json-glib-1.0 --pkg posix \
//           -o pcb-inspector src/*.vala src/**/*.vala
//
// 依赖: app.vala
// =============================================================================

/**
 * 程序主入口
 * @param args 命令行参数
 * @return 退出码（0 = 正常）
 */
int main (string[] args) {
    // 初始化国际化支持（可选）
    // Intl.setlocale (LocaleCategory.ALL, "");
    // Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALE_DIR);
    // Intl.textdomain (Config.GETTEXT_PACKAGE);

    // 创建应用程序实例并运行
    var app = new PcbInspector.App ();
    return app.run (args);
}
