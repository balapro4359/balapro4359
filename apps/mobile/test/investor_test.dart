import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holdings/controller.dart';
import 'package:holdings/format.dart';
import 'package:holdings/main.dart';
import 'package:holdings_engine/holdings_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the book opens, the map stays closed, and Harborview trades', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mirror = HoldingsGame(seed: 1);
    final free = mirror.plots.firstWhere((plot) => plot.ownerId == null && plot.building == null);
    final price = mirror.priceOf(free);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameControllerProvider.overrideWith((ref) => GameController(seed: 1)),
        ],
        child: const HoldingsApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Day 1 of 40'), findsOneWidget);
    expect(find.text('Net worth'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('How to play'), findsOneWidget);

    await tester.tap(find.text('How to play'));
    await tester.pumpAndSettle();
    expect(
      find.text('You start with \$12,000 and 40 days. Finish with the highest net worth.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(find.text('Ironridge'), findsOneWidget);
    expect(find.text('Greenvale'), findsOneWidget);
    expect(find.text('Prices for this city are not in the book yet.'), findsNWidgets(2));
    expect(find.textContaining('%'), findsNothing);

    await tester.tap(find.text('Harbor'));
    await tester.pumpAndSettle();
    expect(find.text('The Docks'), findsOneWidget);
    expect(find.text('1 of 40'), findsOneWidget);

    await tester.ensureVisible(find.text(free.name));
    await tester.tap(find.text(free.name));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Buy ${money(price)}'), findsOneWidget);

    await tester.tap(find.text('Buy ${money(price)}'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Build a parking lot'), findsOneWidget);
    expect(find.textContaining('Build a car wash'), findsOneWidget);

    await tester.tap(find.textContaining('Build a parking lot'));
    await tester.pump(const Duration(milliseconds: 400));
    mirror.buy('you', free.id);
    mirror.build('you', free.id, BuildingType.parking);
    expect(find.text('Sell ${money(saleProceeds(mirror.priceOf(free)))}'), findsOneWidget);

    await tester.tap(find.text('Next day'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('2 of 40'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.notes_outlined));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('bought ${free.name}'), findsOneWidget);
    expect(find.textContaining('built a parking lot on ${free.name}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a short phone still lays out the book and the harbor', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameControllerProvider.overrideWith((ref) => GameController(seed: 2)),
        ],
        child: const HoldingsApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Net worth'), findsOneWidget);

    await tester.tap(find.text('Harbor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Next day'), findsOneWidget, reason: _visibleText(tester));
    expect(tester.takeException(), isNull);
  });
}

String _visibleText(WidgetTester tester) {
  return find.byType(Text).evaluate().map((element) {
    final widget = element.widget as Text;
    return widget.data ?? widget.textSpan?.toPlainText();
  }).join(' | ');
}
