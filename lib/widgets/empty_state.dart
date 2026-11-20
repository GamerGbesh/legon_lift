// Owner: WS4. Shared widget; constructor frozen (SPEC 12.3).
import 'package:material_ui/material_ui.dart';

import '../app/theme/tokens.dart';
import '../app/theme/typography.dart';

/// Centered icon + title + body + optional action for empty lists.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.action});

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: t.muted),
            const SizedBox(height: Space.l),
            Text(title, style: AppText.title.copyWith(color: t.onSurface), textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: Space.s),
              Text(body!, style: AppText.body.copyWith(color: t.muted), textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: Space.xl), action!],
          ],
        ),
      ),
    );
  }
}
