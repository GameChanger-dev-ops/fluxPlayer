import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flux_player/core/database/database.dart';
import 'package:flux_player/features/library/widgets/media_card.dart';

MediaItem _item({String? resolution, int? season, int? episode}) => MediaItem(
      id: 1,
      filePath: '/media/test.mkv',
      title: 'Test Movie',
      mediaType: season != null ? 'episode' : 'movie',
      seasonNumber: season,
      episodeNumber: episode,
      resolutionTag: resolution,
      fileMissing: false,
      addedAt: DateTime(2026),
    );

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 160, height: 240, child: child),
        ),
      ),
    );

void main() {
  testWidgets('shows title and resolution badge', (tester) async {
    await tester.pumpWidget(_wrap(MediaCard(item: _item(resolution: '4K'))));

    expect(find.text('Test Movie'), findsOneWidget);
    expect(find.text('4K'), findsOneWidget);
  });

  testWidgets('shows progress bar when in progress', (tester) async {
    await tester.pumpWidget(_wrap(MediaCard(item: _item(), progress: 0.4)));

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('labels episodes with SxEx info', (tester) async {
    await tester.pumpWidget(
        _wrap(MediaCard(item: _item(season: 2, episode: 5))));

    expect(find.textContaining('S2E5'), findsOneWidget);
  });
}
