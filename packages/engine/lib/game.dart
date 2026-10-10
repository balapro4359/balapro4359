import 'dart:math';

import 'pricing.dart';
import 'tuning.dart';

/// Provisional choices that let the solo app run. They are not locked rules.
/// See docs/DECISIONS.md, "Provisional, so the app can play".
///
/// Settlement of a day, when the player taps Next:
/// income, census, resolve due rumors, shorten effects that were already
/// running, update street multipliers, then advance the day, announce a rumor
/// if one is due, then bots sell and maybe act.
/// A building earns on settlements after the day it was built.
/// Starting demand is 0. Jitter ranges are inclusive. Draws are uniform.
/// Bots start with the same cash as the player. Halfway dollars round away
/// from zero. The day-1 forced buy skips the act roll and, if the normal
/// buy rule cannot pick, buys the cheapest plot that fits the buffer.

class LedgerEntry {
  const LedgerEntry({
    required this.day,
    required this.kind,
    required this.message,
    this.investorId,
    this.plotId,
    this.amount,
  });

  final int day;
  final String kind;
  final String message;
  final String? investorId;
  final String? plotId;
  final double? amount;
}

class ActionResult {
  const ActionResult({required this.ok, this.reason, this.events = const []});

  final bool ok;
  final String? reason;
  final List<LedgerEntry> events;
}

class Investor {
  Investor({
    required this.id,
    required this.name,
    required this.style,
    required this.isBot,
    required this.actChance,
  });

  final String id;
  final String name;
  final String style;
  final bool isBot;
  final double actChance;
  double cash = Tuning.startingCash;
  double totalEarned = 0;
  double bestSale = 0;
  final List<double> netWorth = [];
}

class TempShift {
  TempShift(this.amount, this.daysLeft);
  final double amount;
  int daysLeft;
}

class Plot {
  Plot({
    required this.id,
    required this.name,
    required this.streetId,
    required this.baseTraffic,
  });

  final String id;
  final String name;
  final String streetId;
  double baseTraffic;
  String? ownerId;
  BuildingType? building;
  int? builtOnDay;
  int closureDays = 0;
  double invested = 0;
  double displayNoise = 0;
  int? lastCensusMove;
  final List<TempShift> temps = [];

  double get currentTraffic {
    var extra = 0.0;
    for (final temp in temps) {
      if (temp.daysLeft > 0) extra += temp.amount;
    }
    return clampDouble(
      baseTraffic + extra,
      Tuning.trafficMin,
      Tuning.trafficMax,
    );
  }
}

class Street {
  Street({required this.id, required this.name, required this.baseTraffic});

  final String id;
  final String name;
  final double baseTraffic;
  double multiplier = Tuning.multiplierStart;
  double demand = 0;
  final List<double> history = [Tuning.multiplierStart];
  Rumor? rumor;
}

class Rumor {
  Rumor({
    required this.spec,
    required this.announcedOn,
    required this.decidesOn,
  });

  final EventSpec spec;
  final int announcedOn;
  final int decidesOn;
  bool? happened;
}

class EventSpec {
  const EventSpec({
    required this.id,
    required this.name,
    required this.streetName,
    required this.good,
    required this.chance,
    required this.permanent,
    required this.amount,
    this.tempDays,
    this.closureDays,
    required this.rumor,
    required this.happenedLine,
    required this.missedLine,
  });

  final String id;
  final String name;
  final String streetName;
  final bool good;
  final double chance;
  final bool permanent;
  final double amount;
  final int? tempDays;
  final int? closureDays;
  final String rumor;
  final String happenedLine;
  final String missedLine;
}

