import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:holdings_engine/holdings_engine.dart';

import 'controller.dart';
import 'format.dart';
import 'theme.dart';
import 'widgets.dart';

class BookPage extends StatelessWidget {
  const BookPage({super.key, required this.game, required this.onOpenHarbor});

  final HoldingsGame game;
  final VoidCallback onOpenHarbor;

  @override
  Widget build(BuildContext context) {
    final palette = HoldingsPalette.of(context);
    final you = game.investor('you');
    final worth = game.netWorthOf('you');
    final rival = _leadingRival(game);
    final owned = game.plots.where((p) => p.ownerId == 'you').toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(
          'Day ${game.day} of ${Tuning.soloSeasonDays}',
          style: TextStyle(color: palette.muted, fontSize: 14),
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
                  const Text('You', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 14),
                  _LegendDot(color: ownerColor(rival.id)),
                  const SizedBox(width: 6),
                  Text(rival.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
        const Text('Holdings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        if (owned.isEmpty)
          const SoftCard(
            child: Text(
              'Nothing on the book yet. Open Harborview and buy where the cars are.',
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
                          Text(plot.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            '${street.name} · ${_buildingName(plot.building)}',
                            style: TextStyle(color: palette.muted, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(money(game.priceOf(plot)), style: const TextStyle(fontWeight: FontWeight.w600)),
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
        const SizedBox(height: 6),
        PillButton(label: 'Open Harborview', onPressed: onOpenHarbor),
        const SizedBox(height: 22),
        const Text('Standings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SoftCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (final person in _ranked(game)) _StandingRow(game: game, person: person),
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

Investor _leadingRival(HoldingsGame game) {
  return game.investors.where((person) => person.id != 'you').reduce((best, person) {
    return game.netWorthOf(person.id) > game.netWorthOf(best.id) ? person : best;
  });
}

List<Investor> _ranked(HoldingsGame game) {
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
    null => 'Land',
  };
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

  final HoldingsGame game;
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
                    Text(person.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    if (person.isBot)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: palette.coral.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text('Bot', style: TextStyle(color: palette.coral, fontSize: 12)),
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
              Text(money(worth), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
    ];
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: const Text('How to play', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            for (final rule in rules)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(rule, style: const TextStyle(fontSize: 15, height: 1.35)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.game});

  final HoldingsGame game;

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
            'Rank ${game.rankOf('you')} of 5',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text('Net worth ${money(worth)} · ${signedPercent(ret)}', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text('Earned from businesses ${signedMoney(you.totalEarned)}', style: const TextStyle(fontSize: 15)),
          Text('Streets invested in ${game.streetsHeld('you')} of 4', style: const TextStyle(fontSize: 15)),
          Text('Best sale ${money(you.bestSale)}', style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}

class MapPage extends StatelessWidget {
  const MapPage({super.key, required this.game, required this.onOpenHarbor});

  final HoldingsGame game;
  final VoidCallback onOpenHarbor;

  @override
  Widget build(BuildContext context) {
    final palette = HoldingsPalette.of(context);
    final changes = game.streets.map((street) => game.streetChange(street.id, 1)).whereType<double>();
    final harborChange = changes.isEmpty ? null : changes.reduce((a, b) => a + b) / game.streets.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const Text(
          'The island',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.6),
        ),
        const SizedBox(height: 6),
        Text(
          'Three cities. Harborview is the open book.',
          style: TextStyle(color: palette.muted, fontSize: 15),
        ),
        const SizedBox(height: 16),
        _CityCard(
          name: 'Harborview',
          line: 'Port and trade',
          detail: 'Buy land, build, and sell today.',
          change: harborChange,
          fragility: 0.46,
          fragilityColor: palette.teal,
          onTap: onOpenHarbor,
        ),
        const SizedBox(height: 12),
        _CityCard(
          name: 'Ironridge',
          line: 'One mine, fast and fragile',
          detail: 'Prices for this city are not in the book yet.',
          fragility: 0.86,
          fragilityColor: palette.coral,
          closed: true,
        ),
        const SizedBox(height: 12),
        _CityCard(
          name: 'Greenvale',
          line: 'A farming valley, slow and steady',
          detail: 'Prices for this city are not in the book yet.',
          fragility: 0.18,
          fragilityColor: palette.teal,
          closed: true,
        ),
      ],
    );
  }
}

class _CityCard extends StatelessWidget {
  const _CityCard({
    required this.name,
    required this.line,
    required this.detail,
    required this.fragility,
    required this.fragilityColor,
    this.change,
    this.closed = false,
    this.onTap,
  });

  final String name;
  final String line;
  final String detail;
  final double fragility;
  final Color fragilityColor;
  final double? change;
  final bool closed;
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
          padding: const EdgeInsets.all(18),
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
                    child: Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  ),
                  if (change != null) StreetChange(change: change),
                  if (closed)
                    Container(
                      height: 28,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: palette.line,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text('Closed', style: TextStyle(color: palette.muted, fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(line, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: fragility,
                  minHeight: 6,
                  backgroundColor: palette.line,
                  color: fragilityColor,
                ),
              ),
              const SizedBox(height: 6),
              Text('Fragility', style: TextStyle(color: palette.muted, fontSize: 12)),
              const SizedBox(height: 8),
              Text(detail, style: TextStyle(color: palette.muted, fontSize: 14)),
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
    final selected = controller.selectedPlotId == null ? null : game.plot(controller.selectedPlotId!);
    return Column(
      children: [
        _HarborBar(controller: controller),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return InteractiveViewer(
                minScale: 1,
                maxScale: 2.6,
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Column(
                      children: [
                        const _WaterBand(),
                        for (final street in game.streets)
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
    final you = game.investor('you');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${game.day} of ${Tuning.soloSeasonDays}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const Spacer(),
              Text('Net ${money(game.netWorthOf('you'))}', style: const TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  money(you.cash),
                  style: TextStyle(fontSize: 16, color: you.cash < 0 ? palette.coral : palette.ink),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _TinyButton(
                label: controller.auto ? 'Auto on' : 'Auto',
                filled: controller.auto,
                onPressed: game.finished ? null : () {
                  HapticFeedback.selectionClick();
                  controller.toggleAuto();
                },
              ),
              const SizedBox(width: 8),
              _TinyButton(
                label: 'Next day',
                filled: true,
                onPressed: game.finished
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        controller.nextDay();
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
  const _TinyButton({required this.label, required this.onPressed, required this.filled});

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

class _WaterBand extends StatefulWidget {
  const _WaterBand();

  @override
  State<_WaterBand> createState() => _WaterBandState();
}

class _WaterBandState extends State<_WaterBand> with SingleTickerProviderStateMixin {
  late final AnimationController _beam;

  @override
  void initState() {
    super.initState();
    _beam = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final night = Theme.of(context).brightness == Brightness.dark;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (night && !reduce) {
      if (!_beam.isAnimating) _beam.repeat();
    } else if (_beam.isAnimating) {
      _beam.stop();
    }
  }

  @override
  void dispose() {
    _beam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = HoldingsPalette.of(context);
    final night = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 56,
        child: AnimatedBuilder(
          animation: _beam,
          builder: (context, _) {
            return CustomPaint(
              painter: _WaterPainter(
                color: palette.water,
                beam: night ? _beam.value : null,
                ink: palette.onWater,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.sailing_outlined, color: palette.onWater),
                    const Spacer(),
                    Icon(Icons.light_outlined, color: palette.onWater),
                    const SizedBox(width: 8),
                    Text(
                      'Harborview',
                      style: TextStyle(
                        color: palette.onWater,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WaterPainter extends CustomPainter {
  _WaterPainter({required this.color, required this.ink, required this.beam});

  final Color color;
  final Color ink;
  final double? beam;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    final sweep = beam;
    if (sweep == null) return;
    final angle = (sweep * 2 - 1) * 0.9;
    final origin = Offset(size.width - 28, size.height * 0.45);
    final path = Path()
      ..moveTo(origin.dx, origin.dy)
      ..lineTo(origin.dx - 180, origin.dy + 70 * angle)
      ..lineTo(origin.dx - 40, origin.dy + 18 * angle)
      ..close();
    canvas.drawPath(path, Paint()..color = ink.withValues(alpha: 0.16));
  }

  @override
  bool shouldRepaint(covariant _WaterPainter old) => old.beam != beam || old.color != color;
}

class _StreetRow extends StatelessWidget {
  const _StreetRow({
    required this.game,
    required this.street,
    required this.selectedId,
    required this.onTap,
  });

  final HoldingsGame game;
  final Street street;
  final String? selectedId;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final palette = HoldingsPalette.of(context);
    final plots = game.plots.where((plot) => plot.streetId == street.id).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Text(street.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(width: 8),
            StreetChange(change: game.streetChange(street.id, 1)),
            if (street.rumor != null) ...[
              const SizedBox(width: 8),
              Text('!', style: TextStyle(color: palette.coral, fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final plot in plots)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _PlotTile(
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
  }
}

class _PlotTile extends StatefulWidget {
  const _PlotTile({
    required this.plot,
    required this.game,
    required this.selected,
    required this.onTap,
  });

  final Plot plot;
  final HoldingsGame game;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_PlotTile> createState() => _PlotTileState();
}

class _PlotTileState extends State<_PlotTile> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _PlotTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (widget.selected && !reduce) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating || _pulse.value != 0) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = HoldingsPalette.of(context);
    final plot = widget.plot;
    final income = widget.game.lastIncome[plot.id];
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final bounce = widget.selected ? (1 - _pulse.value) * 4 : 0.0;
          return Stack(
            children: [
              Positioned.fill(
                child: AnimatedContainer(
                  duration: motionOf(context),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: plot.building == null ? palette.sand : palette.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: widget.selected
                          ? palette.teal.withValues(alpha: 0.55 + _pulse.value * 0.45)
                          : plot.ownerId != null
                              ? ownerColor(plot.ownerId)
                              : palette.line,
                      width: widget.selected ? 2 : 1,
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxHeight < 16) return const SizedBox.shrink();
                      final showMark = constraints.maxHeight >= 44;
                      final showIncome = income != null && constraints.maxHeight >= 62;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plot.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          if (showMark) const Spacer(),
                          if (showMark && plot.building == BuildingType.carWash)
                            Icon(Icons.water_drop_outlined, size: 16, color: palette.teal)
                          else if (showMark && plot.building == BuildingType.parking)
                            Icon(Icons.local_parking_outlined, size: 16, color: palette.muted)
                          else if (showMark)
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
              if (widget.selected)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Transform.translate(
                    offset: Offset(0, bounce),
                    child: Icon(Icons.arrow_drop_down, size: 16, color: palette.teal),
                  ),
                ),
            ],
          );
        },
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

  final HoldingsGame game;
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
    final actions = plot.ownerId == null
        ? PillButton(
            label: 'Buy ${money(price)}',
            onPressed: game.finished ? null : onBuy,
          )
        : yours && plot.building == null
            ? Column(
                children: [
                  PillButton(
                    label: _buildLabel(plot, BuildingType.carWash),
                    height: 56,
                    onPressed: game.finished ? null : () => onBuild(BuildingType.carWash),
                  ),
                  const SizedBox(height: 8),
                  PillButton(
                    label: _buildLabel(plot, BuildingType.parking),
                    height: 56,
                    filled: false,
                    onPressed: game.finished ? null : () => onBuild(BuildingType.parking),
                  ),
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(plot.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                ),
              ],
            ),
            Text(street.name, style: TextStyle(color: palette.muted, fontSize: 14)),
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
                child: Text(rumor.spec.rumor, style: const TextStyle(fontSize: 14, height: 1.35)),
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
    );
  }

  String _buildLabel(Plot plot, BuildingType type) {
    final estimate = businessIncome(
      building: type,
      traffic: plot.currentTraffic,
      openForBusiness: true,
    );
    final name = type == BuildingType.carWash ? 'Build a car wash' : 'Build a parking lot';
    final cost = type == BuildingType.carWash ? Tuning.carWashCost : Tuning.parkingCost;
    return '$name\n${money(cost)} · ${signedMoney(estimate)} a day';
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

  final HoldingsGame game;

  @override
  Widget build(BuildContext context) {
    final palette = HoldingsPalette.of(context);
    final items = game.ledger.reversed.toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const Text(
          'News',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.6),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Text('The town is quiet.', style: TextStyle(color: palette.muted, fontSize: 16))
        else
          for (final entry in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Day ${entry.day}', style: TextStyle(color: palette.muted, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(entry.message, style: const TextStyle(fontSize: 16, height: 1.35)),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
