import 'package:flutter_test/flutter_test.dart';
import 'package:flux_player/core/database/database.dart';
import 'package:flux_player/features/organizer/organizer_service.dart';

MediaItem item({
  required int id,
  required String title,
  String mediaType = 'movie',
  int? year,
  int? season,
  int? episode,
  String? resolution,
  DateTime? addedAt,
}) =>
    MediaItem(
      id: id,
      filePath: '/media/$id.mkv',
      title: title,
      mediaType: mediaType,
      year: year,
      seasonNumber: season,
      episodeNumber: episode,
      resolutionTag: resolution,
      fileMissing: false,
      addedAt: addedAt ?? DateTime(2026, 1, id),
    );

void main() {
  final organizer = OrganizerService();

  test('sorts by title case-insensitively', () {
    final sorted = organizer.sort(
      [item(id: 1, title: 'zeta'), item(id: 2, title: 'Alpha')],
      OrganizeMode.byTitle,
    );
    expect(sorted.first.title, 'Alpha');
  });

  test('sorts by year descending', () {
    final sorted = organizer.sort(
      [item(id: 1, title: 'Old', year: 1999), item(id: 2, title: 'New', year: 2024)],
      OrganizeMode.byYear,
    );
    expect(sorted.first.title, 'New');
  });

  test('sorts by resolution rank 4K > HDR > 1080p', () {
    final sorted = organizer.sort(
      [
        item(id: 1, title: 'A', resolution: '1080p'),
        item(id: 2, title: 'B', resolution: '4K'),
        item(id: 3, title: 'C', resolution: 'HDR'),
        item(id: 4, title: 'D'),
      ],
      OrganizeMode.byResolution,
    );
    expect(sorted.map((i) => i.title).toList(), ['B', 'C', 'A', 'D']);
  });

  test('sorts by show, season, then episode', () {
    final sorted = organizer.sort(
      [
        item(id: 1, title: 'Show', mediaType: 'episode', season: 2, episode: 1),
        item(id: 2, title: 'Show', mediaType: 'episode', season: 1, episode: 2),
        item(id: 3, title: 'Show', mediaType: 'episode', season: 1, episode: 1),
      ],
      OrganizeMode.byShow,
    );
    expect(sorted.map((i) => 'S${i.seasonNumber}E${i.episodeNumber}').toList(),
        ['S1E1', 'S1E2', 'S2E1']);
  });

  test('sorts recently added newest first', () {
    final sorted = organizer.sort(
      [
        item(id: 1, title: 'Older', addedAt: DateTime(2026, 1, 1)),
        item(id: 2, title: 'Newer', addedAt: DateTime(2026, 2, 1)),
      ],
      OrganizeMode.recentlyAdded,
    );
    expect(sorted.first.title, 'Newer');
  });

  test('gap analyzer finds missing episodes within a season', () {
    final gaps = organizer.findGaps([
      item(id: 1, title: 'Show', mediaType: 'episode', season: 1, episode: 1),
      item(id: 2, title: 'Show', mediaType: 'episode', season: 1, episode: 3),
      item(id: 3, title: 'Show', mediaType: 'episode', season: 1, episode: 5),
    ]);
    expect(gaps, hasLength(1));
    expect(gaps.single.seasonNumber, 1);
    expect(gaps.single.missingEpisodes, [2, 4]);
  });

  test('gap analyzer reports nothing for complete seasons', () {
    final gaps = organizer.findGaps([
      item(id: 1, title: 'Show', mediaType: 'episode', season: 1, episode: 1),
      item(id: 2, title: 'Show', mediaType: 'episode', season: 1, episode: 2),
    ]);
    expect(gaps, isEmpty);
  });

  test('groups by resolution with SD fallback', () {
    final groups = organizer.group(
      [
        item(id: 1, title: 'A', resolution: '4K'),
        item(id: 2, title: 'B'),
      ],
      OrganizeMode.byResolution,
    );
    expect(groups.keys, containsAll(['4K', 'SD']));
  });
}
