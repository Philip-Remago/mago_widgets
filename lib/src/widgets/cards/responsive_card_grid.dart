import 'package:flutter/material.dart';

class MagoResponsiveGrid extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  final int minColumns;

  final int maxColumns;

  final double spacing;

  final double childAspectRatio;

  const MagoResponsiveGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.minColumns = 2,
    this.maxColumns = 4,
    this.spacing = 12,
    this.childAspectRatio = 16 / 9,
  });

  int _columnsForWidth(double width) {
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    if (width >= 400) return 2;
    return 1;
  }

  double _aspectRatioForColumns(int cols) {
    if (cols <= minColumns) return 1.0;
    return childAspectRatio;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = _columnsForWidth(constraints.maxWidth)
            .clamp(minColumns, maxColumns);
        final ratio = _aspectRatioForColumns(cols);

        return GridView.builder(
          itemCount: itemCount,
          shrinkWrap: true,
          primary: false,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: ratio,
          ),
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
