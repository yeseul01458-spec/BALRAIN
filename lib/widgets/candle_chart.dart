import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

import '../models/stock_models.dart';
import '../theme/app_colors.dart';

class CandleChart extends StatefulWidget {
  final List<Candle> candles;
  const CandleChart({super.key, required this.candles});
  @override
  State<CandleChart> createState() => _CandleChartState();
}

class _CandleChartState extends State<CandleChart> {
  double _scale = 1.0;
  double _previousScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _startOffset = Offset.zero;
  Offset? _touchPosition;
  int? _selectedIndex;

  Offset _globalToLocal(Offset global) {
    final box = context.findRenderObject() as RenderBox;
    return box.globalToLocal(global);
  }

  void _updateSelection(Offset localPos, Size size) {
    const leftPad = 52.0, rightPad = 8.0;
    final plotW = size.width - leftPad - rightPad;
    final n = widget.candles.length;
    if (n < 2) return;
    final chartX = (localPos.dx - _offset.dx) / _scale;
    final t = ((chartX - leftPad) / plotW).clamp(0.0, 1.0);
    final idx = ((t * (n - 1)).round()).toInt();
    setState(() {
      _touchPosition = localPos;
      _selectedIndex = idx;
    });
  }

  double _indexToScreenX(int idx, Size size) {
    const leftPad = 52.0, rightPad = 8.0;
    final plotW = size.width - leftPad - rightPad;
    final n = widget.candles.length;
    final xChart = leftPad + (idx / (n - 1)) * plotW;
    return _offset.dx + xChart * _scale;
  }

  double _priceToScreenY(double price, Size size) {
    const leftPad = 52.0, rightPad = 8.0, topPad = 10.0, bottomPad = 26.0;
    final plotH = size.height - topPad - bottomPad;

    double minY = widget.candles.map((c) => c.l).reduce(math.min);
    double maxY = widget.candles.map((c) => c.h).reduce(math.max);
    if ((maxY - minY).abs() < 1e-9) {
      maxY += 1;
      minY -= 1;
    }

    final t = ((price - minY) / (maxY - minY));
    final yChart = topPad + (1 - t) * plotH;
    return _offset.dy + yChart * _scale;
  }

  void _onScaleStart(ScaleStartDetails d) {
    _previousScale = _scale;
    _startOffset = d.focalPoint - _offset;
  }

  void _onScaleUpdate(ScaleUpdateDetails d, Size size) {
    if (d.scale != 1.0) {
      setState(() {
        _scale = (_previousScale * d.scale).clamp(0.5, 4.5);
        _offset = d.focalPoint - _startOffset;
      });
      return;
    }
    final local = _globalToLocal(d.focalPoint);
    _updateSelection(local, size);
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _previousScale = 1.0;
  }