const eventDeck = <EventSpec>[
  EventSpec(
    id: 'ferry',
    name: 'Ferry terminal',
    streetName: 'The Docks',
    good: true,
    chance: 0.60,
    permanent: true,
    amount: 20,
    rumor: 'The port authority is weighing a ferry terminal on the docks.',
    happenedLine: 'Ferry terminal approved. Dock traffic is up for good.',
    missedLine: 'Ferry terminal plan shelved.',
  ),
  EventSpec(
    id: 'storm',
    name: 'Storm flood',
    streetName: 'The Docks',
    good: false,
    chance: 0.50,
    permanent: false,
    amount: -30,
    tempDays: 6,
    closureDays: 4,
    rumor: 'Forecasters are tracking a storm that could flood the docks.',
    happenedLine:
        'The storm floods the docks. Traffic drops and the buildings close.',
    missedLine: 'The storm misses the harbor.',
  ),
  EventSpec(
    id: 'highway',
    name: 'Highway exit',
    streetName: 'Edge Road',
    good: true,
    chance: 0.45,
    permanent: true,
    amount: 28,
    rumor: 'The county is considering a highway exit on Edge Road.',
    happenedLine: 'Highway exit approved. Edge Road traffic is up for good.',
    missedLine: 'Highway exit plan shelved.',
  ),
  EventSpec(
    id: 'repaving',
    name: 'Repaving',
    streetName: 'Main Street',
    good: false,
    chance: 0.75,
    permanent: false,
    amount: -32,
    tempDays: 6,
    rumor: 'Main Street may be torn up for repaving.',
    happenedLine: 'Repaving starts. Main Street traffic is down for a while.',
    missedLine: 'The repaving plan was postponed.',
  ),
  EventSpec(
    id: 'market',
    name: 'Market hall',
    streetName: 'Old Town',
    good: true,
    chance: 0.55,
    permanent: true,
    amount: 16,
    rumor: 'The council is weighing a market hall in Old Town.',
    happenedLine: 'Market hall approved. Old Town traffic is up for good.',
    missedLine: 'Market hall plan shelved.',
  ),
  EventSpec(
    id: 'yard',
    name: 'Shipping yard leaves',
    streetName: 'The Docks',
    good: false,
    chance: 0.40,
    permanent: true,
    amount: -14,
    rumor: 'Word is the shipping yard may leave the docks.',
    happenedLine: 'The shipping yard is leaving. Dock traffic is down for good.',
    missedLine: 'The shipping yard is staying.',
  ),
  EventSpec(
    id: 'arena',
    name: 'Sports arena',
    streetName: 'Main Street',
    good: true,
    chance: 0.50,
    permanent: true,
    amount: 12,
    rumor: 'A sports arena is proposed beside Main Street.',
    happenedLine: 'Sports arena approved. Main Street traffic is up for good.',
    missedLine: 'Sports arena plan shelved.',
  ),
  EventSpec(
    id: 'mill',
    name: 'Mill closes',
    streetName: 'Old Town',
    good: false,
    chance: 0.45,
    permanent: true,
    amount: -12,
    rumor: 'The mill in Old Town may close.',
    happenedLine: 'The mill has closed. Old Town traffic is down for good.',
    missedLine: 'The mill is staying open.',
  ),
];

class HoldingsGame {
  HoldingsGame({this.seed = 1}) : _random = Random(seed) {
    _buildTown();
    _placeStartingLots();
    _rollNoise();
    _bots(forced: true);
    _recordNetWorth();
  }

  final int seed;
  final Random _random;
  final streets = <Street>[];
  final plots = <Plot>[];
  final investors = <Investor>[];
  final ledger = <LedgerEntry>[];
  final lastIncome = <String, double>{};
  var day = 1;
  var finished = false;
  var _nextRumorDay = Tuning.firstRumorDay;
  final _deck = <EventSpec>[];

  Investor investor(String id) => investors.firstWhere((i) => i.id == id);

  Plot plot(String id) => plots.firstWhere((p) => p.id == id);

  Street streetOf(Plot plot) => streets.firstWhere((s) => s.id == plot.streetId);

  int ownedCount(String investorId) =>
      plots.where((p) => p.ownerId == investorId).length;

  bool earning(Plot plot) =>
      plot.building != null &&
      plot.closureDays == 0 &&
      plot.builtOnDay != null &&
      day > plot.builtOnDay!;

  double incomeOf(Plot plot) => businessIncome(
        building: plot.building,
        traffic: plot.currentTraffic,
        openForBusiness: earning(plot),
      );

  int priceOf(Plot plot) => plotValue(
        traffic: plot.currentTraffic,
        multiplier: streetOf(plot).multiplier,
        building: plot.building,
        dailyIncome: incomeOf(plot),
      );

