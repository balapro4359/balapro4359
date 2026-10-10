import 'dart:math';

import 'game.dart';
import 'pricing.dart';
import 'tuning.dart';

/// Solo island. Appendix A stays in [HoldingsGame].
///
/// Next is one fast tick. Every fourth fast tick is a slow day: income,
/// rent, dividends, taxes, fundamentals, events. The season is 40 slow days.
/// City plots still sell back to the city at 95%. Share orders rest until
/// the next fast tick, then fill at that tick's price. One holder is capped
/// at 20% and pays a 0.5% fee. Every other figure is a starting value.

enum Leaning { proGrowth, steady, cautious }

class StreetPlan {
  const StreetPlan(this.id, this.name, this.baseTraffic, this.plots);
  final String id;
  final String name;
  final double baseTraffic;
  final List<String> plots;
}

class City {
  City({
    required this.id,
    required this.name,
    required this.character,
    required this.outputLabel,
    required this.population,
    required this.jobs,
    required this.output,
    required this.growth,
    required this.concentration,
    required this.leaning,
    required this.unlockAt,
    required this.waiting,
  })  : startPopulation = population,
        startOutput = output;

  final String id;
  final String name;
  final String character;
  final String outputLabel;
  double population;
  double jobs;
  double output;
  final double growth;
  double concentration;
  final Leaning leaning;
  final double unlockAt;
  final double startPopulation;
  final double startOutput;
  StreetPlan? waiting;
  double outputFactor = 1;
  int outputFactorDays = 0;

  double get employment {
    if (population <= 0) return 0;
    final rate = jobs / population;
    if (rate < 0) return 0;
    if (rate > 1) return 1;
    return rate;
  }

  double get effectiveOutput {
    if (outputFactorDays <= 0) return output;
    return output * outputFactor;
  }

  String get council {
    return switch (leaning) {
      Leaning.proGrowth => 'Pro-growth council',
      Leaning.steady => 'Steady council',
      Leaning.cautious => 'Cautious council',
    };
  }
}

class Company {
  Company({
    required this.id,
    required this.name,
    required this.cityId,
    required this.dividendYield,
    required this.price,
  }) : fundamental = price;

  final String id;
  final String name;
  final String cityId;
  final int sharesOutstanding = Tuning.sharesOutstanding;
  final double dividendYield;
  double price;
  double fundamental;
  double lastAsk = 0;
  double lastBid = 0;
  double lastDividend = 0;
  final history = <double>[];
  final holdings = <String, int>{};
}

class ShareOrder {
  const ShareOrder({
    required this.investorId,
    required this.companyId,
    required this.buy,
    required this.shares,
  });

  final String investorId;
  final String companyId;
  final bool buy;
  final int shares;
}

class _ShockSpec {
  const _ShockSpec({
    required this.id,
    required this.announceDay,
    required this.chance,
    required this.good,
    required this.rumor,
    required this.happenedLine,
    required this.missedLine,
    this.cityId,
  });

  final String id;
  final int announceDay;
  final double chance;
  final bool good;
  final String rumor;
  final String happenedLine;
  final String missedLine;
  final String? cityId;
}

class _Pending {
  _Pending({required this.spec, required this.decidesOn});
  final _ShockSpec spec;
  final int decidesOn;
  bool? happened;
}

class _Proposal {
  _Proposal(
      {required this.cityId, required this.decidesOn, required this.chance});
  final String cityId;
  final int decidesOn;
  final double chance;
  bool? passed;
}

const _shockDeck = <_ShockSpec>[
  _ShockSpec(
    id: 'vein',
    cityId: 'ironridge',
    announceDay: 5,
    chance: 0.50,
    good: true,
    rumor: 'Surveyors are talking about a new ore vein under Ironridge.',
    happenedLine:
        'A new vein opens. Ironridge ore jumps, and the town leans harder on the mine.',
    missedLine: 'The vein talk fades. The mine keeps its old seam.',
  ),
  _ShockSpec(
    id: 'drought',
    cityId: 'greenvale',
    announceDay: 9,
    chance: 0.50,
    good: false,
    rumor: 'Greenvale is watching a dry spell that could cut the harvest.',
    happenedLine:
        'The dry spell holds. Greenvale\'s harvest is down for a stretch.',
    missedLine: 'Rain arrives. The harvest scare passes.',
  ),
  _ShockSpec(
    id: 'thin',
    cityId: 'ironridge',
    announceDay: 20,
    chance: 0.40,
    good: false,
    rumor: 'The Ironridge seam looks thinner than the company said.',
    happenedLine: 'The seam is thinning. Ironridge ore falls.',
    missedLine: 'The seam holds. The thin-ore rumor was early.',
  ),
  _ShockSpec(
    id: 'crunch',
    announceDay: 16,
    chance: 0.35,
    good: false,
    rumor: 'Credit is tightening across the island. Prices may fall together.',
    happenedLine: 'Credit tightens. Prices fall in every city at once.',
    missedLine: 'The credit scare passes. Prices are left to the crowd.',
  ),
  _ShockSpec(
    id: 'bank',
    cityId: 'harborview',
    announceDay: 22,
    chance: 0.40,
    good: false,
    rumor: 'Depositors are nervous about Harbor Savings Bank.',
    happenedLine:
        'The bank scare hits. Harbor Savings shares drop, and the port feels it.',
    missedLine: 'The bank scare fades. Harbor Savings holds.',
  ),
];

const _ironEvents = <EventSpec>[
  EventSpec(
    id: 'spur',
    name: 'Rail spur',
    streetName: 'Rail Row',
    good: true,
    chance: 0.50,
    permanent: true,
    amount: 18,
    rumor: 'The railway is weighing a spur along Rail Row.',
    happenedLine: 'The rail spur is approved. Rail Row traffic is up for good.',
    missedLine: 'The rail spur was postponed.',
  ),
  EventSpec(
    id: 'fire',
    name: 'Headframe fire',
    streetName: 'The Pit',
    good: false,
    chance: 0.40,
    permanent: false,
    amount: -24,
    tempDays: 5,
    closureDays: 3,
    rumor: 'A headframe fire is a risk at the pit.',
    happenedLine:
        'A fire closes the pit head. Traffic drops and the buildings shut.',
    missedLine: 'The fire watch stands down.',
  ),
  EventSpec(
    id: 'camp',
    name: 'Camp expansion',
    streetName: 'Camp Road',
    good: true,
    chance: 0.55,
    permanent: true,
    amount: 14,
    rumor: 'The mine may add beds along Camp Road.',
    happenedLine: 'The camp expands. Camp Road traffic is up for good.',
    missedLine: 'The camp expansion was shelved.',
  ),
];

