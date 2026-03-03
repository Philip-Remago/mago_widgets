import 'package:flutter/material.dart';

@immutable
class MagoStroke {
  const MagoStroke({
    required this.points,
    required this.color,
    required this.width,
    required this.isEraser,
  });

  final List<Offset> points;
  final Color color;
  final double width;
  final bool isEraser;

  MagoStroke copyWith({
    List<Offset>? points,
    Color? color,
    double? width,
    bool? isEraser,
  }) {
    return MagoStroke(
      points: points ?? this.points,
      color: color ?? this.color,
      width: width ?? this.width,
      isEraser: isEraser ?? this.isEraser,
    );
  }
}
