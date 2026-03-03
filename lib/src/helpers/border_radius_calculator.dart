import 'package:flutter/widgets.dart';

class MagoBorderRadiusCalculator {
  BorderRadius calculate(
      BorderRadius radius, double by, TextDirection direction) {
    final r = radius.resolve(direction);

    Radius deflate(Radius x) => Radius.elliptical(
          (x.x - by).clamp(0, x.x),
          (x.y - by).clamp(0, x.y),
        );

    return BorderRadius.only(
      topLeft: deflate(r.topLeft),
      topRight: deflate(r.topRight),
      bottomLeft: deflate(r.bottomLeft),
      bottomRight: deflate(r.bottomRight),
    );
  }
}
