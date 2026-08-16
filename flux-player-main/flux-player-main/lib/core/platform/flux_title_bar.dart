import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/colors.dart';
import 'desktop_shell.dart';

/// Custom Windows title bar: logo, app name, current media title and
/// window controls (minimize / maximize / close).
class FluxTitleBar extends StatelessWidget {
  const FluxTitleBar({super.key});

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    return Container(
      height: 36,
      color: FluxColors.surface,
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(LucideIcons.play, size: 14, color: FluxColors.indigo),
          const SizedBox(width: 8),
          Text(l10n.appName, style: labelStyle),
          const SizedBox(width: 12),
          Expanded(
            child: DragToMoveArea(
              child: ValueListenableBuilder<String?>(
                valueListenable: DesktopShell.instance.nowPlaying,
                builder: (context, title, child) => Text(
                  title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: labelStyle,
                ),
              ),
            ),
          ),
          IconButton(
            iconSize: 14,
            icon: const Icon(LucideIcons.minus),
            onPressed: windowManager.minimize,
          ),
          IconButton(
            iconSize: 14,
            icon: const Icon(LucideIcons.square),
            onPressed: _toggleMaximize,
          ),
          IconButton(
            iconSize: 14,
            icon: const Icon(LucideIcons.x),
            onPressed: windowManager.close,
          ),
        ],
      ),
    );
  }
}