  int landOf(Plot plot) => landPrice(
        traffic: plot.currentTraffic,
        multiplier: streetOf(plot).multiplier,
      );

  double carsADay(Plot plot) =>
      plot.currentTraffic * Tuning.carsPerTraffic * (1 + plot.displayNoise);

  double netWorthOf(String investorId) {
    final person = investor(investorId);
    var total = person.cash;
    for (final plot in plots) {
      if (plot.ownerId == investorId) total += priceOf(plot);
    }
    return total;
  }

  double? streetChange(String streetId, int daysBack) {
    final street = streets.firstWhere((s) => s.id == streetId);
    return percentChange(street.history, daysBack);
  }

  int rankOf(String investorId) {
    final ordered = [...investors]..sort((a, b) {
        final byWorth = netWorthOf(b.id).compareTo(netWorthOf(a.id));
        if (byWorth != 0) return byWorth;
        return a.id.compareTo(b.id);
      });
    return ordered.indexWhere((i) => i.id == investorId) + 1;
  }

  int streetsHeld(String investorId) {
    return plots
        .where((p) => p.ownerId == investorId)
        .map((p) => p.streetId)
        .toSet()
        .length;
  }

  ActionResult buy(String investorId, String plotId) {
    final person = investor(investorId);
    final target = plot(plotId);
    if (finished) return const ActionResult(ok: false, reason: 'The season is over.');
    if (target.ownerId != null) {
      return const ActionResult(ok: false, reason: 'That plot is owned.');
    }
    final price = priceOf(target);
    if (person.cash + 1e-6 < price) {
      return const ActionResult(ok: false, reason: 'Not enough cash.');
    }
    person.cash -= price;
    target.ownerId = investorId;
    target.invested = price.toDouble();
    streetOf(target).demand += Tuning.buyDemand;
    final entry = LedgerEntry(
      day: day,
      kind: 'bought',
      message: '${person.name} bought ${target.name} for \$$price.',
      investorId: investorId,
      plotId: plotId,
      amount: price.toDouble(),
    );
    ledger.add(entry);
    return ActionResult(ok: true, events: [entry]);
  }

  ActionResult build(String investorId, String plotId, BuildingType type) {
    final person = investor(investorId);
    final target = plot(plotId);
    if (finished) return const ActionResult(ok: false, reason: 'The season is over.');
    if (target.ownerId != investorId) {
      return const ActionResult(ok: false, reason: 'You do not own that plot.');
    }
    if (target.building != null) {
      return const ActionResult(ok: false, reason: 'Something is already built there.');
    }
    final cost = buildingCost(type);
    if (person.cash + 1e-6 < cost) {
      return const ActionResult(ok: false, reason: 'Not enough cash to build.');
    }
    person.cash -= cost;
    target.building = type;
    target.builtOnDay = day;
    target.invested += cost;
    final label = type == BuildingType.carWash ? 'a car wash' : 'a parking lot';
    final entry = LedgerEntry(
      day: day,
      kind: 'bought',
      message: '${person.name} built $label on ${target.name}.',
      investorId: investorId,
      plotId: plotId,
      amount: cost,
    );
    ledger.add(entry);
    return ActionResult(ok: true, events: [entry]);
  }

  ActionResult sell(String investorId, String plotId) {
    final person = investor(investorId);
    final target = plot(plotId);
    if (finished) return const ActionResult(ok: false, reason: 'The season is over.');
    if (target.ownerId != investorId) {
      return const ActionResult(ok: false, reason: 'You do not own that plot.');
    }
    final price = priceOf(target);
    final proceeds = saleProceeds(price);
    person.cash += proceeds;
    if (proceeds > person.bestSale) person.bestSale = proceeds;
    target.ownerId = null;
    target.invested = 0;
    streetOf(target).demand += Tuning.sellDemand;
    final entry = LedgerEntry(
      day: day,
      kind: 'sold',
      message: '${person.name} sold ${target.name} for \$${proceeds.round()}.',
      investorId: investorId,
      plotId: plotId,
      amount: proceeds,
    );
    ledger.add(entry);
    return ActionResult(ok: true, events: [entry]);
  }

