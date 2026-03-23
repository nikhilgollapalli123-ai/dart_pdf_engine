import 'pdf_color.dart';

/// Dash style for pen strokes.
enum PdfDashStyle {
  solid,
  dash,
  dot,
  dashDot,
  dashDotDot,
}

/// Pen for stroking shapes and lines.
class PdfPen {
  final PdfColor color;
  final double width;
  final PdfDashStyle dashStyle;

  PdfPen(
    this.color, {
    this.width = 1.0,
    this.dashStyle = PdfDashStyle.solid,
  });

  /// Get the PDF dash array operator.
  String toDashOperator() {
    switch (dashStyle) {
      case PdfDashStyle.solid:
        return '[] 0 d';
      case PdfDashStyle.dash:
        return '[${width * 3} ${width * 1}] 0 d';
      case PdfDashStyle.dot:
        return '[${width * 1} ${width * 1}] 0 d';
      case PdfDashStyle.dashDot:
        return '[${width * 3} ${width * 1} ${width * 1} ${width * 1}] 0 d';
      case PdfDashStyle.dashDotDot:
        return '[${width * 3} ${width * 1} ${width * 1} ${width * 1} ${width * 1} ${width * 1}] 0 d';
    }
  }
}
