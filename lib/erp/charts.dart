import 'dart:math' as math;

import 'package:flutter/material.dart';

Color lighten(Color c, [double t = 0.3]) => Color.lerp(c, Colors.white, t)!;
Color darken(Color c, [double t = 0.25]) => Color.lerp(c, Colors.black, t)!;

const _ink = Color(0xFF0F172A);
const _body = Color(0xFF334155);
const _muted = Color(0xFF64748B);

class Slice {
  const Slice(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

class DonutWithLegend extends StatelessWidget {
  const DonutWithLegend({
    super.key,
    required this.slices,
    required this.centerValue,
    required this.centerLabel,
    this.size = 132,
  });
  final List<Slice> slices;
  final String centerValue;
  final String centerLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (a, s) => a + s.value);
    return Row(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(size: Size(size, size), painter: _DonutPainter(slices)),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(centerValue, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink)),
                  Text(centerLabel, style: const TextStyle(fontSize: 10, color: _muted)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in slices)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [lighten(s.color), s.color]),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [BoxShadow(color: s.color.withAlpha(90), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(s.label, style: const TextStyle(fontSize: 12, color: _body), overflow: TextOverflow.ellipsis)),
                      Text(
                        total > 0 ? '${s.value.round()} (${(s.value * 100 / total).round()}%)' : '${s.value.round()}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices);
  final List<Slice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (a, s) => a + s.value);
    final center = Offset(size.width / 2, size.height / 2);
    final outer = math.min(size.width, size.height) / 2 - 8;
    final stroke = outer * 0.40;
    final rect = Rect.fromCircle(center: center, radius: outer - stroke / 2);

    if (total > 0) {
      final shadow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
      canvas.drawArc(rect.shift(const Offset(0, 5)), 0, math.pi * 2, false, shadow);
    }
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFFE2E8F0);
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    if (total <= 0) return;

    final active = slices.where((s) => s.value > 0).toList();
    final gap = active.length > 1 ? 0.035 : 0.0;
    double start = -math.pi / 2;
    for (final s in active) {
      final sweep = s.value / total * math.pi * 2;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [lighten(s.color, 0.25), darken(s.color, 0.1)],
        ).createShader(rect.inflate(stroke / 2));
      canvas.drawArc(rect, start + gap / 2, math.max(0.0, sweep - gap), false, p);
      start += sweep;
    }
    final hi = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x55FFFFFF);
    canvas.drawArc(Rect.fromCircle(center: center, radius: outer - 1.5), 0, math.pi * 2, false, hi);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => true;
}

class BarItem {
  const BarItem(this.label, this.value, {this.valueLabel});
  final String label;
  final double value;
  final String? valueLabel;
}

class BarsChart extends StatelessWidget {
  const BarsChart({super.key, required this.items, required this.color, this.height = 190});
  final List<BarItem> items;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxV = items.fold<double>(0, (m, e) => e.value > m ? e.value : m);
    final barMax = height - 46;
    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final it in items)
              SizedBox(
                width: 50,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(it.valueLabel ?? '${it.value.round()}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _ink)),
                    const SizedBox(height: 4),
                    Container(
                      width: 28,
                      height: maxV > 0 ? math.max(4.0, barMax * it.value / maxV) : 4.0,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(3)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [lighten(color, 0.3), color, darken(color, 0.2)],
                        ),
                        boxShadow: [BoxShadow(color: color.withAlpha(90), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(it.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: _muted)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class LineSeries {
  const LineSeries(this.label, this.values, this.color);
  final String label;
  final List<double> values;
  final Color color;
}

class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.labels, required this.series, this.height = 190});
  final List<String> labels;
  final List<LineSeries> series;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(painter: _TrendPainter(labels, series)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          children: [
            for (final s in series)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 14, height: 4, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 6),
                  Text(s.label, style: const TextStyle(fontSize: 12, color: _body)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.labels, this.series);
  final List<String> labels;
  final List<LineSeries> series;

  void _text(Canvas c, String t, double x, double y, {bool center = false, bool right = false}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: const TextStyle(fontSize: 9, color: _muted)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = center ? x - tp.width / 2 : (right ? x - tp.width : x);
    tp.paint(c, Offset(dx, y));
  }

  double _nice(double v) {
    if (v <= 4) return 4;
    final p = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    return (v / p).ceil() * p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0, right = 8.0, top = 10.0, bottom = 22.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    double maxV = 1;
    for (final s in series) {
      for (final v in s.values) {
        if (v > maxV) maxV = v;
      }
    }
    maxV = _nice(maxV);

    final grid = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = top + h - h * i / 4;
      canvas.drawLine(Offset(left, y), Offset(left + w, y), grid);
      _text(canvas, '${(maxV * i / 4).round()}', left - 6, y - 5, right: true);
    }

    final n = labels.length;
    if (n == 0) return;
    double xAt(int i) => n <= 1 ? left + w / 2 : left + w * i / (n - 1);
    double yAt(double v) => top + h - h * (v / maxV);

    final step = math.max(1, (n / 6).ceil());
    for (var i = 0; i < n; i += step) {
      _text(canvas, labels[i], xAt(i), top + h + 6, center: true);
    }

    for (var si = 0; si < series.length; si++) {
      final s = series[si];
      if (s.values.isEmpty) continue;
      final path = Path();
      for (var i = 0; i < s.values.length && i < n; i++) {
        final x = xAt(i), y = yAt(s.values[i]);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      if (si == 0 && s.values.length > 1) {
        final area = Path.from(path)
          ..lineTo(xAt(math.min(s.values.length, n) - 1), top + h)
          ..lineTo(xAt(0), top + h)
          ..close();
        canvas.drawPath(
          area,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [s.color.withAlpha(90), s.color.withAlpha(5)],
            ).createShader(Rect.fromLTWH(left, top, w, h)),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = s.color,
      );
      for (var i = 0; i < s.values.length && i < n; i++) {
        canvas.drawCircle(Offset(xAt(i), yAt(s.values[i])), 3.6, Paint()..color = Colors.white);
        canvas.drawCircle(Offset(xAt(i), yAt(s.values[i])), 2.4, Paint()..color = s.color);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => true;
}