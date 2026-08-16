import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'core/database/database.dart';
import 'core/platform/flux_title_bar.dart';
import 'core/router/app_router.dart';
import 'core/services/library_scanner.dart';
import 'core/services/providers.dart';
import 'core/theme/app_theme.dart';
import 'features/player/player_screen.dart';
import 'features/settings/settings_providers.dart';
import 'l10n/generated/app_localizations.dart';

/// Runs once at startup: auto-scan the library when enabled in settings.
final bootstrapProvider = FutureProvider<void>((ref) async {
  final prefs = ref.read(databaseProvider).preferencesDao;
  final autoScan = (await prefs.getValue('auto_scan') ?? 'true') == 'true';
  if (autoScan) {
    await ref.read(libraryScannerProvider).scanAll();
  }
});

class FluxApp extends ConsumerWidget {
  const FluxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(bootstrapProvider);
    final router = ref.watch(routerProvider);
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? const FluxSettings();
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: FluxTheme.of(settings.themeMode, settings.accent),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        if (!Platform.isWindows) return content;
        // Windows desktop chrome: custom title bar + drag-and-drop opening.
        return DropTarget(
          onDragDone: (details) {
            final videos = details.files.where((f) => LibraryScanner
                .videoExtensions
                .contains(p.extension(f.path).toLowerCase()));
            if (videos.isNotEmpty) {
              ref.read(routerProvider).push(Uri(
                path: PlayerScreen.route,
                queryParameters: {'path': videos.first.path},
              ).toString());
            }
          },
          child: Column(
            children: [
              const FluxTitleBar(),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }
}
