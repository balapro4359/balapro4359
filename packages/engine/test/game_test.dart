import 'package:holdings_engine/holdings_engine.dart';
import 'package:test/test.dart';

void main() {
  test('the town has four streets and the twenty named plots', () {
    final game = HoldingsGame(seed: 1);
    expect(game.streets.map((s) => s.name), [
      'The Docks',
      'Main Street',
      'Old Town',
      'Edge Road',
    ]);
    expect(game.plots, hasLength(20));
    expect(
      game.plots.where((p) => p.streetId == 'docks').map((p) => p.name),
      ['Pier 1', 'Pier 2', 'Pier 3', 'Pier 4', 'Pier 5'],
    );
    expect(
      game.plots.where((p) => p.streetId == 'main').map((p) => p.name),
      ['101 Main', '115 Main', '130 Main', '144 Main', '160 Main'],
    );
    expect(game.investors, hasLength(5));
    expect(game.investor('you').cash, Tuning.startingCash);
  });

  test('two unowned parking lots start off Edge Road', () {
    final game = HoldingsGame(seed: 4);
    final parked = game.plots.where(
      (p) => p.building == BuildingType.parking && p.builtOnDay == 0,
    );
    expect(parked, hasLength(2));
    expect(parked.every((p) => p.streetId != 'edge'), isTrue);
  });

  test('the same seed plays the same opening', () {
    final a = HoldingsGame(seed: 9);
    final b = HoldingsGame(seed: 9);
    expect(
      a.plots.map((p) => p.baseTraffic),
      b.plots.map((p) => p.baseTraffic),
    );
    expect(
      a.plots.map((p) => p.ownerId),
      b.plots.map((p) => p.ownerId),
    );
  });

  test('buying pays the plot value and selling returns 95 percent', () {
    final game = HoldingsGame(seed: 2);
    final target = game.plots.firstWhere(
      (p) => p.ownerId == null && p.building == null,
    );
    final price = game.priceOf(target);
    final demand = game.streetOf(target).demand;
    final bought = game.buy('you', target.id);
    expect(bought.ok, isTrue);
    expect(game.investor('you').cash, Tuning.startingCash - price);
    expect(game.streetOf(target).demand, closeTo(demand + 0.03, 1e-9));

    final sold = game.sell('you', target.id);
    expect(sold.ok, isTrue);
    expect(
      game.investor('you').cash,
      closeTo(Tuning.startingCash - price * Tuning.saleFee, 1e-6),
    );
    expect(target.ownerId, isNull);
    expect(game.streetOf(target).demand, closeTo(demand, 1e-9));
  });

  test('a new building does not earn on the day it is built', () {
    final game = HoldingsGame(seed: 3);
    final target = game.plots.firstWhere(
      (p) => p.ownerId == null && p.building == null && p.streetId == 'main',
    );
    game.buy('you', target.id);
    game.build('you', target.id, BuildingType.carWash);
    game.nextDay();
    expect(game.lastIncome.containsKey(target.id), isFalse);
    expect(game.day, 2);
    game.nextDay();
    expect(game.lastIncome[target.id], isNotNull);
  });

  test('each bot holds at most three plots and Mei never sells', () {
    final game = HoldingsGame(seed: 5);
    final mei = <int>[game.ownedCount('mei')];
    for (var i = 0; i < 12; i++) {
      game.nextDay();
      mei.add(game.ownedCount('mei'));
      for (final bot in ['rita', 'omar', 'mei', 'dex']) {
        expect(game.ownedCount(bot), lessThanOrEqualTo(Tuning.botMaxPlots));
      }
    }
    for (var i = 1; i < mei.length; i++) {
      expect(mei[i], greaterThanOrEqualTo(mei[i - 1]));
    }
  });

  test('the first rumor is on the book by day 3', () {
    final game = HoldingsGame(seed: 8);
    expect(game.streets.every((s) => s.rumor == null), isTrue);
    game.nextDay();
    expect(game.day, 2);
    game.nextDay();
    expect(game.day, 3);
    expect(game.ledger.any((e) => e.kind == 'rumorAnnounced'), isTrue);
  });

  test('day 40 ends the season', () {
    final game = HoldingsGame(seed: 1);
    while (!game.finished) {
      game.nextDay();
    }
    expect(game.day, 40);
    expect(game.nextDay(), isEmpty);
    expect(game.rankOf('you'), inInclusiveRange(1, 5));
  });
}
