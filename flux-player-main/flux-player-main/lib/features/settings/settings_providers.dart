import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/theme/app_theme.dart';

class FluxSettings {
  const FluxSettings({
    this.subtitleLanguage = 'en',
    this.audioLanguage = 'en',
    this.rememberPosition = true,
    this.autoPlayNext = true,
    this.skipIntroSeconds = 0,
    this.playbackSpeed = 1.0,
    this.themeMode = FluxThemeMode.dark,
    this.accent = FluxAccent.indigo,
    this.metadataLanguage = 'en-US',
    this.autoScanOnStart = true,
    this.subtitleFontSize = 16.0,
  });

  final String subtitleLanguage;
  final String audioLanguage;
  final bool rememberPosition;
  final bool autoPlayNext;
  final int skipIntroSeconds;
  final double playbackSpeed;
  final FluxThemeMode themeMode;
  final FluxAccent accent;
  final String metadataLanguage;
  final bool autoScanOnStart;
  final double subtitleFontSize;

  FluxSettings copyWith({
    String? subtitleLanguage,
    String? audioLanguage,
    bool? rememberPosition,
    bool? autoPlayNext,
    int? skipIntroSeconds,
    double? playbackSpeed,
    FluxThemeMode? themeMode,
    FluxAccent? accent,
    String? metadataLanguage,
    bool? autoScanOnStart,
    double? subtitleFontSize,
  }) =>
      FluxSettings(
        subtitleLanguage: subtitleLanguage ?? this.subtitleLanguage,
        audioLanguage: audioLanguage ?? this.audioLanguage,
        rememberPosition: rememberPosition ?? this.rememberPosition,
        autoPlayNext: autoPlayNext ?? this.autoPlayNext,
        skipIntroSeconds: skipIntroSeconds ?? this.skipIntroSeconds,
        playbackSpeed: playbackSpeed ?? this.playbackSpeed,
        themeMode: themeMode ?? this.themeMode,
        accent: accent ?? this.accent,
        metadataLanguage: metadataLanguage ?? this.metadataLanguage,
        autoScanOnStart: autoScanOnStart ?? this.autoScanOnStart,
        subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
      );
}

class SettingsNotifier extends AsyncNotifier<FluxSettings> {
  PreferencesDao get _prefs => ref.read(databaseProvider).preferencesDao;

  @override
  Future<FluxSettings> build() async {
    final dao = _prefs;
    Future<String?> v(String key) => dao.getValue(key);
    return FluxSettings(
      subtitleLanguage: await v('subtitle_language') ?? 'en',
      audioLanguage: await v('audio_language') ?? 'en',
      rememberPosition: (await v('remember_position') ?? 'true') == 'true',
      autoPlayNext: (await v('auto_play_next') ?? 'true') == 'true',
      skipIntroSeconds:
          int.tryParse(await v('skip_intro_seconds') ?? '') ?? 0,
      playbackSpeed: double.tryParse(await v('playback_speed') ?? '') ?? 1.0,
      themeMode: FluxThemeMode.values.asNameMap()[await v('theme_mode')] ??
          FluxThemeMode.dark,
      accent:
          FluxAccent.values.asNameMap()[await v('accent')] ?? FluxAccent.indigo,
      metadataLanguage: await v('metadata_language') ?? 'en-US',
      autoScanOnStart: (await v('auto_scan') ?? 'true') == 'true',
      subtitleFontSize:
          double.tryParse(await v('subtitle_font_size') ?? '') ?? 16.0,
    );
  }

  FluxSettings get _current => state.valueOrNull ?? const FluxSettings();

  Future<void> _set(String key, String value, FluxSettings updated) async {
    await _prefs.setValue(key, value);
    state = AsyncData(updated);
  }

  Future<void> setSubtitleLanguage(String value) => _set('subtitle_language',
      value, _current.copyWith(subtitleLanguage: value));

  Future<void> setAudioLanguage(String value) =>
      _set('audio_language', value, _current.copyWith(audioLanguage: value));

  Future<void> setRememberPosition(bool value) => _set('remember_position',
      '$value', _current.copyWith(rememberPosition: value));

  Future<void> setAutoPlayNext(bool value) =>
      _set('auto_play_next', '$value', _current.copyWith(autoPlayNext: value));

  Future<void> setSkipIntroSeconds(int value) => _set('skip_intro_seconds',
      '$value', _current.copyWith(skipIntroSeconds: value));

  Future<void> setPlaybackSpeed(double value) => _set('playback_speed',
      '$value', _current.copyWith(playbackSpeed: value));

  Future<void> setThemeMode(FluxThemeMode value) =>
      _set('theme_mode', value.name, _current.copyWith(themeMode: value));

  Future<void> setAccent(FluxAccent value) =>
      _set('accent', value.name, _current.copyWith(accent: value));

  Future<void> setMetadataLanguage(String value) => _set('metadata_language',
      value, _current.copyWith(metadataLanguage: value));

  Future<void> setAutoScanOnStart(bool value) =>
      _set('auto_scan', '$value', _current.copyWith(autoScanOnStart: value));

  Future<void> setSubtitleFontSize(double value) => _set('subtitle_font_size',
      '$value', _current.copyWith(subtitleFontSize: value));
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, FluxSettings>(SettingsNotifier.new);

final libraryFoldersProvider = StreamProvider<List<LibraryFolder>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.libraryFolders).watch();
});
