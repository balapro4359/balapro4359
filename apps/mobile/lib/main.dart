import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controller.dart';
import 'pages.dart';
import 'theme.dart';
import 'widgets.dart';

final gameControllerProvider = ChangeNotifierProvider<GameController>((ref) {
  return GameController();
});

void main() {
  runApp(const ProviderScope(child: HoldingsApp()));
}

class HoldingsApp extends StatelessWidget {
  const HoldingsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Holdings',
      debugShowCheckedModeBanner: false,
      theme: holdingsTheme(Brightness.light),
      darkTheme: holdingsTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const InvestorShell(),
    );
  }
}

class InvestorShell extends ConsumerStatefulWidget {
  const InvestorShell({super.key});

  @override
  ConsumerState<InvestorShell> createState() => _InvestorShellState();
}

class _InvestorShellState extends ConsumerState<InvestorShell> {
  final _pages = PageController();
  var _drive = 0;

  void _reveal(int index) {
    if (!mounted || !_pages.hasClients) return;
    final page = _pages.page ?? _pages.initialPage.toDouble();
    if ((page - index).abs() < 0.01) return;
    final drive = ++_drive;
    final motion = motionOf(context);
    if (motion == Duration.zero) {
      _pages.jumpToPage(index);
      _drive = 0;
      return;
    }
    _pages
        .animateToPage(index, duration: motion, curve: Curves.easeOutCubic)
        .whenComplete(() {
      if (_drive == drive) _drive = 0;
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(gameControllerProvider);
    final palette = HoldingsPalette.of(context);
    ref.listen<int>(gameControllerProvider.select((c) => c.tab),
        (previous, next) {
      _reveal(next);
    });
    ref.listen<int>(gameControllerProvider.select((c) => c.noticeId),
        (previous, next) {
      final message = ref.read(gameControllerProvider).notice;
      if (message == null || next == previous) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });

    final pages = [
      BookPage(
          controller: controller,
          onOpenHarbor: () => controller.openCity('harborview')),
      MapPage(game: controller.game, onOpenCity: controller.openCity),
      HarborPage(controller: controller),
      NewsPage(game: controller.game),
    ];

    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (index) {
                  if (_drive != 0) return;
                  if (controller.tab != index) controller.showTab(index);
                },
                children: pages,
              ),
            ),
            if (controller.game.finished)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: PillButton(
                    label: 'Play again', onPressed: controller.playAgain),
              ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: controller.tab,
        height: 64,
        backgroundColor: palette.card,
        indicatorColor: palette.tealWash,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: controller.showTab,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Book',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: const Icon(Icons.anchor_outlined),
            selectedIcon: const Icon(Icons.anchor),
            label: switch (controller.cityId) {
              'ironridge' => 'Mine',
              'greenvale' => 'Valley',
              _ => 'Harbor',
            },
          ),
          const NavigationDestination(
            icon: Icon(Icons.notes_outlined),
            selectedIcon: Icon(Icons.notes),
            label: 'News',
          ),
        ],
      ),
    );
  }
}
