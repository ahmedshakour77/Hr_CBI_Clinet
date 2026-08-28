import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The profile portrait: a circular image that casts a soft tinted shadow,
/// displaying raw image bytes, photo URL, or falling back to initials/silhouette.
class ShadowAvatar extends StatelessWidget {
  const ShadowAvatar({
    super.key,
    this.imageBytes,
    this.photoUrl,
    this.initials,
    this.size = 132,
  });

  final Uint8List? imageBytes;
  final String? photoUrl;

  /// Shown instead of the generic silhouette when we know the person's name.
  final String? initials;

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.25),
            blurRadius: size * 0.22,
            spreadRadius: 1,
            offset: Offset(0, size * 0.09),
          ),
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.08),
            blurRadius: size * 0.08,
            offset: Offset(0, size * 0.02),
          ),
        ],
      ),
      child: ClipOval(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primaryContainer,
                Color.lerp(colors.primaryContainer, colors.primary, 0.35)!,
              ],
            ),
          ),
          child: _content(context, colors),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, ColorScheme colors) {
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      return Image.memory(
        imageBytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) => _placeholder(context, colors),
      );
    }

    final photo = photoUrl;
    if (photo != null && photo.isNotEmpty) {
      return Image.network(
        photo,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) => _placeholder(context, colors),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _placeholder(context, colors),
      );
    }

    return _placeholder(context, colors);
  }

  Widget _placeholder(BuildContext context, ColorScheme colors) {
    final text = initials;

    if (text != null && text.isNotEmpty) {
      return Center(
        child: Text(
          text,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: colors.onPrimaryContainer,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      );
    }

    return Center(
      child: Icon(
        Icons.person_rounded,
        size: size * 0.56,
        color: colors.onPrimaryContainer.withValues(alpha: 0.55),
      ),
    );
  }
}
