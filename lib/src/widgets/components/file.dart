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

  final String fileName;

  final String fileType;

  final Uint8List? previewImage;

  final String? previewUrl;

  final double size;

  const MagoFilePreview({
    super.key,
    required this.state,
    this.fileName = '',
    this.fileType = '',
    this.previewImage,
    this.previewUrl,
    this.size = 130,
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
        return _buildPreview();
      case FilePreviewState.loadedNoPreview:
        return _buildNoPreview(context);
    }
  }

  Widget _buildLoading() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/defaults/file.png',
          fit: BoxFit.contain,
        ),
        const MagoObjectLoader(
          backgroundColor: Colors.transparent,
          logoSize: 40,
          darkAsset: 'assets/images/logo/pinecone.light.svg',
        ),
      ],
    );
  }

  Widget _buildPreview() {
    final ImageProvider provider;
    if (previewImage != null) {
      provider = MemoryImage(previewImage!);
    } else if (previewUrl != null) {
      provider = NetworkImage(previewUrl!);
    } else {
      return _buildLoading();
    }

    return Image(
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
  }

  Widget _buildNoPreview(BuildContext context) {
    final theme = Theme.of(context);
    final typeLabel = fileType;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/defaults/file.png',
          fit: BoxFit.contain,
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 18.0,
                ),
                if (typeLabel.isNotEmpty)
                  Text(
                    typeLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                      color: MagoColors.neutral500,
                    ),
                  ),
                if (typeLabel.isNotEmpty && fileName.isNotEmpty)
                  const SizedBox(height: 4),
                if (fileName.isNotEmpty)
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: MagoColors.neutral500),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
