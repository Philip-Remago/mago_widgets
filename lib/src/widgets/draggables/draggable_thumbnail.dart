import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class MagoDraggableThumbnail extends StatefulWidget {
  const MagoDraggableThumbnail({
    super.key,
    required this.path,
    this.size = 130,
    this.feedbackSize = 150,
    this.dragDelay = const Duration(milliseconds: 500),
    this.defaultThumbnail = 'assets/images/defaults/file_preview.png',
  });

  final String path;
  final double size;
  final double feedbackSize;
  final Duration dragDelay;
  final String defaultThumbnail;

  @override
  State<MagoDraggableThumbnail> createState() => _MagoDraggableThumbnailState();
}

class _MagoDraggableThumbnailState extends State<MagoDraggableThumbnail> {
  bool get _isFilePath =>
      !kIsWeb &&
      !widget.path.startsWith('http') &&
      !widget.path.startsWith('note_');

  Widget _buildFallback(double size) {
    return Stack(
      children: [
        Image.asset(
          widget.defaultThumbnail,
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
        if (widget.defaultThumbnail ==
            'assets/images/defaults/file_preview.png')
          SizedBox(
            width: size,
            height: size,
            child: AspectRatio(
              aspectRatio: 1.368,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 16.0,
                  ),
                  Text(
                    'Url',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Text(
                      widget.path,
                      style: TextStyle(
                        fontSize: 10,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImage({required double size, double opacity = 1.0}) {
    return Opacity(
      opacity: opacity,
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          child: _isFilePath
              ? Image.file(
                  File(widget.path),
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, st) => _buildFallback(size),
                )
              : _buildFallback(size),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<String>(
      data: widget.path,
      delay: widget.dragDelay,
      feedback: _buildImage(size: widget.feedbackSize),
      childWhenDragging: _buildImage(size: widget.size, opacity: 0.3),
      child: _buildImage(size: widget.size),
    );
  }
}
