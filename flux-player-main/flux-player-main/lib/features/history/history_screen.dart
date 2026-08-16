import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/database/database.dart';
import '../../core/services/tmdb_service.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../l10n/generated/app_localizations.dart';
import '../player/player_screen.dart';

final historyEntriesProvider =
    StreamProvider<List<(MediaItem, WatchHistoryEntry)>>(
        (ref) => ref.watch(databaseProvider).historyDao.watchAllWithMedia());

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  static const route = '/history';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final entries = ref.watch(historyEntriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTitle)),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.errorGeneric),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(historyEntriesProvider),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
        data: (list) => list.isEmpty
            ? Center(
                child: GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.historyEmpty),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final (item, entry) = list[index];
                  return _HistoryCard(item: item, entry: entry);
                },
              ),
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.item, required this.entry});

  final MediaItem item;
  final WatchHistoryEntry entry;

  void _play(BuildContext context) {
    context.push(Uri(
      path: PlayerScreen.route,
      queryParameters: {'path': item.filePath},
    ).toString());
  }

  void _showContextMenu(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dao = ref.read(databaseProvider).historyDao;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.trash2),
                  title: Text(l10n.removeFromHistory),
                  onTap: () {
                    dao.removeEntry(item.id);
                    Navigator.of(sheetContext).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.check),
                  title: Text(l10n.markWatched),
                  onTap: () {
                    dao.setWatched(item.id, watched: true);
                    Navigator.of(sheetContext).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.eyeOff),
                  title: Text(l10n.markUnwatched),
                  onTap: () {
                    dao.setWatched(item.id, watched: false);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final progress =
        entry.durationMs > 0 ? entry.positionMs / entry.durationMs : 0.0;
    final days = DateTime.now().difference(entry.lastWatchedAt).inDays;
    final episodeInfo = item.seasonNumber != null && item.episodeNumber != null
        ? 'S${item.seasonNumber}E${item.episodeNumber}'
        : null;

    return GestureDetector(
      onTap: () => _play(context),
      onLongPress: () => _showContextMenu(context, ref),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 84,
                child: item.posterPath != null
                    ? CachedNetworkImage(
                        imageUrl: '${TmdbService.imageBase}${item.posterPath}',
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 300),
                      )
                    : Container(
                        color: FluxColors.surfaceElevated,
                        child: const Icon(LucideIcons.film,
                            color: FluxColors.textMuted),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (episodeInfo != null)
                    Text(episodeInfo, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: FluxColors.glass,
                      color: entry.watched
                          ? FluxColors.success
                          : FluxColors.indigo,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.daysAgo(days),
                      style: theme.textTheme.labelSmall),
                ],
              ),
            ),
            if (entry.watched)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child:
                    Icon(LucideIcons.check, color: FluxColors.success, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