  List<LedgerEntry> nextDay() {
    if (finished) return const [];
    final start = ledger.length;
    lastIncome.clear();
    _payIncome();
    if (day % 7 == 0) _census();
    _tickEffects();
    _resolveRumors();
    _updateStreets();
    if (day >= Tuning.soloSeasonDays) {
      finished = true;
      _recordNetWorth();
      return ledger.sublist(start);
    }
    day += 1;
    _announceRumor();
    _bots(forced: false);
    _rollNoise();
    _recordNetWorth();
    return ledger.sublist(start);
  }

  void _buildTown() {
    const layout = [
      ('docks', 'The Docks', 55.0, ['Pier 1', 'Pier 2', 'Pier 3', 'Pier 4', 'Pier 5']),
      ('main', 'Main Street', 72.0, ['101 Main', '115 Main', '130 Main', '144 Main', '160 Main']),
      ('old', 'Old Town', 42.0, ['Chapel Ln', 'Mill Row', 'Bell Ct', 'Tanner St', 'Well Sq']),
      ('edge', 'Edge Road', 22.0, ['Lot 1', 'Lot 2', 'Lot 3', 'Lot 4', 'Lot 5']),
    ];
    for (final row in layout) {
      final street = Street(id: row.$1, name: row.$2, baseTraffic: row.$3);
      streets.add(street);
      for (final name in row.$4) {
        final jitter = _int(-Tuning.trafficStartJitter, Tuning.trafficStartJitter);
        plots.add(
          Plot(
            id: '${street.id}-${name.toLowerCase().replaceAll(' ', '-')}',
            name: name,
            streetId: street.id,
            baseTraffic: clampDouble(
              street.baseTraffic + jitter,
              Tuning.trafficStartMin,
              Tuning.trafficStartMax,
            ),
          ),
        );
      }
    }
    investors.addAll([
      Investor(id: 'you', name: 'You', style: 'Investor', isBot: false, actChance: 0),
      Investor(id: 'rita', name: 'Rita', style: 'Follows the crowd', isBot: true, actChance: Tuning.ritaAct),
      Investor(id: 'omar', name: 'Omar', style: 'Counts cars', isBot: true, actChance: Tuning.omarAct),
      Investor(id: 'mei', name: 'Mei', style: 'Spreads bets', isBot: true, actChance: Tuning.meiAct),
      Investor(id: 'dex', name: 'Dex', style: 'Sells on bad news', isBot: true, actChance: Tuning.dexAct),
    ]);
    _refillDeck();
  }

  void _placeStartingLots() {
    final eligible = plots.where((p) => p.streetId != 'edge').toList()..shuffle(_random);
    for (final plot in eligible.take(Tuning.startingParkingLots)) {
      plot.building = BuildingType.parking;
      plot.builtOnDay = 0;
    }
  }

  void _payIncome() {
    for (final plot in plots) {
      if (plot.ownerId == null || plot.building == null) continue;
      final amount = incomeOf(plot);
      if (!earning(plot)) continue;
      final person = investor(plot.ownerId!);
      person.cash += amount;
      person.totalEarned += amount;
      lastIncome[plot.id] = amount;
      if (amount == 0) continue;
      final verb = amount >= 0 ? 'earned' : 'lost';
      ledger.add(
        LedgerEntry(
          day: day,
          kind: 'earned',
          message: '${plot.name} $verb \$${amount.abs().toStringAsFixed(0)}.',
          investorId: person.id,
          plotId: plot.id,
          amount: amount,
        ),
      );
    }
  }

  void _census() {
    for (final plot in plots) {
      final move = _int(-5, 5);
      plot.baseTraffic += move.toDouble();
      plot.lastCensusMove = move;
    }
  }

  void _resolveRumors() {
    for (final street in streets) {
      final rumor = street.rumor;
      if (rumor == null || rumor.decidesOn != day || rumor.happened != null) {
        continue;
      }
      final happens = _random.nextDouble() < rumor.spec.chance;
      rumor.happened = happens;
      if (happens) {
        _applyEffect(street, rumor.spec);
        street.demand += rumor.spec.good
            ? Tuning.happenGoodDemand
            : Tuning.happenBadDemand;
      } else {
        street.demand += rumor.spec.good
            ? Tuning.missGoodDemand
            : Tuning.missBadDemand;
      }
      ledger.add(
        LedgerEntry(
          day: day,
          kind: 'rumorDecided',
          message: happens ? rumor.spec.happenedLine : rumor.spec.missedLine,
          plotId: street.id,
        ),
      );
      street.rumor = null;
    }
  }

