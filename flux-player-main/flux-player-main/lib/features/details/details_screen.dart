import 'package:flutter/material.dart';

import '../../core/widgets/glass_card.dart';
import '../../l10n/generated/app_localizations.dart';

class DetailsScreen extends StatelessWidget {
  const DetailsScreen({
    super.key,
    required this.mediaType,
    required this.tmdbId,
  });

  static const route = '/details';

  final String mediaType;
  final int tmdbId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.detailsTitle)),
      body: Center(
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.placeholderComingSoon),
        ),
      ),
    );
  }
}
