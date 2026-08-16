import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;

import '../../core/database/database.dart';
import '../../core/logging/flux_logger.dart';
import '../../core/platform/desktop_shell.dart';
import '../../core/services/providers.dart';
import '../../core/services/subtitle_service.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../l10n/generated/app_localizations.dart';
import 'subtitle_search_sheet.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, this.filePath});

  static const route = '/player';

  final String? filePath;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _controller;
  late final FluxDatabase _db;
  Timer? _positionWriter;
  StreamSubscription<Tracks>? _tracksSub;
  MediaItem? _mediaItem;
  int? _mediaItemId;
  List<String> _externalSubs = const [];
  bool _subtitleAutoSelected = false;
  bool _controlsVisible = true;
  bool _fileMissing = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _db = ref.read(databaseProvider);
    _player = Player();
    _controller = VideoController(_player);
    _open();
  }

  Future<void> _open() async {
    final path = widget.filePath;
    if (path == null || path.isEmpty) {
      setState(() => _failed = true);
      return;
    }
    try {
      if (!File(path).existsSync()) {
        throw FileSystemException('File not found', path);
      }
      final item = await _db.mediaDao.byFilePath(path);
      _mediaItem = item;
      _mediaItemId = item?.id;

      // 5b: auto-load same-basename external subtitle files.
      _externalSubs =
          ref.read(subtitleServiceProvider).findExternalSubtitles(path);

      // 5a: auto-select the user's preferred embedded subtitle language.
      final preferred =
          await _db.preferencesDao.getValue('subtitle_language') ?? 'en';
      _tracksSub = _player.stream.tracks.listen((tracks) {
        if (_subtitleAutoSelected) return;
        final match = tracks.subtitle
            .where((t) =>
                (t.language ?? '').toLowerCase().startsWith(preferred))
            .toList();
        if (match.isNotEmpty) {
          _subtitleAutoSelected = true;
          _player.setSubtitleTrack(match.first);
        }
      });

      var resumeAt = Duration.zero;
      if (_mediaItemId != null) {
        final entry = await _db.historyDao.entryFor(_mediaItemId!);
        if (entry != null && !entry.watched) {
          resumeAt = Duration(milliseconds: entry.positionMs);
        }
      }

      await _player.open(Media(path));
      if (resumeAt > Duration.zero) {
        await _player.seek(resumeAt);
      }

      // Apply the default playback speed from settings.
      final speed = double.tryParse(
              await _db.preferencesDao.getValue('playback_speed') ?? '') ??
          1.0;
      if (speed != 1.0) {
        await _player.setRate(speed);
      }

      // Windows tray + title bar integration.
      DesktopShell.instance
          .attachPlayer(_player, p.basenameWithoutExtension(path));

      // HARD RULE: write position every 10 seconds, debounced (not per frame).
      _positionWriter =
          Timer.periodic(const Duration(seconds: 10), (_) => _savePosition());
      if (mounted) {
        setState(() {
          _fileMissing = false;
          _failed = false;
        });
      }
    } on FileSystemException catch (e) {
      FluxLogger.instance.w('Cannot open media: $path', e);
      if (_mediaItemId == null) {
        final item = await _db.mediaDao.byFilePath(path);
        _mediaItemId = item?.id;
      }
      await _db.mediaDao.markMissing(path, missing: true);
      if (mounted) setState(() => _fileMissing = true);
    } catch (e, st) {
      FluxLogger.instance.e('Playback failed for $path', e, st);
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _savePosition() async {
    final id = _mediaItemId;
    final duration = _player.state.duration;
    if (id == null || duration == Duration.zero) return;
    await _db.historyDao.savePosition(
      mediaItemId: id,
      positionMs: _player.state.position.inMilliseconds,
      durationMs: duration.inMilliseconds,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _savePosition();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionWriter?.cancel();
    _tracksSub?.cancel();
    DesktopShell.instance.detachPlayer(_player);
    _savePosition();
    _player.dispose();
    super.dispose();
  }

  /// 5c: online subtitle search via OpenSubtitles, download to temp,
  /// load as external track and offer to save next to the video.
  Future<void> _searchSubtitlesOnline() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final item = _mediaItem;
    final tmdbId = item?.tmdbId ?? item?.showTmdbId;
    if (item == null || tmdbId == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.noSubtitlesFound)));
      return;
    }
    final language =
        await _db.preferencesDao.getValue('subtitle_language') ?? 'en';
    if (!mounted) return;
    final result = await SubtitleSearchSheet.show(context, (
      tmdbId: tmdbId,
      language: language,
      seasonNumber: item.seasonNumber,
      episodeNumber: item.episodeNumber,
    ));
    if (result == null || !mounted) return;
    try {
      final service = ref.read(subtitleServiceProvider);
      final tempPath = await service.download(result);
      await _player.setSubtitleTrack(
          SubtitleTrack.uri(tempPath, title: result.releaseName));
      messenger.showSnackBar(SnackBar(
        content: Text(result.releaseName),
        action: SnackBarAction(
          label: l10n.saveSubtitleNextToVideo,
          onPressed: () async {
            final saved =
                await service.saveNextToVideo(tempPath, widget.filePath!);
            if (saved != null) {
              messenger.showSnackBar(
                  SnackBar(content: Text(l10n.subtitleSaved)));
            }
          },
        ),
      ));
    } on SubtitleException catch (e) {
      FluxLogger.instance.w('Online subtitle flow failed: ${e.message}');
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _toggleControls() => setState(() => _controlsVisible = !_controlsVisible);

  void _seekBy(Duration offset) {
    final target = _player.state.position + offset;
    _player.seek(target < Duration.zero ? Duration.zero : target);
  }

  void _retry() {
    setState(() {
      _fileMissing = false;
      _failed = false;
    });
    _open();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasError = _fileMissing || _failed;
    return Scaffold(
      backgroundColor: FluxColors.amoledBackground,
      appBar: hasError ? AppBar() : null,
      body: hasError
          ? _ErrorView(
              message: _fileMissing ? l10n.errorFileMissing : l10n.errorGeneric,
              onRetry: _retry,
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                Video(controller: _controller, controls: NoVideoControls),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleControls,
                  onDoubleTapDown: (details) {
                    final width = MediaQuery.sizeOf(context).width;
                    _seekBy(details.globalPosition.dx < width / 2
                        ? const Duration(seconds: -10)
                        : const Duration(seconds: 10));
                  },
                ),
                // Overlay fade: 0 to 1 opacity, 200ms ease-out (design rule).
                AnimatedOpacity(
                  opacity: _controlsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: _ControlsOverlay(
                      player: _player,
                      title: widget.filePath == null
                          ? l10n.playerTitle
                          : p.basenameWithoutExtension(widget.filePath!),
                      onSeekBy: _seekBy,
                      externalSubs: _externalSubs,
                      onSearchSubtitles: _searchSubtitlesOnline,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({
    required this.player,
    required this.title,
    required this.onSeekBy,
    required this.externalSubs,
    required this.onSearchSubtitles,
  });

  final Player player;
  final String title;
  final void Function(Duration) onSeekBy;
  final List<String> externalSubs;
  final VoidCallback onSearchSubtitles;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.arrowLeft),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SeekBar(player: player),
                  Row(
                    children: [
                      StreamBuilder<bool>(
                        stream: player.stream.playing,
                        initialData: player.state.playing,
                        builder: (context, snapshot) => IconButton(
                          icon: Icon(snapshot.data == true
                              ? LucideIcons.pause
                              : LucideIcons.play),
                          onPressed: player.playOrPause,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.rotateCcw),
                        tooltip: l10n.seekBack,
                        onPressed: () =>
                            onSeekBy(const Duration(seconds: -10)),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.rotateCw),
                        tooltip: l10n.seekForward,
                        onPressed: () => onSeekBy(const Duration(seconds: 10)),
                      ),
                      const Spacer(),
                      _SpeedMenu(player: player),
                      _TrackMenu(player: player, audio: true),
                      _SubtitleMenu(
                        player: player,
                        externalSubs: externalSubs,
                        onSearchOnline: onSearchSubtitles,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeekBar extends StatelessWidget {
  const _SeekBar({required this.player});

  final Player player;

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      initialData: player.state.position,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = player.state.duration;
        final max = duration.inMilliseconds.toDouble();
        return Row(
          children: [
            Text(_format(position),
                style: Theme.of(context).textTheme.labelSmall),
            Expanded(
              child: Slider(
                value: max > 0
                    ? position.inMilliseconds
                        .clamp(0, duration.inMilliseconds)
                        .toDouble()
                    : 0,
                max: max > 0 ? max : 1,
                onChanged: max > 0
                    ? (value) =>
                        player.seek(Duration(milliseconds: value.round()))
                    : null,
              ),
            ),
            Text(_format(duration),
                style: Theme.of(context).textTheme.labelSmall),
          ],
        );
      },
    );
  }
}

class _SpeedMenu extends StatelessWidget {
  const _SpeedMenu({required this.player});

  final Player player;

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      icon: const Icon(LucideIcons.gauge),
      tooltip: AppLocalizations.of(context).speedLabel,
      onSelected: player.setRate,
      itemBuilder: (context) => [
        for (final speed in _speeds)
          PopupMenuItem(value: speed, child: Text('${speed}x')),
      ],
    );
  }
}

class _TrackMenu extends StatelessWidget {
  const _TrackMenu({required this.player, required this.audio});

  final Player player;
  final bool audio;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<int>(
      icon: Icon(audio ? LucideIcons.audioLines : LucideIcons.captions),
      tooltip: audio ? l10n.audioLabel : l10n.subtitlesLabel,
      onSelected: (index) {
        final tracks = player.state.tracks;
        if (audio) {
          player.setAudioTrack(tracks.audio[index]);
        } else {
          player.setSubtitleTrack(tracks.subtitle[index]);
        }
      },
      itemBuilder: (context) {
        if (audio) {
          final tracks = player.state.tracks.audio;
          return [
            for (var i = 0; i < tracks.length; i++)
              PopupMenuItem(
                value: i,
                child: Text(tracks[i].title ??
                    tracks[i].language ??
                    l10n.trackNumber(i + 1)),
              ),
          ];
        }
        final tracks = player.state.tracks.subtitle;
        return [
          for (var i = 0; i < tracks.length; i++)
            PopupMenuItem(
              value: i,
              child: Text(tracks[i].title ??
                  tracks[i].language ??
                  l10n.trackNumber(i + 1)),
            ),
        ];
      },
    );
  }
}

