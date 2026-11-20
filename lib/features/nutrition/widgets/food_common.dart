// Owner: WS6. Small pieces shared by the Food tabs.
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';

final NumberFormat _grouped = NumberFormat.decimalPattern('en');

/// 2100 -> "2,100".
String groupedInt(num n) => _grouped.format(n.round());

/// A signed whole number with a real minus sign: -150 -> "−150", 1000 -> "+1,000".
String signedInt(int n) => n < 0 ? '−${groupedInt(-n)}' : '+${groupedInt(n)}';

/// Litres from ml without trailing zeros: 3250 -> "3.25 L", 4000 -> "4 L".
String litres(int ml) {
  final l = (ml / 1000).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  return '$l L';
}

/// 6.5 -> "6.5", 8.0 -> "8".
String trimNumber(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

/// "12 Nov" from a `yyyy-MM-dd` key.
String shortDate(String key) => DateFormat('d MMM').format(DateTime.parse(key));

/// A tinted note with an icon (disclaimers, rules of thumb).
class InfoNote extends StatelessWidget {
  const InfoNote({super.key, required this.text, this.icon = Icons.info_outline, this.color});

  final String text;
  final IconData icon;

  /// Icon colour; defaults to the muted token.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(color: t.surface2, borderRadius: BorderRadius.circular(Radii.card)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color ?? t.muted),
          const SizedBox(width: Space.m),
          Expanded(child: Text(text, style: AppText.label.copyWith(color: t.onSurface))),
        ],
      ),
    );
  }
}

/// A padded card with an optional title, the standard surface for a block of content.
class FoodCard extends StatelessWidget {
  const FoodCard({super.key, required this.child, this.padding = const EdgeInsets.all(Space.l)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: padding, child: child));
}

/// A bulleted line of body text.
class Bullet extends StatelessWidget {
  const Bullet(this.text, {super.key, this.icon, this.iconColor});

  final String text;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: icon != null
                ? Icon(icon, size: 18, color: iconColor ?? t.muted)
                : Padding(
                    padding: const EdgeInsets.only(top: 8, left: 6),
                    child: Container(width: 6, height: 6, decoration: BoxDecoration(color: t.muted, shape: BoxShape.circle)),
                  ),
          ),
          const SizedBox(width: Space.s),
          Expanded(child: Text(text, style: AppText.body.copyWith(color: t.onSurface))),
        ],
      ),
    );
  }
}
