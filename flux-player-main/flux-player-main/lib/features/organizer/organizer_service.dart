import '../../core/database/database.dart';

/// The five organization modes for the library.
enum OrganizeMode { recentlyAdded, byTitle, byYear, byShow, byResolution }

class EpisodeGap {
  const EpisodeGap({
    required this.showTitle,
    required this.seasonNumber,
    required this.missingEpisodes,
  });

  final String showTitle;
  final int seasonNumber;
  final List<int> missingEpisodes;
}

/// Pure business logic for sorting, grouping and gap analysis.
class OrganizerService {
  static const _resolutionRank = {'4K': 0, 'HDR': 1, '1080p': 2, '720p': 3};

  List<MediaItem> sort(List<MediaItem> items, OrganizeMode mode) {
    final sorted = [...items];
    switch (mode) {
      case OrganizeMode.recentlyAdded:
        sorted.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case OrganizeMode.byTitle:
        sorted.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case OrganizeMode.byYear:
        sorted.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
      case OrganizeMode.byShow:
        sorted.sort((a, b) {
          final byTitle =
              a.title.toLowerCase().compareTo(b.title.toLowerCase());
          if (byTitle != 0) return byTitle;
          final bySeason =
              (a.seasonNumber ?? 0).compareTo(b.seasonNumber ?? 0);
          if (bySeason != 0) return bySeason;
          return (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0);
        });
      case OrganizeMode.byResolution:
        sorted.sort((a, b) => (_resolutionRank[a.resolutionTag] ?? 4)
            .compareTo(_resolutionRank[b.resolutionTag] ?? 4));
    }
    return sorted;
  }

  /// Groups items for shelf-style rendering, keyed by mode-specific labels.
  Map<String, List<MediaItem>> group(
      List<MediaItem> items, OrganizeMode mode) {
    final groups = <String, List<MediaItem>>{};
    for (final item in sort(items, mode)) {
      final key = switch (mode) {
        OrganizeMode.byShow => item.title,
        OrganizeMode.byYear => '${item.year ?? 0}',
        OrganizeMode.byResolution => item.resolutionTag ?? 'SD',
        _ => '',
      };
      groups.putIfAbsent(key, () => []).add(item);
    }
    return groups;
  }

  /// Gap analyzer: reports missing episode numbers per show and season,
  /// from episode 1 up to the highest episode on disk.
  List<EpisodeGap> findGaps(List<MediaItem> items) {
    final byShowSeason = <String, List<MediaItem>>{};
    for (final item in items) {
      if (item.mediaType != 'episode' ||
          item.seasonNumber == null ||
          item.episodeNumber == null) {
        continue;
      }
      byShowSeason
          .putIfAbsent(
              '${item.title.toLowerCase()}|s${item.seasonNumber}', () => [])
          .add(item);
    }
    final gaps = <EpisodeGap>[];
    for (final episodes in byShowSeason.values) {
      final have = episodes.map((e) => e.episodeNumber!).toSet();
      final highest = have.reduce((a, b) => a > b ? a : b);
      final missing = [
        for (var n = 1; n <= highest; n++)
          if (!have.contains(n)) n,
      ];
      if (missing.isNotEmpty) {
        gaps.add(EpisodeGap(
          showTitle: episodes.first.title,
          seasonNumber: episodes.first.seasonNumber!,
          missingEpisodes: missing,
        ));
      }
    }
    gaps.sort((a, b) => a.showTitle.compareTo(b.showTitle));
    return gaps;
  }
}
