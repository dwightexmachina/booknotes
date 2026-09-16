import 'package:flutter/material.dart';

/// Design tokens matching the approved static mock: library-green accent on
/// paper neutrals, serif for book content, mono for counts.
class Palette {
  final Color paper;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color faint;
  final Color accent;
  final Color hairline;
  final Color rowHover;
  final Color rowSelected;
  final Color chipBg;
  final Color chipInk;

  const Palette({
    required this.paper,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.hairline,
    required this.rowHover,
    required this.rowSelected,
    required this.chipBg,
    required this.chipInk,
  });

  static const light = Palette(
    paper: Color(0xFFFAFAF7),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF20261F),
    muted: Color(0xFF6B7268),
    faint: Color(0xFF8C9388),
    accent: Color(0xFF2F5D46),
    hairline: Color(0xFFE2E5DC),
    rowHover: Color(0xFFF1F3EC),
    rowSelected: Color(0xFFE9EEE4),
    chipBg: Color(0xFFEDF2EA),
    chipInk: Color(0xFF2F5D46),
  );

  static const dark = Palette(
    paper: Color(0xFF161A16),
    surface: Color(0xFF1D221C),
    ink: Color(0xFFE6E9E1),
    muted: Color(0xFF9BA396),
    faint: Color(0xFF7B8377),
    accent: Color(0xFF83B99A),
    hairline: Color(0xFF2B312A),
    rowHover: Color(0xFF232922),
    rowSelected: Color(0xFF283126),
    chipBg: Color(0xFF263028),
    chipInk: Color(0xFF9DCBAF),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

const serif = 'Lora';
const mono = 'JetBrains Mono';
