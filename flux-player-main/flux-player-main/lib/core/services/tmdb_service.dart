import 'package:dio/dio.dart';

import '../logging/flux_logger.dart';
import 'secure_store.dart';

class TmdbException implements Exception {
  const TmdbException(this.message);

  final String message;

  @override
  String toString() => 'TmdbException: $message';
}

class TmdbResult {
  const TmdbResult({
    required this.id,
    required this.title,
    this.posterPath,
    this.year,
    this.voteAverage,
  });

  factory TmdbResult.fromMovieJson(Map<String, dynamic> json) => TmdbResult(
        id: json['id'] as int,
        title: (json['title'] ?? '') as String,
        posterPath: json['poster_path'] as String?,
        year: _yearOf(json['release_date'] as String?),
        voteAverage: (json['vote_average'] as num?)?.toDouble(),
      );

  factory TmdbResult.fromTvJson(Map<String, dynamic> json) => TmdbResult(
        id: json['id'] as int,
        title: (json['name'] ?? '') as String,
        posterPath: json['poster_path'] as String?,
        year: _yearOf(json['first_air_date'] as String?),
        voteAverage: (json['vote_average'] as num?)?.toDouble(),
      );

  final int id;
  final String title;
  final String? posterPath;
  final int? year;
  final double? voteAverage;

  static int? _yearOf(String? date) => (date == null || date.length < 4)
      ? null
      : int.tryParse(date.substring(0, 4));
}

class TmdbEpisode {
  const TmdbEpisode({
    required this.seasonNumber,
    required this.episodeNumber,
    required this.name,
    this.stillPath,
    this.overview,
  });

  factory TmdbEpisode.fromJson(Map<String, dynamic> json) => TmdbEpisode(
        seasonNumber: (json['season_number'] ?? 0) as int,
        episodeNumber: (json['episode_number'] ?? 0) as int,
        name: (json['name'] ?? '') as String,
        stillPath: json['still_path'] as String?,
        overview: json['overview'] as String?,
      );

  final int seasonNumber;
  final int episodeNumber;
  final String name;
  final String? stillPath;
  final String? overview;
}

/// TMDb API v3 client. The API key is read from SecureStore on every call;
/// it is never stored in source code.
class TmdbService {
  TmdbService({required Dio dio, required SecureStore store})
      : _dio = dio,
        _store = store;

  final Dio _dio;
  final SecureStore _store;

  static const baseUrl = 'https://api.themoviedb.org/3';
  static const imageBase = 'https://image.tmdb.org/t/p/w500';

  Future<bool> hasApiKey() async {
    final key = await _store.read(SecureStore.tmdbApiKey);
    return key != null && key.isNotEmpty;
  }

  Future<Map<String, dynamic>> _get(
      String path, Map<String, dynamic> query) async {
    final key = await _store.read(SecureStore.tmdbApiKey);
    if (key == null || key.isEmpty) {
      throw const TmdbException('TMDb API key is not configured');
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$baseUrl$path',
        queryParameters: {...query, 'api_key': key},
      );
      final data = response.data;
      if (data == null) {
        throw const TmdbException('Empty response from TMDb');
      }
      return data;
    } on DioException catch (e) {
      FluxLogger.instance.w('TMDb request failed: $path', e);
      throw TmdbException(e.message ?? 'Network error talking to TMDb');
    }
  }

  Future<List<TmdbResult>> searchMovie(String query,
      {int? year, String language = 'en-US'}) async {
    final data = await _get('/search/movie', {
      'query': query,
      if (year != null) 'year': year,
      'language': language,
    });
    return _results(data, TmdbResult.fromMovieJson);
  }

  Future<List<TmdbResult>> searchTv(String query,
      {String language = 'en-US'}) async {
    final data = await _get('/search/tv', {
      'query': query,
      'language': language,
    });
    return _results(data, TmdbResult.fromTvJson);
  }

  Future<List<TmdbEpisode>> seasonEpisodes(int tvId, int seasonNumber,
      {String language = 'en-US'}) async {
    final data =
        await _get('/tv/$tvId/season/$seasonNumber', {'language': language});
    final episodes = (data['episodes'] as List?) ?? const [];
    return episodes
        .map((e) => TmdbEpisode.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  List<TmdbResult> _results(Map<String, dynamic> data,
      TmdbResult Function(Map<String, dynamic>) fromJson) {
    final results = (data['results'] as List?) ?? const [];
    return results.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }
}
