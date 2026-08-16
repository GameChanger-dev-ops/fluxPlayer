import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'database.g.dart';

class LibraryFolders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text().unique()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
}

class MediaItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get filePath => text().unique()();
  TextColumn get title => text()();
  /// 'movie' | 'episode'
  TextColumn get mediaType => text()();
  IntColumn get tmdbId => integer().nullable()();
  IntColumn get showTmdbId => integer().nullable()();
  IntColumn get seasonNumber => integer().nullable()();
  IntColumn get episodeNumber => integer().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get posterPath => text().nullable()();
  /// '4K' | 'HDR' | '1080p' derived from filename tags.
  TextColumn get resolutionTag => text().nullable()();
  BoolColumn get fileMissing => boolean().withDefault(const Constant(false))();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
}

class WatchHistoryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mediaItemId =>
      integer().references(MediaItems, #id).unique()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  BoolColumn get watched => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastWatchedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class AppPreferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class SubtitleSearchCache extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tmdbId => integer()();
  TextColumn get language => text()();
  /// Raw JSON payload of the OpenSubtitles search response.
  TextColumn get payload => text()();
  DateTimeColumn get fetchedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftAccessor(tables: [MediaItems])
class MediaDao extends DatabaseAccessor<FluxDatabase> with _$MediaDaoMixin {
  MediaDao(super.db);

  Stream<List<MediaItem>> watchAll() => select(mediaItems).watch();

  Future<MediaItem?> byFilePath(String path) =>
      (select(mediaItems)..where((t) => t.filePath.equals(path)))
          .getSingleOrNull();

  Future<int> upsert(MediaItemsCompanion item) =>
      into(mediaItems).insertOnConflictUpdate(item);

  /// Never crash when a file disappears from disk: flag it instead.
  Future<void> markMissing(String path, {required bool missing}) =>
      (update(mediaItems)..where((t) => t.filePath.equals(path)))
          .write(MediaItemsCompanion(fileMissing: Value(missing)));
}

@DriftAccessor(tables: [WatchHistoryEntries, MediaItems])
class HistoryDao extends DatabaseAccessor<FluxDatabase>
    with _$HistoryDaoMixin {
  HistoryDao(super.db);

  /// Called by the playback position writer (debounced to every 10s upstream).
  Future<void> savePosition({
    required int mediaItemId,
    required int positionMs,
    required int durationMs,
  }) =>
      into(watchHistoryEntries).insertOnConflictUpdate(
        WatchHistoryEntriesCompanion.insert(
          mediaItemId: mediaItemId,
          positionMs: Value(positionMs),
          durationMs: Value(durationMs),
          lastWatchedAt: Value(DateTime.now()),
        ),
      );

  Future<WatchHistoryEntry?> entryFor(int mediaItemId) =>
      (select(watchHistoryEntries)
            ..where((t) => t.mediaItemId.equals(mediaItemId)))
          .getSingleOrNull();

  Future<void> setWatched(int mediaItemId, {required bool watched}) =>
      (update(watchHistoryEntries)
            ..where((t) => t.mediaItemId.equals(mediaItemId)))
          .write(WatchHistoryEntriesCompanion(watched: Value(watched)));

  Future<void> removeEntry(int mediaItemId) =>
      (delete(watchHistoryEntries)
            ..where((t) => t.mediaItemId.equals(mediaItemId)))
          .go();

  Future<void> clearAll() => delete(watchHistoryEntries).go();

  /// Full history, newest first, joined with media metadata.
  Stream<List<(MediaItem, WatchHistoryEntry)>> watchAllWithMedia() {
    final query = select(watchHistoryEntries).join([
      innerJoin(mediaItems,
          mediaItems.id.equalsExp(watchHistoryEntries.mediaItemId)),
    ])
      ..orderBy([OrderingTerm.desc(watchHistoryEntries.lastWatchedAt)]);
    return query.watch().map((rows) => rows
        .map((r) => (r.readTable(mediaItems), r.readTable(watchHistoryEntries)))
        .toList());
  }

  /// Continue Watching shelf: position 5%-90%, newest first, max [limit].
  Future<List<(MediaItem, WatchHistoryEntry)>> continueWatching(
      {int limit = 10}) async {
    final query = select(watchHistoryEntries).join([
      innerJoin(
          mediaItems, mediaItems.id.equalsExp(watchHistoryEntries.mediaItemId)),
    ])
      ..where(watchHistoryEntries.watched.equals(false) &
          watchHistoryEntries.durationMs.isBiggerThanValue(0))
      ..orderBy([OrderingTerm.desc(watchHistoryEntries.lastWatchedAt)]);
    final rows = await query.get();
    return rows
        .map((r) =>
            (r.readTable(mediaItems), r.readTable(watchHistoryEntries)))
        .where((pair) {
          final fraction = pair.$2.positionMs / pair.$2.durationMs;
          return fraction >= 0.05 && fraction <= 0.90;
        })
        .take(limit)
        .toList();
  }
}

@DriftAccessor(tables: [AppPreferences])
class PreferencesDao extends DatabaseAccessor<FluxDatabase>
    with _$PreferencesDaoMixin {
  PreferencesDao(super.db);

  Future<String?> getValue(String key) async {
    final row = await (select(appPreferences)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setValue(String key, String value) =>
      into(appPreferences).insertOnConflictUpdate(
          AppPreferencesCompanion.insert(key: key, value: value));
}

@DriftDatabase(
  tables: [
    LibraryFolders,
    MediaItems,
    WatchHistoryEntries,
    AppPreferences,
    SubtitleSearchCache,
  ],
  daos: [MediaDao, HistoryDao, PreferencesDao],
)
class FluxDatabase extends _$FluxDatabase {
  FluxDatabase() : super(driftDatabase(name: 'flux_player'));

  FluxDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  /// HARD RULE: all future schema changes go through migrations here;
  /// never modify existing table columns in place.
  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());
}

final databaseProvider = Provider<FluxDatabase>((ref) {
  final db = FluxDatabase();
  ref.onDispose(db.close);
  return db;
});
