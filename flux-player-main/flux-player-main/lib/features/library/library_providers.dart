import 'dart:async';

import 'package:drift/drift.dart' show InsertMode;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/services/library_scanner.dart';
import '../../core/services/providers.dart';

final libraryItemsProvider = StreamProvider<List<MediaItem>>(
    (ref) => ref.watch(databaseProvider).mediaDao.watchAll());

final continueWatchingProvider =
    FutureProvider<List<(MediaItem, WatchHistoryEntry)>>(
        (ref) => ref.watch(databaseProvider).historyDao.continueWatching());

class ScanNotifier extends AsyncNotifier<ScanReport?> {
  @override
  FutureOr<ScanReport?> build() => null;

  Future<void> scanAll() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(libraryScannerProvider).scanAll());
    ref.invalidate(continueWatchingProvider);
  }

  Future<void> addFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;
    final db = ref.read(databaseProvider);
    await db.into(db.libraryFolders).insert(
          LibraryFoldersCompanion.insert(path: path),
          mode: InsertMode.insertOrIgnore,
        );
    await scanAll();
  }
}

final scanProvider =
    AsyncNotifierProvider<ScanNotifier, ScanReport?>(ScanNotifier.new);
