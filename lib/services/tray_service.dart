import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'settings_manager.dart';
import 'ytmusic_auth.dart';

/// Handles the system tray icon and "close to tray" window behavior on
/// desktop platforms (Windows/Linux). macOS is intentionally excluded
/// since minimizing to the menu bar tray isn't a common macOS pattern.
class TrayService with TrayListener, WindowListener {
  final SettingsManager _settings = GetIt.I<SettingsManager>();

  static bool get _isSupportedPlatform => Platform.isWindows || Platform.isLinux;

  Future<void> init() async {
    if (!_isSupportedPlatform) return;

    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    trayManager.addListener(this);

    // We intercept the close button ourselves so we can decide whether
    // to hide to tray or actually quit, based on the user's setting.
    await windowManager.setPreventClose(true);

    await trayManager.setIcon(
      Platform.isWindows ? 'icons/nexmusic_tray.ico' : 'icons/nexmusic_nobg.png',
    );

    await trayManager.setToolTip('NexMusic');

    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show_window', label: 'Show NexMusic'),
          MenuItem(key: 'minimize_window', label: 'Minimize to Tray'),
          MenuItem.separator(),
          MenuItem(key: 'exit_app', label: 'Exit'),
        ],
      ),
    );
  }

  Future<void> dispose() async {
    if (!_isSupportedPlatform) return;
    windowManager.removeListener(this);
    trayManager.removeListener(this);
  }

  @override
  void onWindowClose() {
    if (_settings.closeToTray) {
      windowManager.hide();
    } else {
      _fullyQuit();
    }
  }

  Future<void> _fullyQuit() async {
    try {
      if (GetIt.I.isRegistered<YTMusicAuthService>()) {
        GetIt.I<YTMusicAuthService>().cancelBackgroundWork();
      }
    } catch (_) {}

    // windowManager.destroy() can occasionally block/hang if WebView2's
    // native shutdown deadlocks — never let that freeze the app. Race it
    // against a short timeout and force-exit regardless of the outcome.
    await Future.any([
      windowManager.destroy(),
      Future.delayed(const Duration(milliseconds: 800)),
    ]);
    exit(0);
  }

  @override
  void onWindowMinimize() async {
    if (_settings.minimizeToTray) {
      // Hide instead of leaving a minimized entry in the taskbar.
      await windowManager.hide();
    }
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    // On Windows, the context menu set via setContextMenu is not always
    // shown automatically on right-click — pop it up explicitly.
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        windowManager.show();
        windowManager.focus();
        break;
      case 'minimize_window':
        windowManager.hide();
        break;
      case 'exit_app':
        _fullyQuit();
        break;
    }
  }
}
