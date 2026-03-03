import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

class MagoQr extends StatelessWidget {
  const MagoQr({
    super.key,
    required this.data,
    this.size = 200,
    this.color,
    this.backgroundColor,
    this.errorCorrectionLevel = QrErrorCorrectLevel.M,
    this.moduleRoundness = 0,
    this.borderRadius = 0.3,
    this.padding = const EdgeInsets.all(12),
  });

  final String data;

  final double size;

  final Color? color;

  final Color? backgroundColor;

  final int errorCorrectionLevel;

  final double moduleRoundness;

  final double borderRadius;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedColor = color ?? theme.colorScheme.onSurface;
    final resolvedBg = backgroundColor ?? Colors.transparent;

    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: errorCorrectionLevel,
    );

    final qrImage = QrImage(qrCode);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: size,
        height: size,
        padding: padding,
        decoration: BoxDecoration(color: resolvedBg),
        child: PrettyQrView(
          qrImage: qrImage,
          decoration: PrettyQrDecoration(
            shape: moduleRoundness > 0.5
                ? PrettyQrSmoothSymbol(color: resolvedColor)
                : PrettyQrRoundedSymbol(
                    color: resolvedColor,
                    borderRadius: BorderRadius.circular(moduleRoundness * 8),
                  ),
          ),
        ),
      ),
    );
  }
}