  void _applyEffect(Street street, EventSpec spec) {
    final targets = plots.where((p) => p.streetId == street.id);
    if (spec.permanent) {
      for (final plot in targets) {
        final jitter = _int(-Tuning.permanentJitter, Tuning.permanentJitter);
        plot.baseTraffic = clampDouble(
          plot.baseTraffic + spec.amount + jitter,
          Tuning.permanentBaseMin,
          Tuning.permanentBaseMax,
        );
      }
      return;
    }
    for (final plot in targets) {
      plot.temps.add(TempShift(spec.amount, spec.tempDays ?? 0));
      final closure = spec.closureDays ?? 0;
      if (closure > plot.closureDays) plot.closureDays = closure;
    }
  }

  void _tickEffects() {
    for (final plot in plots) {
      if (plot.closureDays > 0) plot.closureDays -= 1;
      for (final temp in plot.temps) {
        if (temp.daysLeft > 0) temp.daysLeft -= 1;
      }
      plot.temps.removeWhere((temp) => temp.daysLeft <= 0);
    }
  }

  void _updateStreets() {
    for (final street in streets) {
      final noise = _range(-Tuning.multiplierNoise, Tuning.multiplierNoise);
      final next = updateStreet(
        multiplier: street.multiplier,
        demand: street.demand,
        noise: noise,
      );
      street.multiplier = next.multiplier;
      street.demand = next.demand;
      street.history.add(street.multiplier);
    }
  }

  void _announceRumor() {
    if (day != _nextRumorDay) return;
    if (_deck.isEmpty) _refillDeck();
    EventSpec? chosen;
    final skipped = <EventSpec>[];
    while (_deck.isNotEmpty) {
      final spec = _deck.removeAt(0);
      final street = streets.firstWhere((s) => s.name == spec.streetName);
      if (street.rumor != null) {
        skipped.add(spec);
        continue;
      }
      chosen = spec;
      break;
    }
    _deck.insertAll(0, skipped);
    if (chosen == null) {
      _nextRumorDay = day + 1;
      return;
    }
    final delay = _int(3, 5);
    final gap = _int(4, 6);
    final street = streets.firstWhere((s) => s.name == chosen!.streetName);
    street.rumor = Rumor(
      spec: chosen,
      announcedOn: day,
      decidesOn: day + delay,
    );
    street.demand += chosen.good
        ? Tuning.announceGoodDemand
        : Tuning.announceBadDemand;
    _nextRumorDay = day + gap;
    ledger.add(
      LedgerEntry(
        day: day,
        kind: 'rumorAnnounced',
        message: chosen.rumor,
        plotId: street.id,
      ),
    );
  }

  void _refillDeck() {
    _deck
      ..clear()
      ..addAll(eventDeck)
      ..shuffle(_random);
  }

  void _bots({required bool forced}) {
    for (final person in investors.where((i) => i.isBot)) {
      _botSell(person);
      final acts = forced || _random.nextDouble() < person.actChance;
      if (!acts) continue;
      _botBuy(person, forced: forced);
      _botBuild(person);
    }
  }

  void _botSell(Investor person) {
    final owned = plots.where((p) => p.ownerId == person.id).toList();
    if (person.id == 'mei') return;
    if (person.id == 'rita') {
      for (final plot in owned) {
        final change = streetChange(plot.streetId, 2);
        if (change != null && change < Tuning.ritaSellFall) {
          sell(person.id, plot.id);
        }
      }
      return;
    }
    if (person.id == 'omar') {
      for (final plot in owned) {
        if (plot.building == null) continue;
        if (incomeOf(plot) < Tuning.omarSellIncome && _random.nextDouble() < 0.5) {
          sell(person.id, plot.id);
        }
      }
      return;
    }
    for (final plot in owned) {
      final rumor = streetOf(plot).rumor;
      if (rumor != null && !rumor.spec.good && rumor.happened == null) {
        sell(person.id, plot.id);
      }
    }
  }

