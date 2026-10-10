import 'package:flutter/material.dart';

abstract final class HColors {
  static const bg = Color(0xFFF4F1EB);
  static const ink = Color(0xFF1B1A17);
  static const muted = Color(0xFF7C776E);
  static const teal = Color(0xFF1E7A72);
  static const tealWash = Color(0xFFE6F3F1);
  static const coral = Color(0xFFD4543C);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE4DFD6);
  static const sand = Color(0xFFE8E1D4);
  static const water = Color(0xFF8FCCC6);
  static const you = Color(0xFF1E7A72);
  static const rita = Color(0xFFD4543C);
  static const omar = Color(0xFFD08A2A);
  static const mei = Color(0xFF3E6FBF);
  static const dex = Color(0xFF7A5EA7);
  static const tara = Color(0xFF2A6B62);
  static const vik = Color(0xFF8E4B3A);
}

const _owners = {
  'you': HColors.you,
  'rita': HColors.rita,
  'omar': HColors.omar,
  'mei': HColors.mei,
  'dex': HColors.dex,
  'tara': HColors.tara,
  'vik': HColors.vik,
};

Color ownerColor(String? id) => _owners[id] ?? HColors.muted;

@immutable
class HoldingsPalette extends ThemeExtension<HoldingsPalette> {
  const HoldingsPalette({
    required this.bg,
    required this.ink,
    required this.muted,
    required this.teal,
    required this.tealWash,
    required this.coral,
    required this.card,
    required this.line,
    required this.sand,
    required this.water,
    required this.onWater,
  });

  final Color bg;
  final Color ink;
  final Color muted;
  final Color teal;
  final Color tealWash;
  final Color coral;
  final Color card;
  final Color line;
  final Color sand;
  final Color water;
  final Color onWater;

  static const day = HoldingsPalette(
    bg: HColors.bg,
    ink: HColors.ink,
    muted: HColors.muted,
    teal: HColors.teal,
    tealWash: HColors.tealWash,
    coral: HColors.coral,
    card: HColors.card,
    line: HColors.line,
    sand: HColors.sand,
    water: HColors.water,
    onWater: Colors.white,
  );

  static const night = HoldingsPalette(
    bg: Color(0xFF121614),
    ink: Color(0xFFF4F1EB),
    muted: Color(0xFFA8A297),
    teal: Color(0xFF7DCFC6),
    tealWash: Color(0xFF1C3330),
    coral: Color(0xFFE07A64),
    card: Color(0xFF1C211E),
    line: Color(0xFF2C3330),
    sand: Color(0xFF2A2824),
    water: Color(0xFF163E3C),
    onWater: Color(0xFFF4F1EB),
  );

  static HoldingsPalette of(BuildContext context) {
    return Theme.of(context).extension<HoldingsPalette>() ?? day;
  }

  @override
  HoldingsPalette copyWith({
    Color? bg,
    Color? ink,
    Color? muted,
    Color? teal,
    Color? tealWash,
    Color? coral,
    Color? card,
    Color? line,
    Color? sand,
    Color? water,
    Color? onWater,
  }) {
    return HoldingsPalette(
      bg: bg ?? this.bg,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      teal: teal ?? this.teal,
      tealWash: tealWash ?? this.tealWash,
      coral: coral ?? this.coral,
      card: card ?? this.card,
      line: line ?? this.line,
      sand: sand ?? this.sand,
      water: water ?? this.water,
      onWater: onWater ?? this.onWater,
    );
  }

  @override
  HoldingsPalette lerp(ThemeExtension<HoldingsPalette>? other, double t) {
    if (other is! HoldingsPalette) return this;
    return HoldingsPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      teal: Color.lerp(teal, other.teal, t)!,
      tealWash: Color.lerp(tealWash, other.tealWash, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      card: Color.lerp(card, other.card, t)!,
      line: Color.lerp(line, other.line, t)!,
      sand: Color.lerp(sand, other.sand, t)!,
      water: Color.lerp(water, other.water, t)!,
      onWater: Color.lerp(onWater, other.onWater, t)!,
    );
  }
}

ThemeData holdingsTheme(Brightness brightness) {
  final night = brightness == Brightness.dark;
  final palette = night ? HoldingsPalette.night : HoldingsPalette.day;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: palette.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: palette.teal,
      brightness: brightness,
      primary: palette.teal,
      surface: palette.card,
    ),
    splashFactory: InkSparkle.splashFactory,
    extensions: [palette],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: palette.ink,
      displayColor: palette.ink,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.card,
      indicatorColor: palette.tealWash,
      height: 64,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: palette.ink),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.ink,
      contentTextStyle: TextStyle(color: palette.bg, fontSize: 15),
      behavior: SnackBarBehavior.floating,
    ),
    dividerColor: palette.line,
  );
}

Duration motionOf(BuildContext context) {
  final reduce = MediaQuery.disableAnimationsOf(context);
  return reduce ? Duration.zero : const Duration(milliseconds: 320);
}
