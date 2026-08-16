import 'package:flutter/material.dart';

/// Flux Player design-system color tokens.
/// HARD RULE: never hardcode colors outside this file.
abstract final class FluxColors {
  static const background = Color(0xFF0A0A0F);
  static const surface = Color(0xFF12121A);
  static const surfaceElevated = Color(0xFF1A1A26);
  static const glass = Color(0x1AFFFFFF);
  static const indigo = Color(0xFF6366F1);
  static const indigoLight = Color(0xFF818CF8);
  static const amber = Color(0xFFF59E0B);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF475569);
  static const success = Color(0xFF10B981);
  static const error = Color(0xFFEF4444);

  // Theme variants
  static const amoledBackground = Color(0xFF000000);
  static const lightBackground = Color(0xFFF8FAFC);
  static const lightSurface = Color(0xFFFFFFFF);

  // Accent options
  static const teal = Color(0xFF14B8A6);
  static const rose = Color(0xFFF43F5E);
  static const emerald = Color(0xFF10B981);
}
