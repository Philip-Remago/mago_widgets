import 'package:flutter/material.dart';

class GridCellRect {
  final int x;

  final int y;

  final int xSpan;

  final int ySpan;

  const GridCellRect({
    required this.x,
    required this.y,
    this.xSpan = 1,
    this.ySpan = 1,
  });
}

class OccupiedCell {
  final int x;

  final int y;

  const OccupiedCell({required this.x, required this.y});
}

class MagoGridSpacePainter extends CustomPainter {
  final double xSpacing;
  final double ySpacing;

  final double gap;
  final Offset offset;

  final Color cellColor;
  final Color cellOccupiedColor;

  final Color cellBorderColor;
  final double cellBorderWidth;
  final double cellBorderRadius;

  final List<GridCellRect>? customCells;

  final List<OccupiedCell>? occupiedCells;

  final (int, int)? hoverCell;

  final Color hoverOutlineColor;
  final double hoverOutlineWidth;

  const MagoGridSpacePainter({
    required this.xSpacing,
    required this.ySpacing,
    this.gap = 8,
    this.offset = Offset.zero,
    this.cellColor = const Color.fromARGB(255, 80, 80, 80),
    this.cellOccupiedColor = const Color.fromARGB(255, 37, 37, 37),
    this.cellBorderColor = const Color.fromARGB(255, 255, 255, 255),
    this.cellBorderWidth = 1,
    this.cellBorderRadius = 8.0,
    this.customCells,
    this.occupiedCells,
    this.hoverCell,
    this.hoverOutlineColor = Colors.white,
    this.hoverOutlineWidth = 2.0,
  })  : assert(xSpacing > 0),
        assert(ySpacing > 0),
        assert(gap >= 0);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final fillPaint = Paint()
      ..color = cellColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = cellBorderColor
      ..strokeWidth = cellBorderWidth
      ..style = PaintingStyle.stroke;

    if (customCells != null && customCells!.isNotEmpty) {
      _paintCustomCells(canvas, size, fillPaint, borderPaint);
    } else {
      _paintUniformGrid(canvas, size, fillPaint, borderPaint);
    }
  }

  bool _isCellOccupied(int x, int y) {
    if (occupiedCells == null) return false;
    return occupiedCells!.any((c) => c.x == x && c.y == y);
  }

  bool _isHoverCell(int x, int y) {
    if (hoverCell == null) return false;
    return hoverCell!.$1 == x && hoverCell!.$2 == y;
  }

  void _paintCustomCells(
    Canvas canvas,
    Size size,
    Paint fillPaint,
    Paint borderPaint,
  ) {
    final hoverPaint = Paint()
      ..color = hoverOutlineColor
      ..strokeWidth = hoverOutlineWidth
      ..style = PaintingStyle.stroke;

    final occupiedPaint = Paint()
      ..color = cellOccupiedColor
      ..style = PaintingStyle.fill;

    for (final cell in customCells!) {
      final cellW = xSpacing * cell.xSpan - gap;
      final cellH = ySpacing * cell.ySpan - gap;

      final px = cell.x * xSpacing + gap / 2.0;
      final py = cell.y * ySpacing + gap / 2.0;

      final rect = Rect.fromLTWH(px, py, cellW, cellH);
      final rRect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(cellBorderRadius),
      );

      if (rect.right < 0 ||
          rect.bottom < 0 ||
          rect.left > size.width ||
          rect.top > size.height) {
        continue;
      }

      final isOccupied = _isCellOccupied(cell.x, cell.y);
      canvas.drawRRect(rRect, isOccupied ? occupiedPaint : fillPaint);

      if ((cellBorderColor.a * 255.0).round() != 0 && cellBorderWidth > 0) {
        canvas.drawRRect(rRect, borderPaint);
      }

      if (_isHoverCell(cell.x, cell.y)) {
        canvas.drawRRect(rRect, hoverPaint);
      }
    }
  }

  void _paintUniformGrid(
    Canvas canvas,
    Size size,
    Paint fillPaint,
    Paint borderPaint,
  ) {
    final cellW = (xSpacing - gap).clamp(0.0, xSpacing);
    final cellH = (ySpacing - gap).clamp(0.0, ySpacing);

    final insetX = (xSpacing - cellW) / 2.0;
    final insetY = (ySpacing - cellH) / 2.0;

    final dx = _mod(offset.dx, xSpacing);
    final dy = _mod(offset.dy, ySpacing);

    final hoverPaint = Paint()
      ..color = hoverOutlineColor
      ..strokeWidth = hoverOutlineWidth
      ..style = PaintingStyle.stroke;

    final occupiedPaint = Paint()
      ..color = cellOccupiedColor
      ..style = PaintingStyle.fill;

    int yi = 0;
    for (double py = -dy; py < size.height; py += ySpacing) {
      int xi = 0;
      for (double px = -dx; px < size.width; px += xSpacing) {
        final rect = Rect.fromLTWH(px + insetX, py + insetY, cellW, cellH);
        final rRect = RRect.fromRectAndRadius(
          rect,
          Radius.circular(cellBorderRadius),
        );

        if (rect.right < 0 ||
            rect.bottom < 0 ||
            rect.left > size.width ||
            rect.top > size.height) {
          xi++;
          continue;
        }

        final isOccupied = _isCellOccupied(xi, yi);
        canvas.drawRRect(rRect, isOccupied ? occupiedPaint : fillPaint);

        if ((cellBorderColor.a * 255.0).round() != 0 && cellBorderWidth > 0) {
          canvas.drawRRect(rRect, borderPaint);
        }

        if (_isHoverCell(xi, yi)) {
          canvas.drawRRect(rRect, hoverPaint);
        }

        xi++;
      }
      yi++;
    }
  }

  double _mod(double value, double modulo) {
    final m = value % modulo;
    return m < 0 ? m + modulo : m;
  }

  @override
  bool shouldRepaint(covariant MagoGridSpacePainter oldDelegate) {
    return xSpacing != oldDelegate.xSpacing ||
        ySpacing != oldDelegate.ySpacing ||
        gap != oldDelegate.gap ||
        offset != oldDelegate.offset ||
        cellColor != oldDelegate.cellColor ||
        cellOccupiedColor != oldDelegate.cellOccupiedColor ||
        cellBorderColor != oldDelegate.cellBorderColor ||
        cellBorderWidth != oldDelegate.cellBorderWidth ||
        cellBorderRadius != oldDelegate.cellBorderRadius ||
        customCells != oldDelegate.customCells ||
        occupiedCells != oldDelegate.occupiedCells ||
        hoverCell != oldDelegate.hoverCell;
  }
}
