import 'package:path/path.dart' as p;

/// Result of parsing a media filename.
class MatchResult {
  const MatchResult({
    required this.title,
    this.year,
    this.seasonNumber,
    this.episodeNumber,
    this.resolutionTag,
  });

  final String title;
  final int? year;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? resolutionTag;

  bool get isEpisode => seasonNumber != null && episodeNumber != null;
}

/// Parses media filenames into structured metadata
/// (title, year, SxxExx, resolution tags).
class MatcherService {
  static final _seasonEpisode =
      RegExp(r's(\d{1,2})[ ._-]*e(\d{1,3})', caseSensitive: false);
  static final _altSeasonEpisode = RegExp(r'\b(\d{1,2})x(\d{2,3})\b');
  static final _year = RegExp(r'\b(19\d{2}|20\d{2})\b');
  static final _fourK = RegExp(r'\b(2160p|4k|uhd)\b', caseSensitive: false);
  static final _hdr =
      RegExp(r'\b(hdr|hdr10|dv|dolby[ .]?vision)\b', caseSensitive: false);
  static final _fullHd = RegExp(r'\b1080p\b', caseSensitive: false);
  static final _hd = RegExp(r'\b720p\b', caseSensitive: false);
  static final _junk = RegExp(
      r'\b(bluray|blu-ray|webrip|web-dl|webdl|hdtv|x264|x265|h264|h265|hevc|aac|ac3|dts|remux|proper|repack|extended|unrated|10bit)\b.*',
      caseSensitive: false);

  MatchResult parse(String fileName) {
    final base = p.basenameWithoutExtension(fileName);
    final normalized = base.replaceAll(RegExp(r'[._]'), ' ');

    final resolution = resolutionTag(normalized);

    int? season;
    int? episode;
    var titleEnd = normalized.length;

    final se = _seasonEpisode.firstMatch(normalized) ??
        _altSeasonEpisode.firstMatch(normalized);
    if (se != null) {
      season = int.parse(se.group(1)!);
      episode = int.parse(se.group(2)!);
      titleEnd = se.start;
    }

    int? year;
    final yearMatch = _year.firstMatch(normalized.substring(0, titleEnd));
    if (yearMatch != null && yearMatch.start > 0) {
      year = int.parse(yearMatch.group(1)!);
      titleEnd = yearMatch.start < titleEnd ? yearMatch.start : titleEnd;
    }

    var title = normalized.substring(0, titleEnd);
    title = title.replaceAll(_junk, '');
    title = title.replaceAll(RegExp(r'[\[\](){}-]'), ' ');
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.isEmpty) title = base.trim();

    return MatchResult(
      title: title,
      year: year,
      seasonNumber: season,
      episodeNumber: episode,
      resolutionTag: resolution,
    );
  }

  /// Priority: 4K > HDR > 1080p > 720p (badge spec).
  String? resolutionTag(String name) {
    if (_fourK.hasMatch(name)) return '4K';
    if (_hdr.hasMatch(name)) return 'HDR';
    if (_fullHd.hasMatch(name)) return '1080p';
    if (_hd.hasMatch(name)) return '720p';
    return null;
  }
}
