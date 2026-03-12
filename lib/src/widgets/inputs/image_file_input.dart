import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../helpers/constants.dart';
import '../components/glass_container.dart';

class MagoImageFileInput extends StatefulWidget {
  final Future<Uint8List?> Function()? onPickImage;

  final String placeholder;

  final double? height;
  final double? width;
  final Color? fillColor;
  final BorderRadius borderRadius;

  final Uint8List? initialBytes;
  final ValueChanged<Uint8List?>? onChanged;

  const MagoImageFileInput({
    super.key,
    this.onPickImage,
    this.placeholder = 'Tap to select image',
    this.height = 140,
    this.width,
    this.fillColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
    this.initialBytes,
    this.onChanged,
  });

  @override
  State<MagoImageFileInput> createState() => _MagoImageFileInputState();
}

class _MagoImageFileInputState extends State<MagoImageFileInput> {
  Uint8List? _bytes;
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    _bytes = widget.initialBytes;
  }

  Future<void> _pick() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    try {
      Uint8List? picked;

      if (widget.onPickImage != null) {
        picked = await widget.onPickImage!();
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
          lockParentWindow: true,
        );
        picked = result?.files.firstOrNull?.bytes;
      }

      if (!mounted) return;

      if (picked != null) {
        setState(() => _bytes = picked);
        widget.onChanged?.call(picked);
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _remove() {
    setState(() => _bytes = null);
    widget.onChanged?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final resolvedFill =
        widget.fillColor ?? theme.colorScheme.surfaceContainerHighest;

    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface,
    );

    final hintStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withAlpha(128),
    );

    return GlassContainer(
      borderRadius: widget.borderRadius,
      glassProperties: GlassProperties(backgroundColor: resolvedFill),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _isPicking ? null : _pick,
          child: SizedBox(
            height: widget.height,
            width: widget.width ?? double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _isPicking
                      ? Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onSurface.withAlpha(128),
                            ),
                          ),
                        )
                      : _bytes == null
                          ? Center(
                              child: Text(
                                widget.placeholder,
                                style: hintStyle ?? textStyle,
                                textAlign: TextAlign.center,
                              ),
                            )
                          : Center(
                              child: Image.memory(
                                _bytes!,
                                fit: BoxFit.contain,
                              ),
                            ),
                ),
                if (_bytes != null && !_isPicking)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: theme.colorScheme.surface.withAlpha(200),
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _remove,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