  void _onDoubleTap() {
    setState(() {
      _scale = 1.0;
      _offset = Offset.zero;
      _touchPosition = null;
      _selectedIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        final size = cons.biggest;
        final hasSel = _selectedIndex != null;
        final Candle? selected =
        hasSel ? widget.candles[_selectedIndex!] : null;

        Offset? tooltipPos;
        if (hasSel && _touchPosition != null) {
          final dx = _touchPosition!.dx.clamp(0, size.width - 140);
          tooltipPos = Offset(dx.toDouble(), 0);
        }

        double? crossX, crossY;
        if (hasSel && selected != null) {
          crossX = _indexToScreenX(_selectedIndex!, size);
          crossY = _priceToScreenY(selected.c, size);
        }

        return GestureDetector(
          onScaleStart: _onScaleStart,
          onScaleEnd: _onScaleEnd,
          onDoubleTap: _onDoubleTap,
          onScaleUpdate: (d) => _onScaleUpdate(d, size),
          onTapDown: (t) => _updateSelection(t.localPosition, size),
          child: ClipRect(
            child: Stack(
              children: [
                Transform(
                  transform: Matrix4.identity()
                    ..translate(
                      _offset.dx,
                      _offset.dy,
                    )
                    ..scale(_scale),
                  child: CustomPaint(
                    painter: CandlePainter(widget.candles),
                    size: size,
                    willChange: false,
                  ),
                ),
                if (crossX != null && crossY != null)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _CrosshairPainter(
                        crossX: crossX,
                        crossY: crossY,
                      ),
                      size: size,
                    ),
                  ),
                if (selected != null && tooltipPos != null)
                  Positioned(
                    left: tooltipPos.dx,
                    top: tooltipPos.dy,
                    child: _buildTooltip(selected),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTooltip(Candle c) {
    final f = NumberFormat('#,##0.00');
    final df = DateFormat('yyyy.MM.dd');
    return Card(
      color: Colors.white.withOpacity(0.92),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              df.format(c.t),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text('시가: ${f.format(c.o)}'),
            Text('고가: ${f.format(c.h)}'),
            Text('저가: ${f.format(c.l)}'),
            Text(
              '종가: ${f.format(c.c)}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CandlePainter extends CustomPainter {
  final List<Candle> candles;
  CandlePainter(this.candles);

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    const leftPad = 52.0;
    const rightPad = 8.0;
    const topPad = 10.0;
    const bottomPad = 26.0;
    final plotW = size.width - leftPad - rightPad;
    final plotH = size.height - topPad - bottomPad;
    final plotRect = Rect.fromLTWH(
      leftPad,
      topPad,
      plotW,
      plotH,
    );

    double minY = candles.map((c) => c.l).reduce(math.min);
    double maxY = candles.map((c) => c.h).reduce(math.max);
    if ((maxY - minY).abs() < 1e-9) {
      maxY += 1;
      minY -= 1;
    }

    final border = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke;
    canvas.drawRect(plotRect, border);

    // y grid + labels
    const tickCount = 4;
    const textStyle = TextStyle(
      fontSize: 10,
      color: Colors.black54,
    );
    for (int i = 0; i <= tickCount; i++) {
      final t = i / tickCount;
      final y = topPad + (1 - t) * plotH;
      final grid = Paint()
        ..color = const Color(0xFFF3F4F6)
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        grid,
      );

      final value = minY + (maxY - minY) * t;
      final tp = TextPainter(
        text: TextSpan(
          text: value.toStringAsFixed(0),
          style: textStyle,
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(leftPad - 6 - tp.width, y - tp.height / 2),
      );
    }

    // x labels
    const btmTicks = 4;
    for (int i = 0; i <= btmTicks; i++) {
      final t = i / btmTicks;
      final idx = (t * (candles.length - 1)).round();
      final x = leftPad + t * plotW;
      final d = candles[idx].t;
      final label = DateFormat('MM/dd').format(d);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: textStyle,
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          x - tp.width / 2,
          size.height - bottomPad + 6,
        ),
      );
    }

    // candles
    final candleWidth = math.max(2.0, plotW / (candles.length * 1.5));
    final wickWidth = math.max(1.0, candleWidth * 0.25);
    const upColor = Color(0xFF1E3A8A);
    const dnColor = Color(0xFFE11D48);

    double yPos(double price) {
      final t = (price - minY) / (maxY - minY);
      return topPad + (1 - t) * plotH;
    }

    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final x = leftPad + (i / (candles.length - 1)) * plotW;
      final isUp = c.c >= c.o;
      final color = isUp ? upColor : dnColor;

      final wickPaint = Paint()
        ..color = color
        ..strokeWidth = wickWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x, yPos(c.h)),
        Offset(x, yPos(c.l)),
        wickPaint,
      );

      final bodyPaint = Paint()..color = color;
      final bodyLeft = x - candleWidth / 2;
      final bodyRight = x + candleWidth / 2;
      final yOpen = yPos(c.o);
      final yClose = yPos(c.c);
      final bodyTop = math.min(yOpen, yClose);
      final bodyBottom = math.max(yOpen, yClose);

      if ((bodyBottom - bodyTop) < 1) {
        canvas.drawRect(
          Rect.fromLTRB(
            bodyLeft,
            bodyTop - 0.5,
            bodyRight,
            bodyBottom + 0.5,
          ),
          bodyPaint,
        );
      } else {
        canvas.drawRect(
          Rect.fromLTRB(
            bodyLeft,
            bodyTop,
            bodyRight,
            bodyBottom,
          ),
          bodyPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CrosshairPainter extends CustomPainter {
  final double crossX;
  final double crossY;
  _CrosshairPainter({
    required this.crossX,
    required this.crossY,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFF9CA3AF)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(crossX, 0),
      Offset(crossX, size.height),
      line,
    );
    canvas.drawLine(
      Offset(0, crossY),
      Offset(size.width, crossY),
      line,
    );
    final dot = Paint()..color = kBrand;
    canvas.drawCircle(
      Offset(crossX, crossY),
      3,
      dot,
    );
  }

  @override
  bool shouldRepaint(covariant _CrosshairPainter old) =>
      old.crossX != crossX || old.crossY != crossY;
}
