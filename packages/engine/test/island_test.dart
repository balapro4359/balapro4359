import 'package:holdings_engine/holdings_engine.dart';
import 'package:test/test.dart';

void main() {
  test('the locked share cap and fee stay at the brief', () {
    expect(Tuning.shareCap, 0.20);
    expect(Tuning.shareFee, 0.005);
    expect(Tuning.saleProceeds, 0.95);
    final game = IslandGame(seed: 1);
    expect(game.shareCapOf(game.company('harbor-shipping')), 200);
  });

  test('Harborview keeps its four streets and the other cities open', () {
    final game = IslandGame(seed: 1);
    expect(game.cities.map((c) => c.name), [
      'Harborview',
      'Ironridge',
      'Greenvale',
    ]);
    expect(game.streetsOf('harborview').map((s) => s.name), [
      'The Docks',
      'Main Street',
      'Old Town',
      'Edge Road',
    ]);
    expect(game.streetsOf('ironridge').map((s) => s.name), [
      'The Pit',
      'Rail Row',
      'Camp Road',
    ]);
    expect(game.streetsOf('greenvale').map((s) => s.name), [
      'Mill Road',
      'River Lane',
      'Orchard',
    ]);
    expect(game.investors.map((i) => i.id), [
      'you',
      'rita',
      'omar',
      'mei',
      'dex',
      'tara',
      'vik',
    ]);
  });

  test('a city buyback pays 95 percent', () {
    final game = IslandGame(seed: 4);
    final target = game.plots.firstWhere(
      (plot) =>
          plot.ownerId == null && game.cityIdOf(plot.streetId) == 'ironridge',
    );
    expect(game.buy('you', target.id).ok, isTrue);
    final price = game.priceOf(target);
    final before = game.investor('you').cash;
    expect(game.sell('you', target.id).ok, isTrue);
    expect(game.investor('you').cash - before, closeTo(price * 0.95, 1e-9));
  });

  test('share orders fill on the next tick and stop at 20 percent', () {
    final game = IslandGame(seed: 2);
    expect(
      game.placeShareOrder('you', 'harbor-shipping', buy: true, shares: 210).ok,
      isFalse,
    );
    expect(
      game.placeShareOrder('you', 'harbor-shipping', buy: true, shares: 200).ok,
      isTrue,
    );
    expect(game.sharesHeld('you', 'harbor-shipping'), 0);
    final before = game.investor('you').cash;
    game.next();
    final held = game.sharesHeld('you', 'harbor-shipping');
    final spent = before - game.investor('you').cash;
    expect(held, greaterThan(0));
    expect(held, lessThanOrEqualTo(200));
    expect(
      spent,
      closeTo(
          held *
              game.company('harbor-shipping').lastAsk *
              (1 + Tuning.shareFee),
          1e-6),
    );
    final room = 200 - held;
    expect(
      game
          .placeShareOrder('you', 'harbor-shipping',
              buy: true, shares: room + 1)
          .ok,
      isFalse,
    );
    if (room > 0) {
      expect(
        game
            .placeShareOrder('you', 'harbor-shipping', buy: true, shares: room)
            .ok,
        isTrue,
      );
    }
  });

  test('the slow day lands on every fourth tick', () {
    final game = IslandGame(seed: 5);
    final target = game.plots.firstWhere(
      (plot) =>
          plot.ownerId == null &&
          plot.building == null &&
          game.cityIdOf(plot.streetId) == 'harborview',
    );
    expect(game.buy('you', target.id).ok, isTrue);
    expect(game.build('you', target.id, BuildingType.parking).ok, isTrue);
    for (var i = 0; i < 3; i++) {
      game.next();
    }
    expect(game.day, 1);
    expect(game.tick, 4);
    expect(
        game.ledger.where((e) => e.plotId == target.id && e.kind == 'earned'),
        isEmpty);
    game.next();
    expect(game.day, 2);
    expect(game.tick, 1);
    expect(
        game.ledger.where((e) => e.plotId == target.id && e.kind == 'earned'),
        isEmpty);
    for (var i = 0; i < 4; i++) {
      game.next();
    }
    expect(game.day, 3);
    expect(
      game.ledger.where((e) => e.plotId == target.id && e.kind == 'earned'),
      isNotEmpty,
    );
  });

  test('zoning follows the city', () {
    final game = IslandGame(seed: 1);
    final orchard =
        game.plots.firstWhere((plot) => plot.streetId == 'gv-orchard');
    final shaft = game.plots.firstWhere((plot) => plot.streetId == 'ir-pit');
    final pier = game.plots.firstWhere((plot) => plot.streetId == 'hv-docks');
    expect(game.buildAllowed(orchard, BuildingType.carWash), isFalse);
    expect(game.buildAllowed(orchard, BuildingType.farmStand), isTrue);
    expect(game.buildAllowed(shaft, BuildingType.warehouse), isFalse);
    expect(game.buildAllowed(shaft, BuildingType.diner), isTrue);
    expect(game.buildAllowed(pier, BuildingType.warehouse), isTrue);
    expect(game.buildAllowed(pier, BuildingType.diner), isFalse);
  });

  test('the same seed plays the same island', () {
    final left = IslandGame(seed: 7);
    final right = IslandGame(seed: 7);
    expect(
      left.plots.map((p) => p.baseTraffic).toList(),
      right.plots.map((p) => p.baseTraffic).toList(),
    );
    for (var i = 0; i < 8; i++) {
      left.next();
      right.next();
    }
    expect(left.company('ironridge-mining').price,
        right.company('ironridge-mining').price);
    expect(left.investor('you').cash, right.investor('you').cash);
    expect(
        left.city('greenvale').population, right.city('greenvale').population);
  });

  test('Ironridge can open a street and the season ends on day 40', () {
    final game = IslandGame(seed: 3);
    for (var i = 0; i < 159; i++) {
      game.next();
    }
    expect(game.finished, isFalse);
    game.next();
    expect(game.finished, isTrue);
    expect(game.day, 40);
    expect(
        game.streetsOf('ironridge').map((s) => s.name), contains('Vein Road'));
    expect(game.placeShareOrder('you', 'harbor-bank', buy: true, shares: 10).ok,
        isFalse);
  });
}
