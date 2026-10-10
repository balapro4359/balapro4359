import 'package:flutter/material.dart';

/// A place from the agreed world plates. Later art can replace the asset.
class WorldPlate extends StatelessWidget {
  const WorldPlate({super.key, required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      gaplessPlayback: true,
    );
  }
}

String harborPlate(Brightness brightness) {
  return brightness == Brightness.dark
      ? 'assets/world/harbor-night.jpg'
      : 'assets/world/harbor-day.jpg';
}

String cityPlate(String cityId, Brightness brightness) {
  return switch (cityId) {
    'ironridge' => 'assets/world/ironridge.jpg',
    'greenvale' => 'assets/world/greenvale.jpg',
    _ => harborPlate(brightness),
  };
}
