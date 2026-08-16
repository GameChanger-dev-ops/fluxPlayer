import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/services/providers.dart';
import '../../core/services/subtitle_service.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../l10n/generated/app_localizations.dart';

typedef SubtitleQuery = ({
  int tmdbId,
  String language,
  int? seasonNumber,
  int? episodeNumber,
});

final subtitleSearchProvider = FutureProvider.autoDispose
    .family<List<SubtitleSearchResult>, SubtitleQuery>(
        (ref, query) => ref.watch(subtitleServiceProvider).search(
              tmdbId: query.tmdbId,
              language: query.language,
              seasonNumber: query.seasonNumber,
              episodeNumber: query.episodeNumber,
            ));

/// Bottom sheet listing OpenSubtitles results sorted by download count.
class SubtitleSearchSheet extends ConsumerWidget {
  const SubtitleSearchSheet({super.key, required this.query});

  final SubtitleQuery query;

  static Future<SubtitleSearchResult?> show(
      BuildContext context, SubtitleQuery query) {
    return showModalBottomSheet<SubtitleSearchResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SubtitleSearchSheet(query: query),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final results = ref.watch(subtitleSearchProvider(query));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: results.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error is SubtitleException
                          ? error.message
                          : l10n.errorGeneric,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () =>
                          ref.invalidate(subtitleSearchProvider(query)),
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
              data: (list) => list.isEmpty
                  ? Center(child: Text(l10n.noSubtitlesFound))
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: FluxColors.glass),
                      itemBuilder: (context, index) {
                        final result = list[index];
                        return ListTile(
                          leading: const Icon(LucideIcons.captions),
                          title: Text(
                            result.releaseName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            [
                              result.language.toUpperCase(),
                              if (result.uploader != null) result.uploader!,
                              if (result.uploadDate != null)
                                result.uploadDate!.split('T').first,
                              l10n.downloadsCount(result.downloadCount),
                            ].join(' \u00b7 '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          trailing: result.hearingImpaired
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: FluxColors.glass,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(l10n.sdhLabel,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall),
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(result),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