const _greenEvents = <EventSpec>[
  EventSpec(
    id: 'plant',
    name: 'Food plant',
    streetName: 'River Lane',
    good: true,
    chance: 0.50,
    permanent: true,
    amount: 16,
    rumor: 'A food plant is proposed on River Lane.',
    happenedLine:
        'The food plant is approved. River Lane traffic is up for good.',
    missedLine: 'The food plant plan was shelved.',
  ),
  EventSpec(
    id: 'blight',
    name: 'Crop blight',
    streetName: 'Orchard',
    good: false,
    chance: 0.45,
    permanent: false,
    amount: -20,
    tempDays: 6,
    rumor: 'A blight may be spreading through the orchard.',
    happenedLine: 'Blight reaches the orchard. Traffic is down for a while.',
    missedLine: 'The blight stays out of the orchard.',
  ),
  EventSpec(
    id: 'festival',
    name: 'Harvest festival',
    streetName: 'Mill Road',
    good: true,
    chance: 0.60,
    permanent: false,
    amount: 12,
    tempDays: 4,
    rumor: 'Mill Road may host the harvest festival.',
    happenedLine:
        'The festival opens on Mill Road. Traffic is up for a few days.',
    missedLine: 'The festival moved to a private field.',
  ),
];

class IslandGame {
  IslandGame({this.seed = 1}) : _random = Random(seed) {
    _build();
    _placeStartingLots();
    _rollNoise();
    _landBots(forced: true);
    _recordNetWorth();
  }

  final int seed;
  final Random _random;
  final cities = <City>[];
  final streets = <Street>[];
  final plots = <Plot>[];
  final companies = <Company>[];
  final investors = <Investor>[];
  final ledger = <LedgerEntry>[];
  final orders = <ShareOrder>[];
  final lastIncome = <String, double>{};
  final _cityOfStreet = <String, String>{};
  final _decks = <String, List<EventSpec>>{};
  final _nextRumorDay = <String, int>{};
  final _shocks = <_Pending>[];
  final _announcedShocks = <String>{};
  final _proposals = <_Proposal>[];
  final _announcedPolls = <int>{};
  var day = 1;
  var tick = 1;
  var finished = false;

  Investor investor(String id) => investors.firstWhere((i) => i.id == id);

  City city(String id) => cities.firstWhere((c) => c.id == id);

  Company company(String id) => companies.firstWhere((c) => c.id == id);

  Plot plot(String id) => plots.firstWhere((p) => p.id == id);

  Street streetOf(Plot plot) =>
      streets.firstWhere((s) => s.id == plot.streetId);

  String cityIdOf(String streetId) => _cityOfStreet[streetId]!;

  City cityOfPlot(Plot plot) => city(cityIdOf(plot.streetId));

  List<Street> streetsOf(String cityId) =>
      streets.where((s) => cityIdOf(s.id) == cityId).toList();

  List<Company> companiesOf(String cityId) =>
      companies.where((c) => c.cityId == cityId).toList();

  int ownedCount(String investorId) =>
      plots.where((p) => p.ownerId == investorId).length;

  int sharesHeld(String investorId, String companyId) =>
      company(companyId).holdings[investorId] ?? 0;

  ShareOrder? orderFor(String investorId, String companyId) {
    for (final order in orders) {
      if (order.investorId == investorId && order.companyId == companyId)
        return order;
    }
    return null;
  }

  bool cityHasNews(String cityId) {
    for (final street in streetsOf(cityId)) {
      if (street.rumor != null) return true;
    }
    for (final shock in _shocks) {
      if (shock.happened != null) continue;
      if (shock.spec.cityId == null || shock.spec.cityId == cityId) return true;
    }
    for (final poll in _proposals) {
      if (poll.passed == null && poll.cityId == cityId) return true;
    }
    return false;
  }

  bool earning(Plot plot) =>
      plot.building != null &&
      plot.closureDays == 0 &&
      plot.builtOnDay != null &&
      day > plot.builtOnDay!;

  double incomeOf(Plot plot) {
    final home = cityOfPlot(plot);
    return businessIncome(
      building: plot.building,
      traffic: plot.currentTraffic,
      openForBusiness: earning(plot),
      output: home.effectiveOutput,
      population: home.population,
      employment: home.employment,
    );
  }

  int priceOf(Plot target) => plotValue(
        traffic: target.currentTraffic,
        multiplier: streetOf(target).multiplier,
        building: target.building,
        dailyIncome: incomeOf(target),
      );

  int landOf(Plot target) => landPrice(
        traffic: target.currentTraffic,
        multiplier: streetOf(target).multiplier,
      );

  double carsADay(Plot target) =>
      target.currentTraffic * Tuning.carsPerTraffic * (1 + target.displayNoise);

  double? streetChange(String streetId, int daysBack) => percentChange(
      streets.firstWhere((s) => s.id == streetId).history, daysBack);

  double? shareChange(String companyId, int ticksBack) =>
      percentChange(company(companyId).history, ticksBack);

  double netWorthOf(String investorId) {
    final person = investor(investorId);
    var total = person.cash;
    for (final target in plots) {
      if (target.ownerId == investorId) total += priceOf(target);
    }
    for (final listed in companies) {
      total += (listed.holdings[investorId] ?? 0) * listed.price;
    }
    return total;
  }

  int rankOf(String investorId) {
    final ordered = [...investors]..sort((a, b) {
        final byWorth = netWorthOf(b.id).compareTo(netWorthOf(a.id));
        if (byWorth != 0) return byWorth;
        return a.id.compareTo(b.id);
      });
    return ordered.indexWhere((i) => i.id == investorId) + 1;
  }

  int streetsHeld(String investorId) => plots
      .where((p) => p.ownerId == investorId)
      .map((p) => p.streetId)
      .toSet()
      .length;

  int shareCapOf(Company listed) =>
      (listed.sharesOutstanding * Tuning.shareCap).round();

  double permitOf(Leaning leaning) => switch (leaning) {
        Leaning.proGrowth => Tuning.proGrowthPermit,
        Leaning.steady => Tuning.steadyPermit,
        Leaning.cautious => Tuning.cautiousPermit,
      };

  double propertyRate(Leaning leaning) => switch (leaning) {
        Leaning.proGrowth => Tuning.proGrowthPropertyTax,
        Leaning.steady => Tuning.steadyPropertyTax,
        Leaning.cautious => Tuning.cautiousPropertyTax,
      };

