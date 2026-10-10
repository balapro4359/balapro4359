import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:holdings_engine/holdings_engine.dart';

import 'controller.dart';
import 'format.dart';
import 'theme.dart';
import 'widgets.dart';
import 'world.dart';

class BookPage extends StatelessWidget {
  const BookPage(
      {super.key, required this.controller, required this.onOpenHarbor});

  final GameController controller;
  final VoidCallback onOpenHarbor;

  IslandGame get game => controller.game;

  @override
  Widget build(BuildContext context) {
    final palette = HoldingsPalette.of(context);
    final you = game.investor('you');
    final worth = game.netWorthOf('you');
    final rival = _leadingRival(game);
    final owned = game.plots.where((p) => p.ownerId == 'you').toList();
    final shares =
        game.companies.where((c) => game.sharesHeld('you', c.id) > 0).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(
          'Day ${game.day} of ${Tuning.soloSeasonDays}',
          style: TextStyle(color: palette.muted, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          'Tick ${game.tick} of ${Tuning.fastTicksPerSlowDay}. The day settles on the fourth tick.',
          style: TextStyle(color: palette.muted, fontSize: 13),
        ),
        const SizedBox(height: 14),
        Text('Net worth', style: TextStyle(fontSize: 14, color: palette.muted)),
        const SizedBox(height: 6),
        WorthFigure(value: worth),
        const SizedBox(height: 8),
        Text('Cash ${money(you.cash)}', style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 18),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _LegendDot(color: palette.teal),
                  const SizedBox(width: 6),
                  const Text('You',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 14),
                  _LegendDot(color: ownerColor(rival.id)),
                  const SizedBox(width: 6),
                  Text(rival.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              if (you.netWorth.length < 2)
                Text(
                  'The line starts when the first day settles.',
                  style: TextStyle(color: palette.muted, fontSize: 14),
                )
              else
                WorthChart(
                  you: you.netWorth,
                  rival: rival.netWorth,
                  rivalColor: ownerColor(rival.id),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('Holdings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        if (owned.isEmpty && shares.isEmpty)
          const SoftCard(
            child: Text(
              'Nothing on the book yet. Open a city, or buy shares below.',
              style: TextStyle(fontSize: 16, height: 1.35),
            ),
          )
        else
          ...owned.map((plot) {
            final street = game.streetOf(plot);
            final income = game.incomeOf(plot);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(plot.name,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            '${street.name} · ${_buildingName(plot.building)}',
                            style:
                                TextStyle(color: palette.muted, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(money(game.priceOf(plot)),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          signedMoney(income),
                          style: TextStyle(
                            color: income >= 0 ? palette.teal : palette.coral,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        for (final listed in shares)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SoftCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(listed.name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          '${game.sharesHeld('you', listed.id)} shares · ${game.city(listed.cityId).name}',
                          style: TextStyle(color: palette.muted, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Text(money(listed.price * game.sharesHeld('you', listed.id)),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 6),
        PillButton(label: 'Open Harborview', onPressed: onOpenHarbor),
        const SizedBox(height: 22),
        const Text('Companies',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        for (final listed in game.companies)
          _CompanyCard(controller: controller, company: listed),
        const SizedBox(height: 22),
        const Text('Standings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SoftCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (final person in _ranked(game))
                _StandingRow(game: game, person: person),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _HowToPlay(),
        if (game.finished) ...[
          const SizedBox(height: 18),
          _ResultCard(game: game),
        ],
      ],
    );
  }
}

Investor _leadingRival(IslandGame game) {
  return game.investors
      .where((person) => person.id != 'you')
      .reduce((best, person) {
    return game.netWorthOf(person.id) > game.netWorthOf(best.id)
        ? person
        : best;
  });
}

List<Investor> _ranked(IslandGame game) {
  return [...game.investors]..sort((a, b) {
      final byWorth = game.netWorthOf(b.id).compareTo(game.netWorthOf(a.id));
      if (byWorth != 0) return byWorth;
      return a.id.compareTo(b.id);
    });
}

String _buildingName(BuildingType? building) {
  return switch (building) {
    BuildingType.carWash => 'Car wash',
    BuildingType.parking => 'Parking lot',
    BuildingType.warehouse => 'Warehouse',
    BuildingType.diner => 'Diner',
    BuildingType.silo => 'Grain silo',
    BuildingType.farmStand => 'Farm stand',
    BuildingType.house => 'House',
    null => 'Land',
  };
}

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({required this.controller, required this.company});

  final GameController controller;
  final Company company;

  @override
  Widget build(BuildContext context) {
    final palette = HoldingsPalette.of(context);
    final game = controller.game;
    final held = game.sharesHeld('you', company.id);
    final order = game.orderFor('you', company.id);
    final home = game.city(company.cityId);
    final sellLot = held < Tuning.shareLot ? held : Tuning.shareLot;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(company.name,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              '${home.name} · ${money(company.price)} · ${signedPercent(game.shareChange(company.id, 1))}',
              style: TextStyle(color: palette.muted, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              'You hold $held · about ${money(company.fundamental * company.dividendYield)} a share each day',
              style: const TextStyle(fontSize: 14),
            ),
            if (order != null) ...[
              const SizedBox(height: 6),
              Text(
                '${order.buy ? 'Buying' : 'Selling'} ${order.shares}. It fills on the next tick.',
                style: const TextStyle(fontSize: 14),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      key: Key('buy-${company.id}'),
                      onPressed: game.finished
                          ? null
                          : () => controller.orderShares(company.id, buy: true),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.ink,
                        foregroundColor: palette.bg,
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Buy 10',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: game.finished || held == 0
                          ? null
                          : () =>
                              controller.orderShares(company.id, buy: false),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.card,
                        foregroundColor: palette.ink,
                        disabledBackgroundColor: palette.line,
                        shape: const StadiumBorder(),
                        side: BorderSide(color: palette.line),
                      ),
                      child: Text(
                        held == 0 ? 'Sell 10' : 'Sell $sellLot',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.game, required this.person});

  final IslandGame game;
  final Investor person;

  @override
  Widget build(BuildContext context) {
    final palette = HoldingsPalette.of(context);
    final worth = game.netWorthOf(person.id);
    final ret = (worth - Tuning.startingCash) / Tuning.startingCash;
    final plots = game.ownedCount(person.id);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: ownerColor(person.id),
            child: Text(
              person.name.substring(0, 1),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(person.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    if (person.isBot)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: palette.coral.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text('Bot',
                            style:
                                TextStyle(color: palette.coral, fontSize: 12)),
                      ),
                  ],
                ),
                Text(
                  '${person.style} · $plots ${plots == 1 ? 'plot' : 'plots'}',
                  style: TextStyle(color: palette.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(money(worth),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              Text(
                signedPercent(ret),
                style: TextStyle(
                  color: ret >= 0 ? palette.teal : palette.coral,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HowToPlay extends StatelessWidget {
  const _HowToPlay();

  @override
  Widget build(BuildContext context) {
    const rules = [
      'You start with \$12,000 and 40 days. Finish with the highest net worth.',
      'Tap a plot, buy it, then build a car wash or a parking lot. Car washes earn more on busy streets and lose money on quiet ones.',
      'Cars on each street show its traffic. A weekly census on every 7th day shifts it.',
      'News arrives a few days before it lands. It might not happen.',
      'Four rivals trade the same streets. When the crowd piles into a street, its prices climb.',
      'The island also has Ironridge and Greenvale, houses, and company shares. Next moves one tick. The day settles every fourth tick.',
    ];
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: const Text('How to play',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            for (final rule in rules)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(rule,
                    style: const TextStyle(fontSize: 15, height: 1.35)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.game});

  final IslandGame game;

  @override
  Widget build(BuildContext context) {
    final you = game.investor('you');
    final worth = game.netWorthOf('you');
    final ret = (worth - Tuning.startingCash) / Tuning.startingCash;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rank ${game.rankOf('you')} of ${game.investors.length}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text('Net worth ${money(worth)} · ${signedPercent(ret)}',
              style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text('Earned ${signedMoney(you.totalEarned)}',
              style: const TextStyle(fontSize: 15)),
          Text('Taxes ${money(you.totalTax)}',
              style: const TextStyle(fontSize: 15)),
          Text(
              'Streets invested in ${game.streetsHeld('you')} of ${game.streets.length}',
              style: const TextStyle(fontSize: 15)),
          Text('Best sale ${money(you.bestSale)}',
              style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}

class MapPage extends StatelessWidget {
  const MapPage({super.key, required this.game, required this.onOpenCity});

  final IslandGame game;
  final ValueChanged<String> onOpenCity;

  @override
  Widget build(BuildContext context) {
    final palette = HoldingsPalette.of(context);
    const tops = [0.18, 0.46, 0.72];
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        return Stack(
          children: [
            const Positioned.fill(
                child: WorldPlate(asset: 'assets/world/island.jpg')),
            for (var i = 0; i < game.cities.length; i++)
              Positioned(
                left: 48,
                right: 48,
                top: h * tops[i],
                child: _CityCard(
                  name: game.cities[i].name,
                  line: game.cities[i].character,
                  detail: game.cityHasNews(game.cities[i].id)
                      ? 'News is pending.'
                      : game.cities[i].council,
                  change: _cityChange(game, game.cities[i].id),
                  fragility: game.cities[i].concentration,
                  fragilityColor: game.cities[i].concentration > 0.6
                      ? palette.coral
                      : palette.teal,
                  onTap: () => onOpenCity(game.cities[i].id),
                ),
              ),
          ],
        );
      },
    );
  }
}

double? _cityChange(IslandGame game, String cityId) {
  final values = game
      .streetsOf(cityId)
      .map((street) => game.streetChange(street.id, 1))
      .whereType<double>();
  if (values.isEmpty) return null;
  var sum = 0.0;
  var count = 0;
  for (final value in values) {
    sum += value;
    count += 1;
  }
  return sum / count;
}

class _CityCard extends StatelessWidget {
  const _CityCard({
    required this.name,
    required this.line,
    required this.detail,
    required this.fragility,
    required this.fragilityColor,
    this.change,
    this.onTap,
  });

  final String name;
  final String line;
  final String detail;
  final double fragility;
  final Color fragilityColor;
  final double? change;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = HoldingsPalette.of(context);
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: palette.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  if (change != null) StreetChange(change: change),
                ],
              ),
              Text(line, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: fragility,
                  minHeight: 4,
                  backgroundColor: palette.line,
                  color: fragilityColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(detail,
                  style: TextStyle(color: palette.muted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class HarborPage extends StatelessWidget {
  const HarborPage({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    final selected = controller.selectedPlotId == null
        ? null
        : game.plot(controller.selectedPlotId!);
    final streets = game.streetsOf(controller.cityId);
    return Column(
      children: [
        _HarborBar(controller: controller),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final night = Theme.of(context).brightness == Brightness.dark;
              return InteractiveViewer(
                minScale: 1,
                maxScale: 2.6,
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: WorldPlate(
                          asset: cityPlate(controller.cityId,
                              night ? Brightness.dark : Brightness.light),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        right: 10,
                        top: constraints.maxHeight * 0.2,
                        bottom: 8,
                        child: Column(
                          children: [
                            for (final street in streets)
                              Expanded(
                                child: _StreetRow(
                                  game: game,
                                  street: street,
                                  selectedId: controller.selectedPlotId,
                                  onTap: (id) {
                                    HapticFeedback.selectionClick();
                                    controller.selectPlot(id);
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: selected == null
              ? const SizedBox(width: double.infinity)
              : _PlotSheet(
                  key: ValueKey(selected.id),
                  game: game,
                  plot: selected,
                  onBuy: () {
                    HapticFeedback.lightImpact();
                    controller.buySelected();
                  },
                  onBuild: (type) {
                    HapticFeedback.lightImpact();
                    controller.buildSelected(type);
                  },
                  onSell: () {
                    HapticFeedback.lightImpact();
                    controller.sellSelected();
                  },
                  onClose: () => controller.selectPlot(null),
                ),
        ),
      ],
    );
  }
}

class _HarborBar extends StatelessWidget {
  const _HarborBar({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final palette = HoldingsPalette.of(context);
    final game = controller.game;
    final home = game.city(controller.cityId);
    final you = game.investor('you');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(home.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    Text(
                      'Day ${game.day} · tick ${game.tick} of ${Tuning.fastTicksPerSlowDay}',
                      style: TextStyle(color: palette.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Text('Net ${money(game.netWorthOf('you'))}',
                  style: const TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${count(home.population)} people · ${home.outputLabel} ${home.effectiveOutput.round()} · ${home.council}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.muted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  money(you.cash),
                  style: TextStyle(
                      fontSize: 16,
                      color: you.cash < 0 ? palette.coral : palette.ink),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _TinyButton(
                label: controller.auto ? 'Auto on' : 'Auto',
                filled: controller.auto,
                onPressed: game.finished
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        controller.toggleAuto();
                      },
              ),
              const SizedBox(width: 8),
              _TinyButton(
                label: 'Next',
                filled: true,
                onPressed: game.finished
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        controller.nextTick();
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TinyButton extends StatelessWidget {
  const _TinyButton(
      {required this.label, required this.onPressed, required this.filled});

  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final palette = HoldingsPalette.of(context);
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: filled ? palette.ink : palette.card,
          foregroundColor: filled ? palette.bg : palette.ink,
          disabledBackgroundColor: palette.line,
          elevation: 0,
          shape: const StadiumBorder(),
          side: filled ? null : BorderSide(color: palette.line),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}

class _StreetRow extends StatelessWidget {
  const _StreetRow({
    required this.game,
    required this.street,
    required this.selectedId,
    required this.onTap,
  });

  final IslandGame game;
  final Street street;
  final String? selectedId;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final palette = HoldingsPalette.of(context);
    final plots =
        game.plots.where((plot) => plot.streetId == street.id).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final pinHeight = (constraints.maxHeight - 28).clamp(20.0, 46.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: palette.card.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: palette.line),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(street.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(width: 8),
                    StreetChange(change: game.streetChange(street.id, 1)),
                    if (street.rumor != null) ...[
                      const SizedBox(width: 6),
                      Text('!',
                          style: TextStyle(
                              color: palette.coral,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ],
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              height: pinHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final plot in plots)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _PlotPin(
                          plot: plot,
                          game: game,
                          selected: plot.id == selectedId,
                          onTap: () => onTap(plot.id),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlotPin extends StatelessWidget {
  const _PlotPin({
    required this.plot,
    required this.game,
    required this.selected,
    required this.onTap,
  });

  final Plot plot;
  final IslandGame game;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = HoldingsPalette.of(context);
    final income = game.lastIncome[plot.id];
    final owned = plot.ownerId != null;
    return Material(
      color: palette.card.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: motionOf(context),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? palette.teal
                  : owned
                      ? ownerColor(plot.ownerId)
                      : palette.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxHeight < 14) return const SizedBox.shrink();
              final showKind = constraints.maxHeight >= 40;
              final showIncome = income != null && constraints.maxHeight >= 58;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    plot.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  if (showKind && plot.building == BuildingType.carWash)
                    Icon(Icons.water_drop_outlined,
                        size: 14, color: palette.teal)
                  else if (showKind && plot.building == BuildingType.parking)
                    Icon(Icons.local_parking_outlined,
                        size: 14, color: palette.muted)
                  else if (showKind && plot.building != null)
                    Text(
                      _buildingName(plot.building),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: palette.muted),
                    )
                  else if (showKind)
                    Text(
                      plot.ownerId == null ? 'Open' : 'Lot',
                      style: TextStyle(fontSize: 12, color: palette.muted),
                    ),
                  if (showIncome)
                    Text(
                      signedMoney(income),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: income >= 0 ? palette.teal : palette.coral,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PlotSheet extends StatelessWidget {
  const _PlotSheet({
    super.key,
    required this.game,
    required this.plot,
    required this.onBuy,
    required this.onBuild,
    required this.onSell,
    required this.onClose,
  });

  final IslandGame game;
  final Plot plot;
  final VoidCallback onBuy;
  final ValueChanged<BuildingType> onBuild;
  final VoidCallback onSell;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final palette = HoldingsPalette.of(context);
    final street = game.streetOf(plot);
    final yours = plot.ownerId == 'you';
    final price = game.priceOf(plot);
    final rumor = street.rumor;
    final offers = game.offersFor(plot);
    final actions = plot.ownerId == null
        ? PillButton(
            label: 'Buy ${money(price)}',
            onPressed: game.finished ? null : onBuy,
          )
        : yours && plot.building == null
            ? Column(
                children: [
                  for (var i = 0; i < offers.length; i++) ...[
                    PillButton(
                      label: _offer(offers[i]),
                      height: 56,
                      filled: i == 0,
                      onPressed:
                          game.finished ? null : () => onBuild(offers[i]),
                    ),
                    if (i != offers.length - 1) const SizedBox(height: 8),
                  ],
                ],
              )
            : yours
                ? PillButton(
                    label: 'Sell ${money(saleProceeds(price))}',
                    filled: false,
                    onPressed: game.finished ? null : onSell,
                  )
                : Padding(
                    padding: const EdgeInsets.only(bottom: 8, right: 8),
                    child: Text(
                      'Owned by ${game.investor(plot.ownerId!).name}${game.investor(plot.ownerId!).isBot ? ', a bot' : ''}.',
                      style: const TextStyle(fontSize: 15),
                    ),
                  );
    return Material(
      color: palette.card,
      elevation: 12,
      shadowColor: const Color(0x22000000),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.46),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(plot.name,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                  ),
                ],
              ),
              Text(
                '${street.name} · ${_buildingName(plot.building)}',
                style: TextStyle(color: palette.muted, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                '${game.carsADay(plot).round()} cars a day · ${_censusWord(plot)}',
                style: const TextStyle(fontSize: 15),
              ),
              Text(
                '${yours ? 'Sale value' : 'Price'} ${money(price)} · Street ${signedPercent(game.streetChange(street.id, 1))}',
                style: const TextStyle(fontSize: 15),
              ),
              if (yours)
                Text(
                  'In the plot ${money(plot.invested)} · Today ${signedMoney(game.incomeOf(plot))}',
                  style: const TextStyle(fontSize: 15),
                ),
              if (rumor != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(rumor.spec.rumor,
                      style: const TextStyle(fontSize: 14, height: 1.35)),
                ),
              if (plot.closureDays > 0)
                Text(
                  'Closed for ${plot.closureDays} more days',
                  style: TextStyle(color: palette.coral, fontSize: 14),
                ),
              const SizedBox(height: 12),
              actions,
            ],
          ),
        ),
      ),
    );
  }

  String _offer(BuildingType type) {
    final home = game.cityOfPlot(plot);
    final estimate = businessIncome(
      building: type,
      traffic: plot.currentTraffic,
      openForBusiness: true,
      output: home.effectiveOutput,
      population: home.population,
      employment: home.employment,
    );
    final name = switch (type) {
      BuildingType.carWash => 'Build a car wash',
      BuildingType.parking => 'Build a parking lot',
      BuildingType.warehouse => 'Build a warehouse',
      BuildingType.diner => 'Build a diner',
      BuildingType.silo => 'Build a silo',
      BuildingType.farmStand => 'Build a farm stand',
      BuildingType.house => 'Build a house',
    };
    return '$name\n${money(game.buildCost(plot, type))} · ${signedMoney(estimate)} a day';
  }
}

String _censusWord(Plot plot) {
  final move = plot.lastCensusMove;
  if (move == null) return 'no census yet';
  if (move > 0) return 'rose';
  if (move < 0) return 'fell';
  return 'flat';
}

class NewsPage extends StatelessWidget {
  const NewsPage({super.key, required this.game});

  final IslandGame game;

  @override
  Widget build(BuildContext context) {
    final palette = HoldingsPalette.of(context);
    final items = game.ledger.reversed.toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const Text(
          'News',
          style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.6),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Text('The town is quiet.',
              style: TextStyle(color: palette.muted, fontSize: 16))
        else
          for (final entry in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Day ${entry.day}',
                        style: TextStyle(color: palette.muted, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(entry.message,
                        style: const TextStyle(fontSize: 16, height: 1.35)),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
