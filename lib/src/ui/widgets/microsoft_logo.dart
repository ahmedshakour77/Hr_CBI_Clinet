import 'package:flutter/material.dart';

/// The Microsoft four-square mark, drawn rather than shipped as an asset.
///
/// Microsoft's brand guidelines require the logo to appear on the sign-in
/// button, at its official colours and with clear space around it.
class MicrosoftLogo extends StatelessWidget {
  const MicrosoftLogo({super.key, this.size = 18});

  final double size;

  static const _orange = Color(0xFFF25022);
  static const _green = Color(0xFF7FBA00);
  static const _blue = Color(0xFF00A4EF);
  static const _yellow = Color(0xFFFFB900);

  @override
  Widget build(BuildContext context) {
    final tile = (size - 2) / 2;

    return SizedBox(
      width: size,
      height: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Tile(tile, _orange),
              const SizedBox(width: 2),
              _Tile(tile, _green),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Tile(tile, _blue),
              const SizedBox(width: 2),
              _Tile(tile, _yellow),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.size, this.color);

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, color: color);
}
