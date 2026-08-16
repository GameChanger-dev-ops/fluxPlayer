import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/details/details_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/player/player_screen.dart';
import '../../features/settings/settings_screen.dart';

/// All page transitions: SharedAxis horizontal, 280ms (design rule).
CustomTransitionPage<T> _sharedAxisPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: SharedAxisTransitionType.horizontal,
        fillColor: Colors.transparent,
        child: child,
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: LibraryScreen.route,
    routes: [
      GoRoute(
        path: LibraryScreen.route,
        name: 'library',
        pageBuilder: (context, state) => _sharedAxisPage(
            key: state.pageKey, child: const LibraryScreen()),
      ),
      GoRoute(
        path: PlayerScreen.route,
        name: 'player',
        pageBuilder: (context, state) => _sharedAxisPage(
          key: state.pageKey,
          child: PlayerScreen(filePath: state.uri.queryParameters['path']),
        ),
      ),
      GoRoute(
        path: '${DetailsScreen.route}/:type/:id',
        name: 'details',
        pageBuilder: (context, state) => _sharedAxisPage(
          key: state.pageKey,
          child: DetailsScreen(
            mediaType: state.pathParameters['type'] ?? 'movie',
            tmdbId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          ),
        ),
      ),
      GoRoute(
        path: HistoryScreen.route,
        name: 'history',
        pageBuilder: (context, state) => _sharedAxisPage(
            key: state.pageKey, child: const HistoryScreen()),
      ),
      GoRoute(
        path: SettingsScreen.route,
        name: 'settings',
        pageBuilder: (context, state) => _sharedAxisPage(
            key: state.pageKey, child: const SettingsScreen()),
      ),
    ],
  );
});