  void _botBuy(Investor person, {required bool forced}) {
    if (ownedCount(person.id) >= Tuning.botMaxPlots) return;
    final choice = switch (person.id) {
      'rita' => _ritaBuy() ?? (forced ? _cheapestAffordable(person) : null),
      'omar' => _highestTraffic(person),
      'mei' => _meiBuy(person),
      'dex' => _randomAffordable(person),
      _ => null,
    };
    if (choice == null) return;
    buy(person.id, choice.id);
  }

  void _botBuild(Investor person) {
    final empty = plots
        .where((p) => p.ownerId == person.id && p.building == null)
        .toList();
    if (empty.isEmpty) return;
    empty.sort((a, b) => b.currentTraffic.compareTo(a.currentTraffic));
    final target = empty.first;
    BuildingType preferred;
    if (person.id == 'mei') {
      preferred = BuildingType.parking;
    } else if (person.id == 'omar') {
      preferred = target.currentTraffic > Tuning.omarCarWashTraffic
          ? BuildingType.carWash
          : BuildingType.parking;
    } else if (person.id == 'dex') {
      preferred = _random.nextBool() ? BuildingType.carWash : BuildingType.parking;
    } else {
      preferred = BuildingType.carWash;
    }
    if (_canBuild(person, preferred)) {
      build(person.id, target.id, preferred);
      return;
    }
    if (preferred != BuildingType.parking && _canBuild(person, BuildingType.parking)) {
      build(person.id, target.id, BuildingType.parking);
    }
  }

  bool _canBuild(Investor person, BuildingType type) =>
      person.cash + 1e-6 >= buildingCost(type) + Tuning.botBuildBuffer;

  bool _canAfford(Investor person, Plot plot) =>
      plot.ownerId == null &&
      ownedCount(person.id) < Tuning.botMaxPlots &&
      person.cash - priceOf(plot) + 1e-6 >= Tuning.botBuyBuffer;

  Plot? _ritaBuy() {
    String? bestStreet;
    var best = Tuning.ritaBuyRise;
    for (final street in streets) {
      final change = streetChange(street.id, 3);
      if (change != null && change > best) {
        best = change;
        bestStreet = street.id;
      }
    }
    if (bestStreet == null) return null;
    final person = investor('rita');
    final options = plots
        .where((p) => p.streetId == bestStreet && _canAfford(person, p))
        .toList();
    if (options.isEmpty) return null;
    options.sort((a, b) => priceOf(a).compareTo(priceOf(b)));
    return options.first;
  }

  Plot? _meiBuy(Investor person) {
    final ownedStreets = plots
        .where((p) => p.ownerId == person.id)
        .map((p) => p.streetId)
        .toSet();
    final options = plots
        .where((p) => !ownedStreets.contains(p.streetId) && _canAfford(person, p))
        .toList();
    if (options.isEmpty) return null;
    options.sort((a, b) => priceOf(a).compareTo(priceOf(b)));
    return options.first;
  }

  Plot? _highestTraffic(Investor person) {
    final options = plots.where((p) => _canAfford(person, p)).toList();
    if (options.isEmpty) return null;
    options.sort((a, b) => b.currentTraffic.compareTo(a.currentTraffic));
    return options.first;
  }

  Plot? _cheapestAffordable(Investor person) {
    final options = plots.where((p) => _canAfford(person, p)).toList();
    if (options.isEmpty) return null;
    options.sort((a, b) => priceOf(a).compareTo(priceOf(b)));
    return options.first;
  }

  Plot? _randomAffordable(Investor person) {
    final options = plots.where((p) => _canAfford(person, p)).toList();
    if (options.isEmpty) return null;
    return options[_random.nextInt(options.length)];
  }

  void _rollNoise() {
    for (final plot in plots) {
      plot.displayNoise = _range(-Tuning.carsNoise, Tuning.carsNoise);
    }
  }

  void _recordNetWorth() {
    for (final person in investors) {
      person.netWorth.add(netWorthOf(person.id));
    }
  }

  int _int(int min, int max) => min + _random.nextInt(max - min + 1);

  double _range(double min, double max) => min + _random.nextDouble() * (max - min);
}
