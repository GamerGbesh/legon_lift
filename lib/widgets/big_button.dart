// Owner: WS4. Shared widget; constructor frozen (SPEC 12.3).
import 'package:material_ui/material_ui.dart';

import '../app/theme/tokens.dart';
import '../app/theme/typography.dart';

enum BigButtonKind { primary, secondary, destructive }

/// Full-width thumb-zone button: primary = filled gold, secondary = outlined, destructive = danger text.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.kind = BigButtonKind.primary,
    this.height = Sizes.primaryButton,
  });

  final String label;
  final IconData? icon;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final BigButtonKind kind;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button));
    final textStyle = AppText.body.copyWith(fontSize: 18, fontWeight: FontWeight.w600);
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 24), const SizedBox(width: Space.s)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1)),
      ],
    );
    final size = WidgetStatePropertyAll(Size.fromHeight(height));
    return SizedBox(
      width: double.infinity,
      height: height,
      child: switch (kind) {
        BigButtonKind.primary => FilledButton(
            onPressed: onPressed,
            style: ButtonStyle(
              minimumSize: size,
              shape: WidgetStatePropertyAll(shape),
              backgroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.disabled) ? t.surface2 : t.primary),
              foregroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.disabled) ? t.muted : t.onPrimary),
              textStyle: WidgetStatePropertyAll(textStyle),
            ),
            child: child,
          ),
        BigButtonKind.secondary => OutlinedButton(
            onPressed: onPressed,
            style: ButtonStyle(
              minimumSize: size,
              shape: WidgetStatePropertyAll(shape),
              side: WidgetStatePropertyAll(BorderSide(color: t.muted)),
              foregroundColor: WidgetStatePropertyAll(t.onSurface),
              textStyle: WidgetStatePropertyAll(textStyle),
            ),
            child: child,
          ),
        BigButtonKind.destructive => TextButton(
            onPressed: onPressed,
            style: ButtonStyle(
              minimumSize: size,
              shape: WidgetStatePropertyAll(shape),
              foregroundColor: WidgetStatePropertyAll(t.danger),
              textStyle: WidgetStatePropertyAll(textStyle),
            ),
            child: child,
          ),
      },
    );
  }
}
