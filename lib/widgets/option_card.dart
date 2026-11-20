// Owner: WS4. Shared widget (additive to SPEC 12.3): a big single-choice card used by onboarding,
// the split picker and other "pick one" lists.
import 'package:material_ui/material_ui.dart';

import '../app/theme/tokens.dart';
import '../app/theme/typography.dart';

/// A full-width selectable card (min 56 dp) with a radio mark, an optional icon, subtitle and badge.
class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
    this.icon,
    this.badge,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Small highlighted tag such as "Recommended".
  final String? badge;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? Color.alphaBlend(t.primary.withValues(alpha: 0.12), t.surface) : t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: selected ? t.primary : t.surface2, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Sizes.minTap + 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: selected ? t.primary : t.muted, size: 28),
                    const SizedBox(width: Space.m),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          spacing: Space.s,
                          runSpacing: Space.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(title, style: AppText.bodyStrong.copyWith(color: t.onSurface)),
                            if (badge != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: 2),
                                decoration: BoxDecoration(
                                  color: t.primary,
                                  borderRadius: BorderRadius.circular(Radii.chip),
                                ),
                                child: Text(badge!, style: AppText.caption.copyWith(color: t.onPrimary, fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!, style: AppText.label.copyWith(color: t.muted)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  trailing ??
                      Icon(
                        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: selected ? t.primary : t.muted,
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
