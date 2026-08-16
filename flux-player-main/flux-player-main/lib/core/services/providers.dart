import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import 'library_scanner.dart';
import 'matcher_service.dart';
import 'secure_store.dart';
import 'subtitle_service.dart';
import 'tmdb_service.dart';

final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));
});

final matcherServiceProvider =
    Provider<MatcherService>((ref) => MatcherService());

final tmdbServiceProvider = Provider<TmdbService>((ref) => TmdbService(
      dio: ref.watch(dioProvider),
      store: ref.watch(secureStoreProvider),
    ));

final libraryScannerProvider =
    Provider<LibraryScanner>((ref) => LibraryScanner(
          db: ref.watch(databaseProvider),
          matcher: ref.watch(matcherServiceProvider),
          tmdb: ref.watch(tmdbServiceProvider),
        ));

final subtitleServiceProvider =
    Provider<SubtitleService>((ref) => SubtitleService(
          dio: ref.watch(dioProvider),
          store: ref.watch(secureStoreProvider),
          db: ref.watch(databaseProvider),
        ));
