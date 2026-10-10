import 'package:flutter/material.dart';

import 'format.dart';
import 'theme.dart';

class WorthFigure extends StatelessWidget {
  const WorthFigure({super.key, required this.value, this.size = 40});

  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = HoldingsPalette.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: motionOf(context),
      curve: Curves.easeOutCubic,
      builder: (context, shown, _) {
        return Text(
          money(shown),
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w600,
            letterSpacing: -1.2,
            color: palette.ink,
            height: 1,
          ),
        );
      },
    );
  }
}

class WorthChart extends StatelessWidget {
  const WorthChart({
    super.key,
    required this.you,
    required this.rival,
    required this.rivalColor,
    this.height = 108,
  });

  final List<double> you;
  final List<double> rival;
  final Color rivalColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = HoldingsPalette.of(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey(you.length),
      tween: Tween(begin: 0, end: 1),
      duration: motionOf(context),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _WorthPainter(
              you: you,
              rival: rival,
              youColor: palette.teal,
              rivalColor: rivalColor,
              progress: t,
            ),
          ),
        );
      },
    );
  }
}

class _WorthPainter extends CustomPainter {
  _WorthPainter({
    required this.you,
    required this.rival,
    required this.youColor,
    required this.rivalColor,
    required this.progress,
  });

  final List<double> you;
  final List<double> rival;
  final Color youColor;
  final Color rivalColor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (you.length < 2) return;
    final all = [...you, ...rival];
    final minV = all.reduce((a, b) => a < b ? a : b);
    final maxV = all.reduce((a, b) => a > b ? a : b);
    final span = (maxV - minV).abs() < 1 ? 1.0 : maxV - minV;
    final last = (you.length - 1) * progress;
    _draw(canvas, size, you, youColor, minV, span, last, fill: true);
    if (rival.length >= 2) {
      _draw(canvas, size, rival, rivalColor, minV, span, last, fill: false);
    }
  }

  void _draw(
    Canvas canvas,
    Size size,
    List<double> values,
    Color color,
    double minV,
    double span,
    double last, {
    required bool fill,
  }) {
    final path = Path();
    final count = values.length;
    var started = false;
    for (var i = 0; i < count; i++) {
      if (i > last) break;
      final x = size.width * i / (count - 1);
      final y = size.height - ((values[i] - minV) / span) * (size.height - 8) - 4;
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }
    if (!started) return;
    if (fill) {
      final filled = Path.from(path)
        ..lineTo(size.width * (last.clamp(0, count - 1)) / (count - 1), size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(filled, Paint()..color = color.withValues(alpha: 0.12));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = fill ? 2.4 : 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _WorthPainter old) {
    return old.you != you || old.rival != rival || old.progress != progress;
  }
}

class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final palette = HoldingsPalette.of(context);
    return Material(
      color: palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: palette.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = true,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = HoldingsPalette.of(context);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: filled ? palette.ink : palette.card,
          foregroundColor: filled ? palette.bg : palette.ink,
          disabledBackgroundColor: palette.line,
          disabledForegroundColor: palette.muted,
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.15),
          side: filled ? null : BorderSide(color: palette.line),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

class StreetChange extends StatelessWidget {
  const StreetChange({super.key, required this.change});

  final double? change;

  @override
  Widget build(BuildContext context) {
    final palette = HoldingsPalette.of(context);
    final up = (change ?? 0) > 0.0005;
    final down = (change ?? 0) < -0.0005;
    final color = up ? palette.teal : down ? palette.coral : palette.muted;
    final arrow = up ? '↑ ' : down ? '↓ ' : '';
    return Text(
      '$arrow${signedPercent(change)}',
      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14),
    );
  }
}
