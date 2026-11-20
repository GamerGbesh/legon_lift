// Owner: WS5. Pumps a WS5 screen inside the real provider tree (buildRoot) with fakes.
import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/app/routes.dart';
import 'package:legon_lift/app/theme/app_theme.dart';
import 'package:legon_lift/app/theme/tokens.dart';
import 'package:legon_lift/features/session_player/player_screen.dart';
import 'package:legon_lift/main.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fakes.dart';

/// Stands in for the session player (owned by WS3) so tests can assert navigation to it.
class FakePlayerPage extends StatelessWidget {
  const FakePlayerPage({super.key, required this.args});

  final PlayerArgs args;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text('player:${args.sessionId}'));
}

Route<dynamic>? _routes(RouteSettings s) {
  if (s.name == Routes.session) {
    final args = s.arguments is PlayerArgs ? s.arguments! as PlayerArgs : const PlayerArgs();
    return MaterialPageRoute<dynamic>(settings: s, builder: (_) => FakePlayerPage(args: args));
  }
  return onGenerateRoute(s);
}

/// Pumps [home] at the reference phone size (412 x 892 dp) with animations disabled (the frame
/// animator then shows still frames, so pumpAndSettle works).
Future<void> pumpScreen(WidgetTester tester, FakeApp app, Widget home, {Size size = const Size(412, 892)}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final root = await buildRoot(
    app.deps,
    child: MaterialApp(
      theme: AppTheme.build(legonNight),
      home: home,
      onGenerateRoute: _routes,
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
    ),
  );
  await tester.pumpWidget(root);
  await tester.pumpAndSettle();
}