  double businessRate(Leaning leaning) => switch (leaning) {
        Leaning.proGrowth => Tuning.proGrowthBusinessTax,
        Leaning.steady => Tuning.steadyBusinessTax,
        Leaning.cautious => Tuning.cautiousBusinessTax,
      };

  double paceOf(Leaning leaning) => switch (leaning) {
        Leaning.proGrowth => Tuning.proGrowthPace,
        Leaning.steady => Tuning.steadyPace,
        Leaning.cautious => Tuning.cautiousPace,
      };

  bool buildAllowed(Plot target, BuildingType type) {
    final cityId = cityIdOf(target.streetId);
    final local = switch (type) {
      BuildingType.warehouse => cityId == 'harborview',
      BuildingType.diner => cityId == 'ironridge',
      BuildingType.silo || BuildingType.farmStand => cityId == 'greenvale',
      BuildingType.carWash ||
      BuildingType.parking ||
      BuildingType.house =>
        true,
    };
    if (!local) return false;
    if (cityId == 'greenvale' &&
        target.streetId == 'gv-orchard' &&
        type == BuildingType.carWash) {
      return false;
    }
    return true;
  }

  List<BuildingType> offersFor(Plot target) =>
      BuildingType.values.where((type) => buildAllowed(target, type)).toList();

  double buildCost(Plot target, BuildingType type) =>
      buildingCost(type) * permitOf(cityOfPlot(target).leaning);

