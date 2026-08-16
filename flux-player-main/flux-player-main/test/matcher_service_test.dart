import 'package:flutter_test/flutter_test.dart';
import 'package:flux_player/core/services/matcher_service.dart';

void main() {
  final matcher = MatcherService();

  test('parses movie with year and 4K resolution', () {
    final result = matcher.parse('Interstellar.2014.2160p.HDR.BluRay.x265.mkv');
    expect(result.title, 'Interstellar');
    expect(result.year, 2014);
    expect(result.isEpisode, false);
    expect(result.resolutionTag, '4K');
  });

  test('parses SxxExx episodes', () {
    final result = matcher.parse('Severance.S02E05.1080p.WEB-DL.mkv');
    expect(result.title, 'Severance');
    expect(result.seasonNumber, 2);
    expect(result.episodeNumber, 5);
    expect(result.resolutionTag, '1080p');
  });

  test('parses NxNN episode notation', () {
    final result = matcher.parse('The Office 3x12 HDTV.mp4');
    expect(result.title, 'The Office');
    expect(result.seasonNumber, 3);
    expect(result.episodeNumber, 12);
  });

  test('flags HDR when no 4K marker present', () {
    final result = matcher.parse('Dune.Part.Two.2024.HDR.WEBRip.mkv');
    expect(result.resolutionTag, 'HDR');
    expect(result.year, 2024);
  });

  test('falls back to basename when nothing matches', () {
    final result = matcher.parse('home_video.mp4');
    expect(result.title, 'home video');
    expect(result.year, isNull);
    expect(result.isEpisode, false);
  });
}
