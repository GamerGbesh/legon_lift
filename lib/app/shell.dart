// Owner: WS4. Bottom navigation with 5 tabs kept alive in an IndexedStack (SPEC 3.1).
import 'package:material_ui/material_ui.dart';

import '../features/library/library_screen.dart';
import '../features/program/program_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/today/today_screen.dart';
import '../features/you/you_screen.dart';

/// The five tabs, in bottom-bar order.
enum ShellTab { today, program, library, progress, you }

/// The main screen after onboarding (route `/`).
///
/// Android back on any tab other than Today returns to Today first. Inactive tabs keep their
/// state but their animations are paused ([TickerMode]).
class Shell extends StatefulWidget {
  const Shell({super.key, this.initialTab = ShellTab.today});

  final ShellTab initialTab;

  /// Switches the enclosing shell to [tab] (no-op outside a shell).
  static void goTo(BuildContext context, ShellTab tab) =>
      context.findAncestorStateOfType<_ShellState>()?._select(tab.index);

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late int _index = widget.initialTab.index;

  static const _tabs = [TodayScreen(), ProgramScreen(), LibraryScreen(), ProgressScreen(), YouScreen()];

  void _select(int i) {
    if (i != _index) setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _index == ShellTab.today.index,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _select(ShellTab.today.index);
        },
        child: Scaffold(
          body: IndexedStack(
            index: _index,
            children: [
              for (final (i, tab) in _tabs.indexed) TickerMode(enabled: i == _index, child: tab),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Today'),
              NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Program'),
              NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Library'),
              NavigationDestination(
                  icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Progress'),
              NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'You'),
            ],
          ),
        ),
      );
}