  ActionResult buy(String investorId, String plotId) {
    final person = investor(investorId);
    final target = plot(plotId);
    if (finished)
      return const ActionResult(ok: false, reason: 'The season is over.');
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
    if (finished)
      return const ActionResult(ok: false, reason: 'The season is over.');
    if (target.ownerId != investorId) {
      return const ActionResult(ok: false, reason: 'You do not own that plot.');
    }
    if (target.building != null) {
      return const ActionResult(
          ok: false, reason: 'Something is already built there.');
    }
    if (!buildAllowed(target, type)) {
      return const ActionResult(
          ok: false, reason: 'The council does not allow that there.');
    }
    final cost = buildCost(target, type);
    if (person.cash + 1e-6 < cost) {
      return const ActionResult(ok: false, reason: 'Not enough cash to build.');
    }
    person.cash -= cost;
    target.building = type;
    target.builtOnDay = day;
    target.invested += cost;
    final entry = LedgerEntry(
      day: day,
      kind: 'bought',
      message: '${person.name} built ${_builtName(type)} on ${target.name}.',
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
    if (finished)
      return const ActionResult(ok: false, reason: 'The season is over.');
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

  ActionResult placeShareOrder(
    String investorId,
    String companyId, {
    required bool buy,
    required int shares,
  }) {
    final person = investor(investorId);
    if (finished)
      return const ActionResult(ok: false, reason: 'The season is over.');
    if (shares <= 0) {
      return const ActionResult(
          ok: false, reason: 'Choose at least one share.');
    }
    final listed = company(companyId);
    orders.removeWhere(
        (o) => o.investorId == investorId && o.companyId == companyId);
    final held = sharesHeld(investorId, companyId);
    if (buy) {
      final room = shareCapOf(listed) - held;
      if (held >= shareCapOf(listed) || room <= 0) {
        return const ActionResult(ok: false, reason: 'That is the 20% cap.');
      }
      if (shares > room) {
        return const ActionResult(
            ok: false, reason: 'That would pass the 20% cap.');
      }
    } else if (shares > held) {
      return const ActionResult(
          ok: false, reason: 'You do not hold that many shares.');
    }
    final order = ShareOrder(
      investorId: investorId,
      companyId: companyId,
      buy: buy,
      shares: shares,
    );
    orders.add(order);
    final side = buy ? 'buy' : 'sell';
    final entry = LedgerEntry(
      day: day,
      kind: 'order',
      message:
          '${person.name} put in an order to $side $shares shares of ${listed.name}. It fills on the next tick.',
      investorId: investorId,
      amount: shares.toDouble(),
    );
    ledger.add(entry);
    return ActionResult(ok: true, events: [entry]);
  }

  List<LedgerEntry> next() {
    if (finished) return const [];
    final start = ledger.length;
    _clearShares();
    _updateStreets();
    if (tick == Tuning.fastTicksPerSlowDay) {
      _slowDay();
      tick = 1;
    } else {
      tick += 1;
    }
    if (!finished) {
      _shareTraders();
      _recordNetWorth();
    }
    return ledger.sublist(start);
  }

  void _build() {
    final harbor = City(
      id: 'harborview',
      name: 'Harborview',
      character: 'Port and trade',
      outputLabel: 'Trade',
      population: Tuning.harborPopulation,
      jobs: Tuning.harborJobs,
      output: Tuning.harborOutput,
      growth: Tuning.harborGrowth,
      concentration: Tuning.harborConcentration,
      leaning: Leaning.steady,
      unlockAt: Tuning.harborUnlockPopulation,
      waiting:
          const StreetPlan('hv-wharf', 'New Wharf', Tuning.newWharfTraffic, [
        'Berth 1',
        'Berth 2',
        'Berth 3',
        'Berth 4',
        'Berth 5',
      ]),
    );
    final iron = City(
      id: 'ironridge',
      name: 'Ironridge',
      character: 'One mine, fast and fragile',
      outputLabel: 'Ore',
      population: Tuning.ironPopulation,
      jobs: Tuning.ironJobs,
      output: Tuning.ironOutput,
      growth: Tuning.ironGrowth,
      concentration: Tuning.ironConcentration,
      leaning: Leaning.proGrowth,
      unlockAt: Tuning.ironUnlockPopulation,
      waiting:
          const StreetPlan('ir-vein', 'Vein Road', Tuning.veinRoadTraffic, [
        'Cut 1',
        'Cut 2',
        'Cut 3',
        'Cut 4',
        'Cut 5',
      ]),
    );
    final green = City(
      id: 'greenvale',
      name: 'Greenvale',
      character: 'A farming valley, slow and steady',
      outputLabel: 'Harvest',
      population: Tuning.greenPopulation,
      jobs: Tuning.greenJobs,
      output: Tuning.greenOutput,
      growth: Tuning.greenGrowth,
      concentration: Tuning.greenConcentration,
      leaning: Leaning.cautious,
      unlockAt: Tuning.greenUnlockPopulation,
      waiting: const StreetPlan(
          'gv-field', 'South Field', Tuning.southFieldTraffic, [
        'Field 1',
        'Field 2',
        'Field 3',
        'Field 4',
        'Field 5',
      ]),
    );
    cities.addAll([harbor, iron, green]);
    _openStreet(
        harbor,
        const StreetPlan('hv-docks', 'The Docks', 55, [
          'Pier 1',
          'Pier 2',
          'Pier 3',
          'Pier 4',
          'Pier 5',
        ]));
    _openStreet(
        harbor,
        const StreetPlan('hv-main', 'Main Street', 72, [
          '101 Main',
          '115 Main',
          '130 Main',
          '144 Main',
          '160 Main',
        ]));
    _openStreet(
        harbor,
        const StreetPlan('hv-old', 'Old Town', 42, [
          'Chapel Ln',
          'Mill Row',
          'Bell Ct',
          'Tanner St',
          'Well Sq',
        ]));
    _openStreet(
        harbor,
        const StreetPlan('hv-edge', 'Edge Road', 22, [
          'Lot 1',
          'Lot 2',
          'Lot 3',
          'Lot 4',
          'Lot 5',
        ]));
    _openStreet(
        iron,
        const StreetPlan('ir-pit', 'The Pit', Tuning.ironPitTraffic, [
          'Shaft 1',
          'Shaft 2',
          'Shaft 3',
          'Shaft 4',
          'Shaft 5',
        ]));
    _openStreet(
        iron,
        const StreetPlan('ir-rail', 'Rail Row', Tuning.ironRailTraffic, [
          'Rail 1',
          'Rail 2',
          'Rail 3',
          'Rail 4',
          'Rail 5',
        ]));
    _openStreet(
        iron,
        const StreetPlan('ir-camp', 'Camp Road', Tuning.ironCampTraffic, [
          'Camp 1',
          'Camp 2',
          'Camp 3',
          'Camp 4',
          'Camp 5',
        ]));
    _openStreet(
        green,
        const StreetPlan('gv-mill', 'Mill Road', Tuning.greenMillTraffic, [
          'Mill 1',
          'Mill 2',
          'Mill 3',
          'Mill 4',
          'Mill 5',
        ]));
    _openStreet(
        green,
        const StreetPlan('gv-river', 'River Lane', Tuning.greenRiverTraffic, [
          'River 1',
          'River 2',
          'River 3',
          'River 4',
          'River 5',
        ]));
    _openStreet(
        green,
        const StreetPlan('gv-orchard', 'Orchard', Tuning.greenOrchardTraffic, [
          'Acre 1',
          'Acre 2',
          'Acre 3',
          'Acre 4',
          'Acre 5',
        ]));
    companies.addAll([
      _company('harbor-shipping', 'Harborview Shipping', harbor,
          Tuning.shippingYield),
      _company('harbor-bank', 'Harbor Savings Bank', harbor, Tuning.bankYield),
      _company(
          'ironridge-mining', 'Ironridge Mining', iron, Tuning.miningYield),
      _company(
          'greenvale-coop', 'Greenvale Farms Co-op', green, Tuning.coopYield),
    ]);
    investors.addAll([
      Investor(
          id: 'you',
          name: 'You',
          style: 'Investor',
          isBot: false,
          actChance: 0),
      Investor(
        id: 'rita',
        name: 'Rita',
        style: 'Follows the crowd',
        isBot: true,
        actChance: Tuning.ritaAct,
      ),
      Investor(
        id: 'omar',
        name: 'Omar',
        style: 'Reads fundamentals',
        isBot: true,
        actChance: Tuning.omarAct,
      ),
      Investor(
        id: 'mei',
        name: 'Mei',
        style: 'Diversifies',
        isBot: true,
        actChance: Tuning.meiAct,
      ),
      Investor(
        id: 'dex',
        name: 'Dex',
        style: 'Panics',
        isBot: true,
        actChance: Tuning.dexAct,
      ),
      Investor(
        id: 'tara',
        name: 'Tara',
        style: 'Day trader',
        isBot: true,
        actChance: Tuning.taraAct,
      ),
      Investor(
        id: 'vik',
        name: 'Vik',
        style: 'Contrarian',
        isBot: true,
        actChance: Tuning.vikAct,
      ),
    ]);
    _decks['harborview'] = [...eventDeck]..shuffle(_random);
    _decks['ironridge'] = [..._ironEvents]..shuffle(_random);
    _decks['greenvale'] = [..._greenEvents]..shuffle(_random);
    _nextRumorDay['harborview'] = Tuning.firstRumorDay;
    _nextRumorDay['ironridge'] = Tuning.ironFirstRumorDay;
    _nextRumorDay['greenvale'] = Tuning.greenFirstRumorDay;
  }

  Company _company(String id, String name, City home, double yield) {
    final listed = Company(
      id: id,
      name: name,
      cityId: home.id,
      dividendYield: yield,
      price: _fundamentalValue(id, home, Tuning.sharesOutstanding),
    );
    listed.history.add(listed.price);
    listed.lastAsk = listed.price * (1 + Tuning.shareSpread / 2);
    listed.lastBid = listed.price * (1 - Tuning.shareSpread / 2);
    return listed;
  }

  void _openStreet(City home, StreetPlan plan) {
    final street =
        Street(id: plan.id, name: plan.name, baseTraffic: plan.baseTraffic);
    streets.add(street);
    _cityOfStreet[street.id] = home.id;
    for (final name in plan.plots) {
      final jitter =
          _int(-Tuning.trafficStartJitter, Tuning.trafficStartJitter);
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

  void _placeStartingLots() {
    final harbor = plots
        .where((p) => p.streetId.startsWith('hv-') && p.streetId != 'hv-edge')
        .toList()
      ..shuffle(_random);
    for (final target in harbor.take(Tuning.startingParkingLots)) {
      target.building = BuildingType.parking;
      target.builtOnDay = 0;
    }
    final pit = plots
        .where((p) => p.streetId == 'ir-pit')
        .take(Tuning.ironStartingLots);
    final mill = plots
        .where((p) => p.streetId == 'gv-mill')
        .take(Tuning.greenStartingLots);
    for (final target in [...pit, ...mill]) {
      target.building = BuildingType.parking;
      target.builtOnDay = 0;
    }
  }

  void _slowDay() {
    lastIncome.clear();
    _payIncome();
    _payDividends();
    _chargePropertyTax();
    if (day % 7 == 0) _census();
    _tickEffects();
    _resolveRumors();
    _resolveShocks();
    _resolvePolls();
    _grow();
    _driftTraffic();
    _unlockStreets();
    if (day >= Tuning.soloSeasonDays) {
      finished = true;
      _recordNetWorth();
      return;
    }
    day += 1;
    _announceRumors();
    _announceShocks();
    _announcePolls();
    _landBots(forced: false);
  }

  void _payIncome() {
    final businessTax = <String, double>{};
    for (final target in plots) {
      if (target.ownerId == null || target.building == null) continue;
      final amount = incomeOf(target);
      if (!earning(target)) continue;
      final person = investor(target.ownerId!);
      person.cash += amount;
      person.totalEarned += amount;
      lastIncome[target.id] = amount;
      if (amount > 0) {
        final tax = amount * businessRate(cityOfPlot(target).leaning);
        person.cash -= tax;
        person.totalTax += tax;
        final key = '${person.id}|${cityIdOf(target.streetId)}';
        businessTax[key] = (businessTax[key] ?? 0) + tax;
      }
      if (amount == 0) continue;
      final verb = amount >= 0 ? 'earned' : 'lost';
      ledger.add(
        LedgerEntry(
          day: day,
          kind: 'earned',
          message: '${target.name} $verb \$${amount.abs().toStringAsFixed(0)}.',
          investorId: person.id,
          plotId: target.id,
          amount: amount,
        ),
      );
    }
    for (final entry in businessTax.entries) {
      if (entry.value == 0) continue;
      final parts = entry.key.split('|');
      final home = city(parts[1]);
      ledger.add(
        LedgerEntry(
          day: day,
          kind: 'tax',
          message:
              'Business tax in ${home.name} \$${entry.value.toStringAsFixed(0)}.',
          investorId: parts[0],
          amount: entry.value,
        ),
      );
    }
  }

  void _payDividends() {
    for (final listed in companies) {
      final perShare = listed.fundamental * listed.dividendYield;
      listed.lastDividend = perShare;
      if (perShare == 0) continue;
      for (final holder in listed.holdings.entries) {
        if (holder.value <= 0) continue;
        final amount = perShare * holder.value;
        final person = investor(holder.key);
        person.cash += amount;
        person.totalEarned += amount;
        ledger.add(
          LedgerEntry(
            day: day,
            kind: 'dividend',
            message:
                '${listed.name} paid \$${amount.toStringAsFixed(0)} on ${holder.value} shares.',
            investorId: person.id,
            amount: amount,
          ),
        );
      }
    }
  }

  void _chargePropertyTax() {
    final due = <String, double>{};
    for (final target in plots) {
      if (target.ownerId == null) continue;
      final home = cityOfPlot(target);
      final tax = priceOf(target) * propertyRate(home.leaning);
      final key = '${target.ownerId}|${home.id}';
      due[key] = (due[key] ?? 0) + tax;
    }
    for (final entry in due.entries) {
      final parts = entry.key.split('|');
      final person = investor(parts[0]);
      person.cash -= entry.value;
      person.totalTax += entry.value;
      ledger.add(
        LedgerEntry(
          day: day,
          kind: 'tax',
          message:
              'Property tax in ${city(parts[1]).name} \$${entry.value.toStringAsFixed(0)}.',
          investorId: person.id,
          amount: entry.value,
        ),
      );
    }
  }

  void _census() {
    for (final target in plots) {
      final move = _int(-5, 5);
      target.baseTraffic += move.toDouble();
      target.lastCensusMove = move;
    }
  }

  void _tickEffects() {
    for (final target in plots) {
      if (target.closureDays > 0) target.closureDays -= 1;
      for (final temp in target.temps) {
        if (temp.daysLeft > 0) temp.daysLeft -= 1;
      }
      target.temps.removeWhere((temp) => temp.daysLeft <= 0);
    }
    for (final home in cities) {
      if (home.outputFactorDays <= 0) continue;
      home.outputFactorDays -= 1;
      if (home.outputFactorDays == 0) home.outputFactor = 1;
    }
  }

  void _resolveRumors() {
    for (final street in streets) {
      final rumor = street.rumor;
      if (rumor == null || rumor.decidesOn != day || rumor.happened != null)
        continue;
      final happens = _random.nextDouble() < rumor.spec.chance;
      rumor.happened = happens;
      if (happens) {
        _applyStreet(street, rumor.spec);
        street.demand +=
            rumor.spec.good ? Tuning.happenGoodDemand : Tuning.happenBadDemand;
      } else {
        street.demand +=
            rumor.spec.good ? Tuning.missGoodDemand : Tuning.missBadDemand;
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

  void _applyStreet(Street street, EventSpec spec) {
    final targets = plots.where((p) => p.streetId == street.id);
    if (spec.permanent) {
      for (final target in targets) {
        final jitter = _int(-Tuning.permanentJitter, Tuning.permanentJitter);
        target.baseTraffic = clampDouble(
          target.baseTraffic + spec.amount + jitter,
          Tuning.permanentBaseMin,
          Tuning.permanentBaseMax,
        );
      }
      return;
    }
    for (final target in targets) {
      target.temps.add(TempShift(spec.amount, spec.tempDays ?? 0));
      final closure = spec.closureDays ?? 0;
      if (closure > target.closureDays) target.closureDays = closure;
    }
  }

  void _resolveShocks() {
    for (final shock in _shocks) {
      if (shock.happened != null || shock.decidesOn != day) continue;
      final happens = _random.nextDouble() < shock.spec.chance;
      shock.happened = happens;
      if (happens) _applyShock(shock.spec);
      ledger.add(
        LedgerEntry(
          day: day,
          kind: 'rumorDecided',
          message: happens ? shock.spec.happenedLine : shock.spec.missedLine,
        ),
      );
    }
  }

  void _applyShock(_ShockSpec spec) {
    switch (spec.id) {
      case 'vein':
        final home = city('ironridge');
        home.output *= Tuning.veinOutput;
        home.concentration = clampDouble(
          home.concentration + Tuning.veinConcentration,
          0.05,
          0.95,
        );
      case 'thin':
        final home = city('ironridge');
        home.output *= Tuning.thinOutput;
        home.concentration = clampDouble(
          home.concentration + Tuning.thinConcentration,
          0.05,
          0.95,
        );
      case 'drought':
        final home = city('greenvale');
        home.outputFactor = Tuning.droughtFactor;
        home.outputFactorDays = Tuning.droughtDays;
      case 'crunch':
        for (final street in streets) {
          street.demand += Tuning.crunchDemand;
        }
        for (final listed in companies) {
          listed.price *= Tuning.crunchPrice;
        }
      case 'bank':
        company('harbor-bank').price *= Tuning.bankScarePrice;
        for (final street in streetsOf('harborview')) {
          street.demand += Tuning.bankScareDemand;
        }
    }
  }

  void _resolvePolls() {
    for (final poll in _proposals) {
      if (poll.passed != null || poll.decidesOn != day) continue;
      final home = city(poll.cityId);
      final passed = _random.nextDouble() < poll.chance;
      poll.passed = passed;
      if (passed) {
        home.output *= 1 + Tuning.projectOutputBoost;
        for (final street in streetsOf(home.id)) {
          street.demand += Tuning.projectDemand;
        }
      } else {
        for (final street in streetsOf(home.id)) {
          street.demand += Tuning.projectMissDemand;
        }
      }
      ledger.add(
        LedgerEntry(
          day: day,
          kind: 'rumorDecided',
          message: passed
              ? '${home.name} approves the public project.'
              : '${home.name} votes the public project down.',
        ),
      );
    }
  }

  void _grow() {
    for (final home in cities) {
      final pace = paceOf(home.leaning);
      home.population *= 1 + home.growth * pace;
      home.jobs *= 1 + home.growth * pace * 0.9;
      home.output *= 1 + home.growth * pace;
      if (home.jobs > home.population) home.jobs = home.population;
      if (home.population < 100) home.population = 100;
      if (home.output < 1) home.output = 1;
    }
  }

  void _driftTraffic() {
    for (final target in plots) {
      final home = cityOfPlot(target);
      final street = streetOf(target);
      final scale = (home.output / home.startOutput) *
          sqrt(home.population / home.startPopulation);
      final aim = clampDouble(
        street.baseTraffic * scale,
        Tuning.permanentBaseMin,
        Tuning.permanentBaseMax,
      );
      target.baseTraffic += (aim - target.baseTraffic) * Tuning.trafficDrift;
    }
  }

  void _unlockStreets() {
    for (final home in cities) {
      final plan = home.waiting;
      if (plan == null || home.population < home.unlockAt) continue;
      _openStreet(home, plan);
      home.waiting = null;
      ledger.add(
        LedgerEntry(
          day: day,
          kind: 'rumorDecided',
          message: 'A new street opened in ${home.name}: ${plan.name}.',
        ),
      );
    }
  }

  void _announceRumors() {
    for (final home in cities) {
      if (day != _nextRumorDay[home.id]) continue;
      final deck = _decks[home.id]!;
      if (deck.isEmpty) _refill(home.id);
      EventSpec? chosen;
      final skipped = <EventSpec>[];
      while (deck.isNotEmpty) {
        final spec = deck.removeAt(0);
        final street =
            streetsOf(home.id).where((s) => s.name == spec.streetName);
        if (street.isEmpty) continue;
        if (street.first.rumor != null) {
          skipped.add(spec);
          continue;
        }
        chosen = spec;
        break;
      }
      deck.insertAll(0, skipped);
      if (chosen == null) {
        _nextRumorDay[home.id] = day + 1;
        continue;
      }
      final delay = _int(3, 5);
      final gap = _int(4, 6);
      final street =
          streetsOf(home.id).firstWhere((s) => s.name == chosen!.streetName);
      street.rumor =
          Rumor(spec: chosen, announcedOn: day, decidesOn: day + delay);
      street.demand +=
          chosen.good ? Tuning.announceGoodDemand : Tuning.announceBadDemand;
      _nextRumorDay[home.id] = day + gap;
      ledger.add(
        LedgerEntry(
          day: day,
          kind: 'rumorAnnounced',
          message: chosen.rumor,
          plotId: street.id,
        ),
      );
    }
  }

  void _refill(String cityId) {
    final source = switch (cityId) {
      'ironridge' => _ironEvents,
      'greenvale' => _greenEvents,
      _ => eventDeck,
    };
    _decks[cityId] = [...source]..shuffle(_random);
  }

  void _announceShocks() {
    for (final spec in _shockDeck) {
      if (spec.announceDay != day || _announcedShocks.contains(spec.id))
        continue;
      _announcedShocks.add(spec.id);
      _shocks.add(_Pending(spec: spec, decidesOn: day + Tuning.shockDelay));
      ledger.add(
          LedgerEntry(day: day, kind: 'rumorAnnounced', message: spec.rumor));
    }
  }

  void _announcePolls() {
    if (day != 8 && day != 24) return;
    if (_announcedPolls.contains(day)) return;
    _announcedPolls.add(day);
    for (final home in cities) {
      final chance = Tuning.projectChance;
      _proposals.add(
        _Proposal(
            cityId: home.id,
            decidesOn: day + Tuning.shockDelay,
            chance: chance),
      );
      ledger.add(
        LedgerEntry(
          day: day,
          kind: 'rumorAnnounced',
          message:
              '${home.name} will vote on a public project in ${Tuning.shockDelay} days. The poll is ${(chance * 100).round()}%.',
        ),
      );
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

  void _clearShares() {
    for (final listed in companies) {
      final home = city(listed.cityId);
      final fundamental =
          _fundamentalValue(listed.id, home, listed.sharesOutstanding);
      listed.fundamental = fundamental;
      final book = orders.where((o) => o.companyId == listed.id).toList();
      var net = 0;
      for (final order in book) {
        net += order.buy ? order.shares : -order.shares;
      }
      final noise = _range(-Tuning.shareNoise, Tuning.shareNoise);
      final impact = Tuning.shareImpact * net / listed.sharesOutstanding;
      var nextPrice = listed.price * (1 + impact + noise) +
          Tuning.shareDrift * (fundamental - listed.price);
      if (nextPrice < Tuning.shareMinPrice) nextPrice = Tuning.shareMinPrice;
      final ask = nextPrice * (1 + Tuning.shareSpread / 2);
      final bid = nextPrice * (1 - Tuning.shareSpread / 2);
      listed.lastAsk = ask;
      listed.lastBid = bid;
      for (final order in book) {
        _fill(order, listed, ask, bid);
      }
      listed.price = nextPrice;
      listed.history.add(nextPrice);
    }
    orders.clear();
  }

  void _fill(ShareOrder order, Company listed, double ask, double bid) {
    final person = investor(order.investorId);
    if (order.buy) {
      final unit = ask * (1 + Tuning.shareFee);
      var fill = order.shares;
      final room = shareCapOf(listed) - sharesHeld(person.id, listed.id);
      if (room < fill) fill = room;
      if (unit > 0) {
        final affordable = ((person.cash + 1e-6) / unit).floor();
        if (affordable < fill) fill = affordable;
      } else {
        fill = 0;
      }
      if (fill <= 0) {
        if (!person.isBot) {
          ledger.add(
            LedgerEntry(
              day: day,
              kind: 'order',
              message: 'The order for ${listed.name} did not fill.',
              investorId: person.id,
            ),
          );
        }
        return;
      }
      final spent = fill * unit;
      person.cash -= spent;
      listed.holdings[person.id] = sharesHeld(person.id, listed.id) + fill;
      ledger.add(
        LedgerEntry(
          day: day,
          kind: 'bought',
          message: '${person.name} bought $fill shares of ${listed.name}.',
          investorId: person.id,
          amount: spent,
        ),
      );
      return;
    }
    var fill = order.shares;
    final held = sharesHeld(person.id, listed.id);
    if (held < fill) fill = held;
    if (fill <= 0) return;
    final proceeds = fill * bid * (1 - Tuning.shareFee);
    person.cash += proceeds;
    if (proceeds > person.bestSale) person.bestSale = proceeds;
    final left = held - fill;
    if (left == 0) {
      listed.holdings.remove(person.id);
    } else {
      listed.holdings[person.id] = left;
    }
    ledger.add(
      LedgerEntry(
        day: day,
        kind: 'sold',
        message: '${person.name} sold $fill shares of ${listed.name}.',
        investorId: person.id,
        amount: proceeds,
      ),
    );
  }

  double _fundamentalValue(String id, City home, int outstanding) {
    final raw = switch (id) {
      'harbor-shipping' => home.effectiveOutput * Tuning.shippingPerOutput +
          home.population * Tuning.shippingPerPerson,
      'harbor-bank' =>
        home.population * Tuning.bankPerPerson + home.jobs * Tuning.bankPerJob,
      'ironridge-mining' => home.effectiveOutput * Tuning.miningPerOutput +
          home.population * Tuning.miningPerPerson,
      _ => home.effectiveOutput * Tuning.coopPerOutput +
          home.population * Tuning.coopPerPerson,
    };
    return raw / outstanding;
  }

  void _shareTraders() {
    for (final person in investors) {
      if (person.id == 'tara') _taraShares(person);
      if (person.id == 'vik') _vikShares(person);
    }
  }

  void _taraShares(Investor person) {
    if (_random.nextDouble() >= person.actChance) return;
    final selling = <String>{};
    for (final listed in companies) {
      final held = sharesHeld(person.id, listed.id);
      if (held <= 0) continue;
      final change = percentChange(listed.history, 2);
      if (change != null && change < Tuning.taraSellFall) {
        selling.add(listed.id);
        placeShareOrder(
          person.id,
          listed.id,
          buy: false,
          shares: held < Tuning.shareLot ? held : Tuning.shareLot,
        );
      }
    }
    Company? best;
    var bestRise = Tuning.taraBuyRise;
    for (final listed in companies) {
      if (selling.contains(listed.id)) continue;
      final change = percentChange(listed.history, 3);
      if (change == null || change <= bestRise) continue;
      if (_styleRoom(person, listed) < Tuning.shareLot) continue;
      if (!_canBuyLot(person, listed)) continue;
      bestRise = change;
      best = listed;
    }
    if (best != null) {
      placeShareOrder(person.id, best.id, buy: true, shares: Tuning.shareLot);
    }
  }

  void _vikShares(Investor person) {
    if (_random.nextDouble() >= person.actChance) return;
    final selling = <String>{};
    for (final listed in companies) {
      final held = sharesHeld(person.id, listed.id);
      if (held <= 0) continue;
      if (listed.price < listed.fundamental * Tuning.vikPremium) continue;
      selling.add(listed.id);
      placeShareOrder(
        person.id,
        listed.id,
        buy: false,
        shares: held < Tuning.shareLot ? held : Tuning.shareLot,
      );
    }
    final cheap = [...companies]..sort(
        (a, b) => (a.price / a.fundamental).compareTo(b.price / b.fundamental),
      );
    for (final listed in cheap) {
      if (selling.contains(listed.id)) continue;
      if (listed.price > listed.fundamental * Tuning.vikDiscount) continue;
      if (_styleRoom(person, listed) < Tuning.shareLot) continue;
      if (!_canBuyLot(person, listed)) continue;
      placeShareOrder(person.id, listed.id, buy: true, shares: Tuning.shareLot);
      return;
    }
  }

  void _landBots({required bool forced}) {
    for (final person
        in investors.where((i) => i.isBot && i.id != 'tara' && i.id != 'vik')) {
      _botSell(person);
      final acts = forced || _random.nextDouble() < person.actChance;
      if (!acts) continue;
      _botBuy(person, forced: forced);
      _botBuild(person);
      _botShareBook(person);
    }
  }

  void _botSell(Investor person) {
    final owned = plots.where((p) => p.ownerId == person.id).toList();
    if (person.id == 'mei') return;
    if (person.id == 'rita') {
      for (final target in owned) {
        final change = streetChange(target.streetId, 2);
        if (change != null && change < Tuning.ritaSellFall)
          sell(person.id, target.id);
      }
      _ritaShareSells(person);
      return;
    }
    if (person.id == 'omar') {
      for (final target in owned) {
        if (target.building == null) continue;
        if (incomeOf(target) < Tuning.omarSellIncome &&
            _random.nextDouble() < 0.5) {
          sell(person.id, target.id);
        }
      }
      return;
    }
    for (final target in owned) {
      final rumor = streetOf(target).rumor;
      final badStreet =
          rumor != null && !rumor.spec.good && rumor.happened == null;
      if (badStreet || _cityIsBad(cityIdOf(target.streetId)))
        sell(person.id, target.id);
    }
    for (final listed in companies) {
      final held = sharesHeld(person.id, listed.id);
      if (held > 0 && _cityIsBad(listed.cityId)) {
        placeShareOrder(person.id, listed.id, buy: false, shares: held);
      }
    }
  }

  void _ritaShareSells(Investor person) {
    for (final listed in companies) {
      final held = sharesHeld(person.id, listed.id);
      if (held <= 0) continue;
      final change = percentChange(listed.history, 2);
      if (change != null && change < Tuning.ritaSellFall) {
        placeShareOrder(
          person.id,
          listed.id,
          buy: false,
          shares: held < Tuning.shareLot ? held : Tuning.shareLot,
        );
      }
    }
  }

  bool _cityIsBad(String cityId) {
    for (final shock in _shocks) {
      if (shock.happened != null || shock.spec.good) continue;
      if (shock.spec.cityId == null || shock.spec.cityId == cityId) return true;
    }
    return false;
  }

  void _botBuy(Investor person, {required bool forced}) {
    if (ownedCount(person.id) >= Tuning.islandBotMaxPlots) return;
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
    empty.sort((a, b) {
      final byTraffic = b.currentTraffic.compareTo(a.currentTraffic);
      if (byTraffic != 0) return byTraffic;
      return plots.indexOf(a).compareTo(plots.indexOf(b));
    });
    final target = empty.first;
    final preferred = _preferred(person, target);
    if (buildAllowed(target, preferred) &&
        _canBuild(person, target, preferred)) {
      build(person.id, target.id, preferred);
      return;
    }
    if (preferred != BuildingType.parking &&
        buildAllowed(target, BuildingType.parking) &&
        _canBuild(person, target, BuildingType.parking)) {
      build(person.id, target.id, BuildingType.parking);
    }
  }

  BuildingType _preferred(Investor person, Plot target) {
    final home = cityOfPlot(target);
    if (person.id == 'mei') return BuildingType.parking;
    if (person.id == 'dex') {
      return _random.nextBool() ? BuildingType.carWash : BuildingType.parking;
    }
    if (person.id == 'omar') {
      if (home.id == 'harborview' &&
          home.effectiveOutput > 50 &&
          buildAllowed(target, BuildingType.warehouse)) {
        return BuildingType.warehouse;
      }
      if (home.id == 'ironridge' &&
          home.population > 2000 &&
          buildAllowed(target, BuildingType.diner)) {
        return BuildingType.diner;
      }
      if (home.id == 'greenvale' && buildAllowed(target, BuildingType.silo)) {
        return home.effectiveOutput >= 36
            ? BuildingType.silo
            : BuildingType.farmStand;
      }
    }
    if (target.currentTraffic > Tuning.omarCarWashTraffic &&
        person.id == 'omar') {
      return BuildingType.carWash;
    }
    if (person.id == 'omar') return BuildingType.parking;
    return BuildingType.carWash;
  }

  void _botShareBook(Investor person) {
    if (person.id == 'omar') {
      final ranked = [...companies]..sort(
          (a, b) => city(b.cityId)
              .effectiveOutput
              .compareTo(city(a.cityId).effectiveOutput),
        );
      for (final listed in ranked) {
        if (_styleRoom(person, listed) < Tuning.shareLot) continue;
        if (!_canBuyLot(person, listed)) continue;
        placeShareOrder(person.id, listed.id,
            buy: true, shares: Tuning.shareLot);
        return;
      }
    }
    if (person.id == 'mei') {
      final missing = companies
          .where((c) => sharesHeld(person.id, c.id) == 0)
          .toList()
        ..sort((a, b) => a.price.compareTo(b.price));
      for (final listed in missing) {
        if (_styleRoom(person, listed) < Tuning.shareLot) continue;
        if (!_canBuyLot(person, listed)) continue;
        placeShareOrder(person.id, listed.id,
            buy: true, shares: Tuning.shareLot);
        return;
      }
    }
    if (person.id == 'rita') {
      Company? best;
      var bestRise = Tuning.ritaBuyRise;
      for (final listed in companies) {
        final change = percentChange(listed.history, 3);
        if (change == null || change <= bestRise) continue;
        if (_styleRoom(person, listed) < Tuning.shareLot) continue;
        if (!_canBuyLot(person, listed)) continue;
        bestRise = change;
        best = listed;
      }
      if (best != null) {
        placeShareOrder(person.id, best.id, buy: true, shares: Tuning.shareLot);
      }
    }
  }

  bool _canBuild(Investor person, Plot target, BuildingType type) =>
      person.cash + 1e-6 >= buildCost(target, type) + Tuning.botBuildBuffer;

  bool _canAfford(Investor person, Plot target) =>
      target.ownerId == null &&
      ownedCount(person.id) < Tuning.islandBotMaxPlots &&
      person.cash - priceOf(target) + 1e-6 >= Tuning.botBuyBuffer;

  bool _canBuyLot(Investor person, Company listed) {
    final unit =
        listed.price * (1 + Tuning.shareSpread / 2) * (1 + Tuning.shareFee);
    return person.cash - unit * Tuning.shareLot + 1e-6 >= Tuning.botBuyBuffer;
  }

  int _styleRoom(Investor person, Company listed) {
    final fraction = person.id == 'tara' || person.id == 'vik'
        ? Tuning.traderShareCap
        : Tuning.investorShareCap;
    final style = (listed.sharesOutstanding * fraction).round();
    final hard = shareCapOf(listed);
    final limit = style < hard ? style : hard;
    final room = limit - sharesHeld(person.id, listed.id);
    return room < 0 ? 0 : room;
  }

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
    final ownedCities = plots
        .where((p) => p.ownerId == person.id)
        .map((p) => cityIdOf(p.streetId))
        .toSet();
    final ownedStreets = plots
        .where((p) => p.ownerId == person.id)
        .map((p) => p.streetId)
        .toSet();
    final affordable = plots.where((p) => _canAfford(person, p)).toList();
    final freshCity = affordable
        .where((p) => !ownedCities.contains(cityIdOf(p.streetId)))
        .toList();
    final freshStreet =
        affordable.where((p) => !ownedStreets.contains(p.streetId)).toList();
    final options = freshCity.isNotEmpty
        ? freshCity
        : freshStreet.isNotEmpty
            ? freshStreet
            : affordable;
    if (options.isEmpty) return null;
    options.sort((a, b) => priceOf(a).compareTo(priceOf(b)));
    return options.first;
  }

  Plot? _highestTraffic(Investor person) {
    final options = plots.where((p) => _canAfford(person, p)).toList();
    if (options.isEmpty) return null;
    options.sort((a, b) {
      final byTraffic = b.currentTraffic.compareTo(a.currentTraffic);
      if (byTraffic != 0) return byTraffic;
      return plots.indexOf(a).compareTo(plots.indexOf(b));
    });
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
    for (final target in plots) {
      target.displayNoise = _range(-Tuning.carsNoise, Tuning.carsNoise);
    }
  }

  void _recordNetWorth() {
    for (final person in investors) {
      person.netWorth.add(netWorthOf(person.id));
    }
  }

  int _int(int min, int max) => min + _random.nextInt(max - min + 1);

  double _range(double min, double max) =>
      min + _random.nextDouble() * (max - min);
}

String _builtName(BuildingType type) => switch (type) {
      BuildingType.carWash => 'a car wash',
      BuildingType.parking => 'a parking lot',
      BuildingType.warehouse => 'a warehouse',
      BuildingType.diner => 'a diner',
      BuildingType.silo => 'a silo',
      BuildingType.farmStand => 'a farm stand',
      BuildingType.house => 'a house',
    };
