import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database.dart';
import '../logging/flux_logger.dart';
import 'secure_store.dart';

class SubtitleException implements Exception {
  const SubtitleException(this.message);

  final String message;

  @override
  String toString() => 'SubtitleException: $message';
}

class SubtitleSearchResult {
  const SubtitleSearchResult({
    required this.fileId,
    required this.language,
    required this.releaseName,
    this.uploader,
    this.uploadDate,
    this.downloadCount = 0,
    this.hearingImpaired = false,
  });

  factory SubtitleSearchResult.fromJson(Map<String, dynamic> json) {
    final attrs = (json['attributes'] ?? const <String, dynamic>{})
        as Map<String, dynamic>;
    final files = (attrs['files'] as List?) ?? const [];
    final fileId = files.isEmpty
        ? 0
        : ((files.first as Map<String, dynamic>)['file_id'] ?? 0) as int;
    return SubtitleSearchResult(
      fileId: fileId,
      language: (attrs['language'] ?? '') as String,
      releaseName: (attrs['release'] ?? '') as String,
      uploader:
          ((attrs['uploader'] as Map<String, dynamic>?)?['name']) as String?,
      uploadDate: attrs['upload_date'] as String?,
      downloadCount: (attrs['download_count'] ?? 0) as int,
      hearingImpaired: (attrs['hearing_impaired'] ?? false) as bool,
    );
  }

  final int fileId;
  final String language;
  final String releaseName;
  final String? uploader;
  final String? uploadDate;
  final int downloadCount;
  final bool hearingImpaired;
}

/// OpenSubtitles REST API v1 client plus local subtitle discovery.
/// HARD RULE: never crashes on timeout; API key only in SecureStore.
class SubtitleService {
  SubtitleService({
    required Dio dio,
    required SecureStore store,
    required FluxDatabase db,
  })  : _dio = dio,
        _store = store,
        _db = db;

  final Dio _dio;
  final SecureStore _store;
  final FluxDatabase _db;

  static const baseUrl = 'https://api.opensubtitles.com/api/v1';
  static const _userAgent = 'Flux Player v0.1.0';
  static const externalExtensions = {'.srt', '.ass', '.vtt', '.sub'};

  /// Same-directory subtitle files with an identical base name.
  /// FileSystemException-safe.
  List<String> findExternalSubtitles(String videoPath) {
    try {
      final dir = Directory(p.dirname(videoPath));
      if (!dir.existsSync()) return const [];
      final base = p.basenameWithoutExtension(videoPath).toLowerCase();
      return dir
          .listSync(followLinks: false)
          .whereType<File>()
          .where((f) {
            final ext = p.extension(f.path).toLowerCase();
            return externalExtensions.contains(ext) &&
                p.basenameWithoutExtension(f.path).toLowerCase() == base;
          })
          .map((f) => f.path)
          .toList();
    } on FileSystemException catch (e) {
      FluxLogger.instance.w('External subtitle scan failed for $videoPath', e);
      return const [];
    }
  }

  /// Search subtitles by TMDb ID with a 24h cache per (tmdbId, language).
  Future<List<SubtitleSearchResult>> search({
    required int tmdbId,
    String language = 'en',
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    final cached = await _readCache(tmdbId, language);
    if (cached != null) return cached;

    final key = await _store.read(SecureStore.openSubtitlesApiKey);
    if (key == null || key.isEmpty) {
      throw const SubtitleException('OpenSubtitles API key is not configured');
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$baseUrl/subtitles',
        queryParameters: {
          'tmdb_id': tmdbId,
          'languages': language,
          if (seasonNumber != null) 'season_number': seasonNumber,
          if (episodeNumber != null) 'episode_number': episodeNumber,
        },
        options: Options(headers: {'Api-Key': key, 'User-Agent': _userAgent}),
      );
      final data = (response.data?['data'] as List?) ?? const [];
      await _writeCache(tmdbId, language, jsonEncode(data));
      return _parse(data);
    } on DioException catch (e) {
      FluxLogger.instance.w('Subtitle search failed for tmdb:$tmdbId', e);
      throw SubtitleException(e.message ?? 'Subtitle search failed');
    }
  }

  /// Downloads a subtitle to the temp directory and returns its path.
  Future<String> download(SubtitleSearchResult result) async {
    final key = await _store.read(SecureStore.openSubtitlesApiKey);
    if (key == null || key.isEmpty) {
      throw const SubtitleException('OpenSubtitles API key is not configured');
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/download',
        data: {'file_id': result.fileId},
        options: Options(headers: {'Api-Key': key, 'User-Agent': _userAgent}),
      );
      final link = response.data?['link'] as String?;
      final fileName = (response.data?['file_name'] as String?) ??
          'subtitle_${result.fileId}.srt';
      if (link == null) {
        throw const SubtitleException('Download link missing');
      }
      final tempDir = await getTemporaryDirectory();
      final target = p.join(tempDir.path, fileName);
      await _dio.download(link, target);
      return target;
    } on DioException catch (e) {
      FluxLogger.instance.w('Subtitle download failed', e);
      throw SubtitleException(e.message ?? 'Subtitle download failed');
    }
  }

  /// Copies a downloaded subtitle next to the video file. Returns the new
  /// path, or null when the copy failed (never throws).
  Future<String?> saveNextToVideo(String subtitlePath, String videoPath) async {
    try {
      final target = p.join(
        p.dirname(videoPath),
        '${p.basenameWithoutExtension(videoPath)}${p.extension(subtitlePath)}',
      );
      await File(subtitlePath).copy(target);
      return target;
    } on FileSystemException catch (e) {
      FluxLogger.instance.w('Could not save subtitle next to video', e);
      return null;
    }
  }

  List<SubtitleSearchResult> _parse(List<dynamic> data) {
    final results = data
        .map((e) => SubtitleSearchResult.fromJson(e as Map<String, dynamic>))
        .where((r) => r.fileId != 0)
        .toList()
      ..sort((a, b) => b.downloadCount.compareTo(a.downloadCount));
    return results;
  }

  Future<List<SubtitleSearchResult>?> _readCache(
      int tmdbId, String language) async {
    final row = await (_db.select(_db.subtitleSearchCache)
          ..where((t) => t.tmdbId.equals(tmdbId) & t.language.equals(language))
          ..orderBy([(t) => OrderingTerm.desc(t.fetchedAt)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    if (DateTime.now().difference(row.fetchedAt) >
        const Duration(hours: 24)) {
      return null;
    }
    try {
      return _parse(jsonDecode(row.payload) as List<dynamic>);
    } on FormatException {
      return null;
    }
  }

  Future<void> _writeCache(int tmdbId, String language, String payload) async {
    await (_db.delete(_db.subtitleSearchCache)
          ..where((t) => t.tmdbId.equals(tmdbId) & t.language.equals(language)))
        .go();
    await _db.into(_db.subtitleSearchCache).insert(
          SubtitleSearchCacheCompanion.insert(
            tmdbId: tmdbId,
            language: language,
            payload: payload,
          ),
        );
  }
}
