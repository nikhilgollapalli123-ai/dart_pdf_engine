// PDF page view widget for rendering a single page.

import 'package:flutter/material.dart';

import '../pdf_page.dart';
import 'pdf_page_renderer.dart';

/// Widget that renders a single PDF page.
///
/// Uses [PdfPageRenderer] to interpret PDF content stream operators
/// and paint them on a Flutter [Canvas] via [CustomPainter].
///
/// Example:
/// ```dart
/// PdfPageView(
///   page: document.pages[0],
///   width: 400,
/// )
/// ```
class PdfPageView extends StatelessWidget {
  /// The PDF page to render.
  final PdfPage page;

  /// The desired display width. Height is calculated from aspect ratio.
  final double? width;

  /// The desired display height. Width is calculated from aspect ratio.
  final double? height;

  /// Optional decoration for the page container (e.g., shadow, border).
  final BoxDecoration? decoration;

  const PdfPageView({
    super.key,
    required this.page,
    this.width,
    this.height,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    final aspectRatio = page.width / page.height;

    double displayWidth;
    double displayHeight;

    if (width != null) {
      displayWidth = width!;
      displayHeight = displayWidth / aspectRatio;
    } else if (height != null) {
      displayHeight = height!;
      displayWidth = displayHeight * aspectRatio;
    } else {
      // Default: fit to available width.
      displayWidth = MediaQuery.of(context).size.width;
      displayHeight = displayWidth / aspectRatio;
    }

    return Container(
      width: displayWidth,
      height: displayHeight,
      decoration: decoration ??
          BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            borderRadius: BorderRadius.circular(2),
          ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        size: Size(displayWidth, displayHeight),
        painter: PdfPageRenderer(
          page: page,
        ),
      ),
    );
  }
}
