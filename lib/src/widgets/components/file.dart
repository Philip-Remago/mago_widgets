import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mago_widgets/src/config/theme.dart';
import 'package:mago_widgets/src/widgets/components/object_loader.dart';

enum FilePreviewState {
  loading,

  loadedWithPreview,

  loadedNoPreview,
}

class MagoFilePreview extends StatelessWidget {
  final FilePreviewState state;

  final String? fileName;

  final String fileType;

  final Uint8List? previewImage;

  final String? previewUrl;

  final String? previewAsset;

  final double size;

  final double textSpacing;

  final TextStyle? fileTypeStyle;

  final TextStyle? fileNameStyle;

  final double? textPadding;

  final bool showFileName;

  const MagoFilePreview({
    super.key,
    required this.state,
    this.fileName,
    this.fileType = '',
    this.previewImage,
    this.previewUrl,
    this.previewAsset,
    this.size = 130,
    this.textSpacing = 55.0,
    this.fileTypeStyle,
    this.fileNameStyle,
    this.textPadding,
    this.showFileName = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (state) {
      case FilePreviewState.loading:
        return _buildLoading();
      case FilePreviewState.loadedWithPreview:
        return _buildPreview(context);
      case FilePreviewState.loadedNoPreview:
        return _buildNoPreview(context);
    }
  }

  Widget _buildLoading() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/defaults/icons/file.png',
          fit: BoxFit.contain,
        ),
        const MagoObjectLoader(
          backgroundColor: Colors.transparent,
          logoSize: 40,
          darkAsset: 'assets/images/defaults/logo/pinecone.light.svg',
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context) {
    final ImageProvider provider;
    if (previewImage != null) {
      provider = MemoryImage(previewImage!);
    } else if (previewUrl != null) {
      provider = NetworkImage(previewUrl!);
    } else if (previewAsset != null) {
      provider = AssetImage(previewAsset!);
    } else {
      return _buildLoading();
    }

    final image = Image(
      image: provider,
      fit: BoxFit.contain,
      width: size,
      height: size,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return _buildLoading();
      },
      errorBuilder: (_, __, ___) => _buildLoading(),
    );

    final hasFileName =
        showFileName && fileName != null && fileName!.isNotEmpty;
    if (!hasFileName) return image;

    final theme = Theme.of(context);
    final resolvedNameStyle = fileNameStyle ??
        theme.textTheme.bodySmall?.copyWith(color: MagoColors.neutral500);
    final hPad = textPadding ?? size * 0.15;

    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        Positioned.fill(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Text(
                fileName!,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: resolvedNameStyle,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoPreview(BuildContext context) {
    final theme = Theme.of(context);
    final typeLabel = fileType;
    final hasFileName = fileName != null && fileName!.isNotEmpty;

    final resolvedTypeStyle = fileTypeStyle ??
        theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: MagoColors.neutral500,
        );

    final resolvedNameStyle = fileNameStyle ??
        theme.textTheme.bodySmall?.copyWith(color: MagoColors.neutral500);

    final hPad = textPadding ?? size * 0.15;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/defaults/icons/file.png',
          fit: BoxFit.contain,
        ),
        if (typeLabel.isNotEmpty)
          Positioned.fill(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    typeLabel,
                    textAlign: TextAlign.center,
                    style: resolvedTypeStyle,
                  ),
                ),
              ),
            ),
          ),
        if (typeLabel.isNotEmpty && hasFileName)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Opacity(
                      opacity: 0,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: hPad),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            typeLabel,
                            textAlign: TextAlign.center,
                            style: resolvedTypeStyle,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: textSpacing),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: hPad),
                          child: Text(
                            fileName!,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: resolvedNameStyle,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          )
        else if (hasFileName)
          Positioned.fill(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Text(
                  fileName!,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: resolvedNameStyle,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
