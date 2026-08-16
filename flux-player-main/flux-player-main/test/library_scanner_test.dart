import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flux_player/core/database/database.dart';
import 'package:flux_player/core/services/library_scanner.dart';
import 'package:flux_player/core/services/matcher_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late FluxDatabase db;
  late Directory tempDir;

  setUp(() async {
    db = FluxDatabase.forTesting(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('flux_scan_test');
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> addFolder(String path) => db
      .into(db.libraryFolders)
      .insert(LibraryFoldersCompanion.insert(path: path));

  test('indexes video files and skips non-video files', () async {
    File(p.join(tempDir.path, 'Interstellar.2014.1080p.mkv'))
        .writeAsStringSync('x');
    File(p.join(tempDir.path, 'notes.txt')).writeAsStringSync('x');
    await addFolder(tempDir.path);

    final scanner = LibraryScanner(db: db, matcher: MatcherService());
    final report = await scanner.scanAll();

    expect(report.added, 1);
    final items = await db.select(db.mediaItems).get();
    expect(items.single.title, 'Interstellar');
    expect(items.single.mediaType, 'movie');
    expect(items.single.resolutionTag, '1080p');
  });

  test('flags items whose files were deleted', () async {
    final file = File(p.join(tempDir.path, 'Show.S01E01.mkv'))
      ..writeAsStringSync('x');
    await addFolder(tempDir.path);
    final scanner = LibraryScanner(db: db, matcher: MatcherService());
    await scanner.scanAll();

    file.deleteSync();
    final report = await scanner.scanAll();

    expect(report.missing, 1);
    final items = await db.select(db.mediaItems).get();
    expect(items.single.fileMissing, true);
  });

  test('reports unreadable folders instead of crashing', () async {
    await addFolder(p.join(tempDir.path, 'does_not_exist'));
    final scanner = LibraryScanner(db: db, matcher: MatcherService());
    final report = await scanner.scanAll();
    expect(report.errors, isNotEmpty);
  });
}
