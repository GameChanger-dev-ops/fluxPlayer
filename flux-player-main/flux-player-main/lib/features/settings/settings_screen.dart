import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/database/database.dart';
import '../../core/services/secure_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../l10n/generated/app_localizations.dart';
import '../library/library_providers.dart';
import 'settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const route = '/settings';

  static const _languages = ['en', 'es', 'fr', 'de', 'pt', 'ja'];
  static const _metadataLanguages = [
    'en-US',
    'es-ES',
    'fr-FR',
    'de-DE',
    'pt-BR',
    'ja-JP',
  ];
  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  static const _skipIntroOptions = [0, 30, 60, 90];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: FilledButton(
            onPressed: () => ref.invalidate(settingsProvider),
            child: Text(l10n.retry),
          ),
        ),
        data: (settings) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section(context, l10n.playbackSection, [
              _dropdown<String>(
                context,
                l10n.defaultSubtitleLanguage,
                settings.subtitleLanguage,
                _languages,
                (v) => v.toUpperCase(),
                (v) => ref
                    .read(settingsProvider.notifier)
                    .setSubtitleLanguage(v),
              ),
              _dropdown<String>(
                context,
                l10n.defaultAudioLanguage,
                settings.audioLanguage,
                _languages,
                (v) => v.toUpperCase(),
                (v) =>
                    ref.read(settingsProvider.notifier).setAudioLanguage(v),
              ),
              SwitchListTile(
                title: Text(l10n.rememberPosition),
                value: settings.rememberPosition,
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .setRememberPosition(v),
              ),
              SwitchListTile(
                title: Text(l10n.autoPlayNext),
                value: settings.autoPlayNext,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setAutoPlayNext(v),
              ),
              _dropdown<int>(
                context,
                l10n.skipIntroDuration,
                settings.skipIntroSeconds,
                _skipIntroOptions,
                (v) => l10n.secondsValue(v),
                (v) => ref
                    .read(settingsProvider.notifier)
                    .setSkipIntroSeconds(v),
              ),
              _dropdown<double>(
                context,
                l10n.defaultPlaybackSpeed,
                settings.playbackSpeed,
                _speeds,
                (v) => '${v}x',
                (v) =>
                    ref.read(settingsProvider.notifier).setPlaybackSpeed(v),
              ),
            ]),
            _section(context, l10n.librarySection, [
              _FolderList(),
              ListTile(
                leading: const Icon(LucideIcons.folderPlus),
                title: Text(l10n.addFolder),
                onTap: () => ref.read(scanProvider.notifier).addFolder(),
              ),
              ListTile(
                leading: const Icon(LucideIcons.refreshCw),
                title: Text(l10n.scanLibrary),
                onTap: () => ref.read(scanProvider.notifier).scanAll(),
              ),
              SwitchListTile(
                title: Text(l10n.autoScanOnStart),
                value: settings.autoScanOnStart,
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .setAutoScanOnStart(v),
              ),
              _dropdown<String>(
                context,
                l10n.metadataLanguage,
                settings.metadataLanguage,
                _metadataLanguages,
                (v) => v,
                (v) => ref
                    .read(settingsProvider.notifier)
                    .setMetadataLanguage(v),
              ),
              _ApiKeyField(
                storageKey: SecureStore.tmdbApiKey,
                label: l10n.tmdbApiKeyLabel,
              ),
            ]),
            _section(context, l10n.subtitlesSection, [
              _dropdown<String>(
                context,
                l10n.defaultSubtitleLanguage,
                settings.subtitleLanguage,
                _languages,
                (v) => v.toUpperCase(),
                (v) => ref
                    .read(settingsProvider.notifier)
                    .setSubtitleLanguage(v),
              ),
              ListTile(
                title: Text(l10n.subtitleFontSize),
                subtitle: Slider(
                  value: settings.subtitleFontSize,
                  min: 12,
                  max: 32,
                  divisions: 10,
                  label: settings.subtitleFontSize.round().toString(),
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .setSubtitleFontSize(v),
                ),
              ),
              _ApiKeyField(
                storageKey: SecureStore.openSubtitlesApiKey,
                label: l10n.openSubtitlesApiKeyLabel,
              ),
            ]),
            _section(context, l10n.appearanceSection, [
              ListTile(
                title: Text(l10n.themeLabel),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SegmentedButton<FluxThemeMode>(
                    segments: [
                      ButtonSegment(
                          value: FluxThemeMode.dark,
                          label: Text(l10n.themeDark)),
                      ButtonSegment(
                          value: FluxThemeMode.amoled,
                          label: Text(l10n.themeAmoled)),
                      ButtonSegment(
                          value: FluxThemeMode.light,
                          label: Text(l10n.themeLight)),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (selection) => ref
                        .read(settingsProvider.notifier)
                        .setThemeMode(selection.first),
                  ),
                ),
              ),
              ListTile(
                title: Text(l10n.accentLabel),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final accent in FluxAccent.values)
                        ChoiceChip(
                          avatar: CircleAvatar(
                              backgroundColor: FluxTheme.accentColor(accent)),
                          label: Text(_accentLabel(l10n, accent)),
                          selected: settings.accent == accent,
                          onSelected: (selected) {
                            if (selected) {
                              ref
                                  .read(settingsProvider.notifier)
                                  .setAccent(accent);
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ]),
            _section(context, l10n.aboutSection, [
              ListTile(
                leading: const Icon(LucideIcons.info),
                title: Text('${l10n.appName} \u00b7 ${l10n.studioName}'),
                subtitle: Text('${l10n.appVersionLabel} 0.1.0'),
              ),
              ListTile(
                leading: const Icon(LucideIcons.scale),
                title: Text(l10n.licensesLabel),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: l10n.appName,
                ),
              ),
              ListTile(
                leading: const Icon(LucideIcons.trash2),
                title: Text(l10n.clearWatchHistory),
                onTap: () => _confirmClearHistory(context, ref),
              ),
              ListTile(
                leading: const Icon(LucideIcons.databaseZap),
                title: Text(l10n.clearLibraryCache),
                onTap: () => _clearLibraryCache(context, ref),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  String _accentLabel(AppLocalizations l10n, FluxAccent accent) =>
      switch (accent) {
        FluxAccent.indigo => l10n.accentIndigo,
        FluxAccent.amber => l10n.accentAmber,
        FluxAccent.teal => l10n.accentTeal,
        FluxAccent.rose => l10n.accentRose,
        FluxAccent.emerald => l10n.accentEmerald,
      };

  Future<void> _confirmClearHistory(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.clearWatchHistory),
        content: Text(l10n.clearWatchHistoryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(databaseProvider).historyDao.clearAll();
    }
  }

  /// Clears TMDb metadata only; never deletes files or library entries.
  Future<void> _clearLibraryCache(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final db = ref.read(databaseProvider);
    await db.update(db.mediaItems).write(const MediaItemsCompanion(
          tmdbId: Value(null),
          showTmdbId: Value(null),
          posterPath: Value(null),
        ));
    messenger.showSnackBar(SnackBar(content: Text(l10n.clearLibraryCacheDone)));
  }

  Widget _section(BuildContext context, String title, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child:
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            GlassCard(child: Column(children: children)),
          ],
        ),
      );

  Widget _dropdown<T>(
    BuildContext context,
    String title,
    T value,
    List<T> options,
    String Function(T) label,
    void Function(T) onChanged,
  ) =>
      ListTile(
        title: Text(title),
        trailing: DropdownButton<T>(
          value: value,
          underline: const SizedBox.shrink(),
          items: [
            for (final option in options)
              DropdownMenuItem(value: option, child: Text(label(option))),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      );
}

class _FolderList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final folders = ref.watch(libraryFoldersProvider);
    final db = ref.read(databaseProvider);
    return folders.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => ListTile(title: Text(l10n.errorGeneric)),
      data: (list) => Column(
        children: [
          ListTile(
            leading: const Icon(LucideIcons.folder),
            title: Text(l10n.manageFolders),
          ),
          for (final folder in list)
            ListTile(
              dense: true,
              title: Text(folder.path,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(LucideIcons.x, size: 16),
                onPressed: () => (db.delete(db.libraryFolders)
                      ..where((t) => t.id.equals(folder.id)))
                    .go(),
              ),
            ),
        ],
      ),
    );
  }
}

class _ApiKeyField extends ConsumerStatefulWidget {
  const _ApiKeyField({required this.storageKey, required this.label});

  final String storageKey;
  final String label;

  @override
  ConsumerState<_ApiKeyField> createState() => _ApiKeyFieldState();
}

class _ApiKeyFieldState extends ConsumerState<_ApiKeyField> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value =
        await ref.read(secureStoreProvider).read(widget.storageKey);
    if (mounted && value != null) {
      setState(() => _controller.text = value);
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(secureStoreProvider)
        .write(widget.storageKey, _controller.text.trim());
    messenger.showSnackBar(SnackBar(content: Text(l10n.apiKeySaved)));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      title: TextField(
        controller: _controller,
        obscureText: true,
        decoration: InputDecoration(labelText: widget.label),
      ),
      trailing: IconButton(
        icon: const Icon(LucideIcons.save),
        tooltip: l10n.save,
        onPressed: _save,
      ),
    );
  }
}
