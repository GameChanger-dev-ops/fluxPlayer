import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/generated/app_localizations.dart';
import '../logging/flux_logger.dart';

/// Windows system tray integration and desktop shell state
/// (current media title for the custom title bar).
class DesktopShell with TrayListener {
  DesktopShell._();

  static final DesktopShell instance = DesktopShell._();

  /// Shown in the custom Windows title bar while media plays.
  final ValueNotifier<String?> nowPlaying = ValueNotifier(null);

  Player? _activePlayer;

  void attachPlayer(Player player, String title) {
    _activePlayer = player;
    nowPlaying.value = title;
  }

  void detachPlayer(Player player) {
    if (_activePlayer == player) {
      _activePlayer = null;
      nowPlaying.value = null;
    }
  }

  AppLocalizations _l10n() {
    try {
      return lookupAppLocalizations(ui.PlatformDispatcher.instance.locale);
    } on FlutterError {
      return lookupAppLocalizations(const ui.Locale('en'));
    }
  }

  Future<void> init() async {
    if (!Platform.isWindows) return;
    trayManager.addListener(this);
    try {
      await trayManager.setIcon('assets/tray_icon.ico');
    } on Exception catch (e) {
      // Tray menu still works if the icon asset is not bundled yet.
      FluxLogger.instance.w('Tray icon not set', e);
    }
    final l10n = _l10n();
    try {
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(key: 'play_pause', label: l10n.trayPlayPause),
        MenuItem(key: 'stop', label: l10n.trayStop),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: l10n.trayQuit),
      ]));
    } on Exception catch (e) {
      FluxLogger.instance.w('Tray menu setup failed', e);
    }
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'play_pause':
        _activePlayer?.playOrPause();
      case 'stop':
        _activePlayer?.pause();
        _activePlayer?.seek(Duration.zero);
      case 'quit':
        windowManager.destroy();
    }
  }

  void dispose() {
    trayManager.removeListener(this);
  }
}
