import 'package:flutter/material.dart';

enum DrawingTool { pen, eraser }

enum DoodleBackgroundStyle { none, dots, lines, grid }

class DrawingStroke {
  DrawingStroke({
    required this.points,
    required this.color,
    required this.width,
    required this.tool,
  });

  final List<Offset> points;
  final Color color;
  final double width;
  final DrawingTool tool;
}

class JournalDrawingCanvas extends StatelessWidget {
  const JournalDrawingCanvas({
    super.key,
    required this.repaintKey,
    required this.strokes,
    required this.activeStroke,
    required this.baseImageUrl,
    required this.backgroundStyle,
    required this.backgroundSpacing,
    required this.onStrokeStart,
    required this.onStrokeUpdate,
    required this.onStrokeEnd,
  });

  final GlobalKey repaintKey;
  final List<DrawingStroke> strokes;
  final DrawingStroke? activeStroke;
  final String? baseImageUrl;
  final DoodleBackgroundStyle backgroundStyle;
  final double backgroundSpacing;
  final ValueChanged<Offset> onStrokeStart;
  final ValueChanged<Offset> onStrokeUpdate;
  final VoidCallback onStrokeEnd;

  @override
  Widget build(BuildContext context) {
    final allStrokes = <DrawingStroke>[...strokes];
    if (activeStroke != null) {
      allStrokes.add(activeStroke!);
    }

    return RepaintBoundary(
      key: repaintKey,
      child: ColoredBox(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: DoodleBackgroundPainter(
                  style: backgroundStyle,
                  spacing: backgroundSpacing,
                ),
              ),
            ),
            if (baseImageUrl != null && baseImageUrl!.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: Image.network(
                    baseImageUrl!,
                    fit: BoxFit.fill,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) => onStrokeStart(details.localPosition),
              onPanUpdate: (details) => onStrokeUpdate(details.localPosition),
              onPanEnd: (_) => onStrokeEnd(),
              onPanCancel: onStrokeEnd,
              child: CustomPaint(
                painter: _JournalDrawingPainter(strokes: allStrokes),
                size: Size.infinite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DoodleBackgroundPainter extends CustomPainter {
  DoodleBackgroundPainter({required this.style, required this.spacing});

  final DoodleBackgroundStyle style;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    if (style == DoodleBackgroundStyle.none) {
      return;
    }

    final paint = Paint()
      ..color = const Color(0xFF5F6B7A).withValues(alpha: 0.2)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.fill;
    final unit = spacing.clamp(12, 48);

    switch (style) {
      case DoodleBackgroundStyle.none:
        return;
      case DoodleBackgroundStyle.dots:
        for (var y = unit / 2; y < size.height; y += unit) {
          for (var x = unit / 2; x < size.width; x += unit) {
            canvas.drawCircle(Offset(x, y), 1.2, paint);
          }
        }
        break;
      case DoodleBackgroundStyle.lines:
        final linePaint = Paint()
          ..color = paint.color
          ..strokeWidth = 0.8;
        for (var y = unit / 2; y < size.height; y += unit) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
        }
        break;
      case DoodleBackgroundStyle.grid:
        final linePaint = Paint()
          ..color = paint.color
          ..strokeWidth = 0.8;
        for (var y = 0.0; y < size.height; y += unit) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
        }
        for (var x = 0.0; x < size.width; x += unit) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant DoodleBackgroundPainter oldDelegate) {
    return oldDelegate.style != style || oldDelegate.spacing != spacing;
  }
}

class _JournalDrawingPainter extends CustomPainter {
  _JournalDrawingPainter({required this.strokes});

  final List<DrawingStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());

    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true
        ..strokeWidth = stroke.width
        ..color = stroke.tool == DrawingTool.eraser
            ? Colors.transparent
            : stroke.color
        ..blendMode = stroke.tool == DrawingTool.eraser
            ? BlendMode.clear
            : BlendMode.srcOver;

      if (stroke.points.length == 1) {
        final point = stroke.points.first;
        canvas.drawCircle(
          point,
          stroke.width / 2,
          paint..style = PaintingStyle.fill,
        );
        continue;
      }

      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (var i = 1; i < stroke.points.length; i++) {
        final prev = stroke.points[i - 1];
        final curr = stroke.points[i];
        final mx = (prev.dx + curr.dx) / 2;
        final my = (prev.dy + curr.dy) / 2;
        path.quadraticBezierTo(prev.dx, prev.dy, mx, my);
      }
      path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _JournalDrawingPainter oldDelegate) {
    return oldDelegate.strokes != strokes;
  }
}
