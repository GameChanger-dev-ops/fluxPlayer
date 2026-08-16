import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/database/database.dart';
import '../../../core/services/tmdb_service.dart';
import '../../../core/theme/colors.dart';

/// Media card: movies 2:3 portrait, episodes 16:9 landscape, radius 12,
/// hover scale 1.0 to 1.03 in 150ms (design rules).
class MediaCard extends StatefulWidget {
  const MediaCard({
    super.key,
    required this.item,
    this.progress,
    this.watched = false,
    this.onTap,
    this.onLongPress,
  });

  final MediaItem item;
  final double? progress;
  final bool watched;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isEpisode = widget.item.mediaType == 'episode';
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: AspectRatio(
            aspectRatio: isEpisode ? 16 / 9 : 2 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _poster(),
                  _titleGradient(),
                  if (widget.item.resolutionTag != null)
                    Positioned(
                        top: 8, left: 8, child: _pill(widget.item.resolutionTag!)),
                  if (widget.watched)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: FluxColors.indigo,
                        child: Icon(LucideIcons.check,
                            size: 14, color: FluxColors.textPrimary),
                      ),
                    ),
                  if (widget.item.fileMissing)
                    const Positioned(
                      bottom: 8,
                      right: 8,
                      child: Icon(LucideIcons.fileX,
                          size: 16, color: FluxColors.error),
                    ),
                  if (widget.progress != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: widget.progress,
                        minHeight: 3,
                        backgroundColor: FluxColors.glass,
                        color: FluxColors.indigo,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _poster() {
    final posterPath = widget.item.posterPath;
    if (posterPath == null) {
      return Container(
        color: FluxColors.surfaceElevated,
        child: const Center(
          child: Icon(LucideIcons.film, color: FluxColors.textMuted, size: 32),
        ),
      );
    }
    // Image load: fade in 300ms, shimmer while loading (design rules).
    return CachedNetworkImage(
      imageUrl: '${TmdbService.imageBase}$posterPath',
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 300),
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: FluxColors.surface,
        highlightColor: FluxColors.surfaceElevated,
        child: Container(color: FluxColors.surface),
      ),
      errorWidget: (context, url, error) => Container(
        color: FluxColors.surfaceElevated,
        child: const Center(
          child: Icon(LucideIcons.imageOff, color: FluxColors.textMuted),
        ),
      ),
    );
  }

  Widget _pill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: FluxColors.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      );

  Widget _titleGradient() {
    final item = widget.item;
    final label = item.seasonNumber != null && item.episodeNumber != null
        ? '${item.title} \u00b7 S${item.seasonNumber}E${item.episodeNumber}'
        : item.title;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, FluxColors.background],
          ),
        ),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: FluxColors.textPrimary),
        ),
      ),
    );
  }
}
