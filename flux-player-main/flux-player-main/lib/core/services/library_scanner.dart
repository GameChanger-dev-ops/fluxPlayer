import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../database/database.dart';
import '../logging/flux_logger.dart';
import 'matcher_service.dart';
import 'tmdb_service.dart';

class ScanReport {
  ScanReport({this.scanned = 0, this.added = 0, this.missing = 0});

  int scanned;
  int added;
  int missing;
  final List<String> errors = [];
}

/// Scans library source folders for video files, indexes them into Drift and
/// flags items whose backing file disappeared.
/// HARD RULE: never crashes on FileSystemException.
class LibraryScanner {
  LibraryScanner({required this.db, required this.matcher, this.tmdb});

  final FluxDatabase db;
  final MatcherService matcher;
  final TmdbService? tmdb;

  static const videoExtensions = {
    '.mp4',
    '.mkv',
    '.avi',
    '.mov',
    '.webm',
    '.m4v',
    '.wmv',
    '.ts',
    '.flv',
  };

  Future<ScanReport> scanAll() async {
    final report = ScanReport();
    final folders = await db.select(db.libraryFolders).get();
    for (final folder in folders) {
      await scanFolder(folder.path, report);
    }
    await _flagMissingFiles(report);
    return report;
  }

  Future<void> scanFolder(String folderPath, ScanReport report) async {
    final dir = Directory(folderPath);
    try {
      if (!await dir.exists()) {
        report.errors.add('Folder not found: $folderPath');
        return;
      }
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final ext = p.extension(entity.path).toLowerCase();
        if (!videoExtensions.contains(ext)) continue;
        report.scanned++;
        await _indexFile(entity.path, report);
      }
    } on FileSystemException catch (e) {
      FluxLogger.instance.w('Scan failed for $folderPath', e);
      report.errors.add('Could not read $folderPath');
    }
  }

  Future<void> _indexFile(String path, ScanReport report) async {
    final existing = await db.mediaDao.byFilePath(path);
    if (existing != null) {
      if (existing.fileMissing) {
        await db.mediaDao.markMissing(path, missing: false);
      }
      return;
    }
    final match = matcher.parse(p.basename(path));
    var companion = MediaItemsCompanion.insert(
      filePath: path,
      title: match.title,
      mediaType: match.isEpisode ? 'episode' : 'movie',
      seasonNumber: Value(match.seasonNumber),
      episodeNumber: Value(match.episodeNumber),
      year: Value(match.year),
      resolutionTag: Value(match.resolutionTag),
    );
    companion = await _enrich(companion, match);
    await db.mediaDao.upsert(companion);
    report.added++;
  }

  /// Best-effort TMDb enrichment; skipped when no API key is configured and
  /// never fatal to a scan.
  Future<MediaItemsCompanion> _enrich(
      MediaItemsCompanion companion, MatchResult match) async {
    final service = tmdb;
    if (service == null || !await service.hasApiKey()) return companion;
    try {
      final results = match.isEpisode
          ? await service.searchTv(match.title)
          : await service.searchMovie(match.title, year: match.year);
      if (results.isEmpty) return companion;
      final best = results.first;
      return companion.copyWith(
        tmdbId: Value(match.isEpisode ? null : best.id),
        showTmdbId: Value(match.isEpisode ? best.id : null),
        posterPath: Value(best.posterPath),
        year: Value(match.year ?? best.year),
      );
    } on TmdbException catch (e) {
      FluxLogger.instance.w('Metadata enrichment skipped: ${e.message}');
      return companion;
    }
  }

  Future<void> _flagMissingFiles(ScanReport report) async {
    final items = await db.select(db.mediaItems).get();
    for (final item in items) {
      try {
        final exists = File(item.filePath).existsSync();
        if (!exists && !item.fileMissing) {
          await db.mediaDao.markMissing(item.filePath, missing: true);
          report.missing++;
        } else if (exists && item.fileMissing) {
          await db.mediaDao.markMissing(item.filePath, missing: false);
        }
      } on FileSystemException catch (e) {
        FluxLogger.instance
            .w('Missing-file check failed for ${item.filePath}', e);
      }
    }
  }
}
