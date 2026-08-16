import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/database/database.dart';
import '../../core/widgets/glass_card.dart';
import '../../l10n/generated/app_localizations.dart';
import '../history/history_screen.dart';
import '../organizer/organizer_providers.dart';
import '../organizer/organizer_service.dart';
import '../player/player_screen.dart';
import '../settings/settings_screen.dart';
import 'library_providers.dart';
import 'widgets/media_card.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  static const route = '/library';

  void _play(BuildContext context, MediaItem item) {
    context.push(Uri(
      path: PlayerScreen.route,
      queryParameters: {'path': item.filePath},
    ).toString());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final items = ref.watch(libraryItemsProvider);
    final scanState = ref.watch(scanProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.libraryTitle,
            style: Theme.of(context).textTheme.headlineMedium),
        actions: [
          PopupMenuButton<OrganizeMode>(
            icon: const Icon(LucideIcons.arrowUpDown),
            tooltip: l10n.sortLabel,
            onSelected: (mode) =>
                ref.read(organizeModeProvider.notifier).state = mode,
            itemBuilder: (context) => [
              PopupMenuItem(
                  value: OrganizeMode.recentlyAdded,
                  child: Text(l10n.sortRecentlyAdded)),
              PopupMenuItem(
                  value: OrganizeMode.byTitle, child: Text(l10n.sortByTitle)),
              PopupMenuItem(
                  value: OrganizeMode.byYear, child: Text(l10n.sortByYear)),
              PopupMenuItem(
                  value: OrganizeMode.byShow, child: Text(l10n.sortByShow)),
              PopupMenuItem(
                  value: OrganizeMode.byResolution,
                  child: Text(l10n.sortByResolution)),
            ],
          ),
          if (scanState.isLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(LucideIcons.refreshCw),
              tooltip: l10n.scanLibrary,
              onPressed: () => ref.read(scanProvider.notifier).scanAll(),
            ),
          IconButton(
            icon: const Icon(LucideIcons.folderPlus),
            tooltip: l10n.addFolder,
            onPressed: () => ref.read(scanProvider.notifier).addFolder(),
          ),
          IconButton(
            icon: const Icon(LucideIcons.history),
            tooltip: l10n.historyTitle,
            onPressed: () => context.push(HistoryScreen.route),
          ),
          IconButton(
            icon: const Icon(LucideIcons.settings),
            tooltip: l10n.settingsTitle,
            onPressed: () => context.push(SettingsScreen.route),
          ),
        ],
      ),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _MessageCard(
          message: l10n.errorGeneric,
          buttonLabel: l10n.retry,
          onPressed: () => ref.invalidate(libraryItemsProvider),
        ),
        data: (list) => list.isEmpty
            ? _MessageCard(
                message: l10n.libraryEmpty,
                hint: l10n.libraryEmptyHint,
                buttonLabel: l10n.addFolder,
                onPressed: () => ref.read(scanProvider.notifier).addFolder(),
              )
            : _LibraryBody(
                items: list,
                onPlay: (item) => _play(context, item),
              ),
      ),
    );
  }
}

class _LibraryBody extends ConsumerWidget {
  const _LibraryBody({required this.items, required this.onPlay});

  final List<MediaItem> items;
  final void Function(MediaItem) onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(organizeModeProvider);
    final sorted = ref.watch(organizerServiceProvider).sort(items, mode);
    final movies = sorted.where((i) => i.mediaType == 'movie').toList();
    final episodes = sorted.where((i) => i.mediaType == 'episode').toList();
    final continueWatching = ref.watch(continueWatchingProvider);

    return CustomScrollView(
      slivers: [
        if (continueWatching.valueOrNull?.isNotEmpty ?? false)
          SliverToBoxAdapter(
            child: _ContinueWatchingShelf(
              entries: continueWatching.value!,
              onPlay: onPlay,
            ),
          ),
        if (movies.isNotEmpty) ...[
          _sectionHeader(context, l10n.moviesSection),
          _grid(movies, 2 / 3),
        ],
        if (episodes.isNotEmpty) ...[
          _sectionHeader(context, l10n.episodesSection),
          _grid(episodes, 16 / 9),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }

  SliverToBoxAdapter _sectionHeader(BuildContext context, String title) =>
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
      );

  SliverPadding _grid(List<MediaItem> list, double aspect) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: aspect < 1 ? 160 : 280,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: aspect,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => MediaCard(
              item: list[index],
              onTap: () => onPlay(list[index]),
            ),
            childCount: list.length,
          ),
        ),
      );
}

class _ContinueWatchingShelf extends StatelessWidget {
  const _ContinueWatchingShelf({required this.entries, required this.onPlay});

  final List<(MediaItem, WatchHistoryEntry)> entries;
  final void Function(MediaItem) onPlay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text(l10n.continueWatching,
              style: Theme.of(context).textTheme.titleLarge),
        ),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: entries.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final (item, entry) = entries[index];
              return SizedBox(
                width: item.mediaType == 'episode' ? 280 : 120,
                child: MediaCard(
                  item: item,
                  progress: entry.durationMs > 0
                      ? entry.positionMs / entry.durationMs
                      : null,
                  onTap: () => onPlay(item),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
    this.hint,
  });

  final String message;
  final String? hint;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: Theme.of(context).textTheme.titleMedium),
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(hint!, style: Theme.of(context).textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}
