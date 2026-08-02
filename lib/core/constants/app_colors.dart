import 'package:flutter/material.dart';

/// Cosmos – God-level dark palette
abstract class AppColors {
  // ── Backgrounds ────────────────────────────────────────────────────────────
  static const background   = Color(0xFF090D16); // Slate-950
  static const surface      = Color(0xFF0F1623); // Slightly lighter slate
  static const cardBg       = Color(0xFF141C2E); // Card surface

  // ── Accents ────────────────────────────────────────────────────────────────
  static const cyan         = Color(0xFF06B6D4); // Neon cyan
  static const cyanLight    = Color(0xFF67E8F9);
  static const cyanDark     = Color(0xFF0891B2);

  static const purple       = Color(0xFFA855F7); // Neon purple
  static const purpleLight  = Color(0xFFD8B4FE);
  static const purpleDark   = Color(0xFF7C3AED);

  // ── Gradients ──────────────────────────────────────────────────────────────
  static const gradientCyanPurple = LinearGradient(
    colors: [cyan, purple],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const gradientDark = LinearGradient(
    colors: [Color(0xFF0F1623), Color(0xFF0A0E1A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientCard = LinearGradient(
    colors: [Color(0xFF1A2340), Color(0xFF0F1623)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Status ─────────────────────────────────────────────────────────────────
  static const success  = Color(0xFF10B981);
  static const warning  = Color(0xFFF59E0B);
  static const error    = Color(0xFFEF4444);
  static const info     = Color(0xFF3B82F6);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted     = Color(0xFF475569);

  // ── Glass / Overlays ───────────────────────────────────────────────────────
  static const glassBorder   = Color(0x1AFFFFFF); // white10
  static const glassFill     = Color(0x0DFFFFFF); // white5
  static const overlayLight  = Color(0x14FFFFFF);
  static const overlayDark   = Color(0x80000000);

  // ── Shadows / Glows ────────────────────────────────────────────────────────
  static List<BoxShadow> cyanGlow(double blurRadius) => [
    BoxShadow(color: cyan.withOpacity(0.25), blurRadius: blurRadius, spreadRadius: -4),
  ];

  static List<BoxShadow> purpleGlow(double blurRadius) => [
    BoxShadow(color: purple.withOpacity(0.25), blurRadius: blurRadius, spreadRadius: -4),
  ];

  static List<BoxShadow> cardShadow() => [
    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 8)),
  ];
}
