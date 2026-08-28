import 'package:flutter/material.dart';

/// One labelled row of the profile card.
///
/// A missing value is shown as a muted placeholder rather than an empty space,
/// so "we don't have this yet" is visibly different from "this is blank".
class ProfileField extends StatelessWidget {
  const ProfileField({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.placeholder = 'غير محدد',
  });

  final IconData icon;
  final String label;

  /// Null renders [placeholder] in a muted style.
  final String? value;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasValue = value != null && value!.isNotEmpty;

    return Semantics(
      label: label,
      value: hasValue ? value : placeholder,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasValue ? value! : placeholder,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: hasValue
                          ? colors.onSurface
                          : colors.onSurfaceVariant.withValues(alpha: 0.55),
                      fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                    ),
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