/// Subtitle menu: embedded tracks, auto-discovered external files and the
/// OpenSubtitles online search entry point.
class _SubtitleMenu extends StatelessWidget {
  const _SubtitleMenu({
    required this.player,
    required this.externalSubs,
    required this.onSearchOnline,
  });

  final Player player;
  final List<String> externalSubs;
  final VoidCallback onSearchOnline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<VoidCallback>(
      icon: const Icon(LucideIcons.captions),
      tooltip: l10n.subtitlesLabel,
      onSelected: (callback) => callback(),
      itemBuilder: (context) {
        final embedded = player.state.tracks.subtitle;
        return [
          for (var i = 0; i < embedded.length; i++)
            PopupMenuItem(
              value: () => player.setSubtitleTrack(embedded[i]),
              child: Text(embedded[i].title ??
                  embedded[i].language ??
                  l10n.trackNumber(i + 1)),
            ),
          for (final path in externalSubs)
            PopupMenuItem(
              value: () => player.setSubtitleTrack(
                  SubtitleTrack.uri(path, title: p.basename(path))),
              child: Text(
                  '${p.basename(path)} (${l10n.externalLabel})'),
            ),
          PopupMenuItem(
            value: onSearchOnline,
            child: Row(
              children: [
                const Icon(LucideIcons.globe, size: 16),
                const SizedBox(width: 8),
                Text(l10n.searchSubtitlesOnline),
              ],
            ),
          ),
        ];
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}
