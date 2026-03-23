import 'pdf_color.dart';

/// Abstract brush for filling shapes and text.
abstract class PdfBrush {
  /// Get the color of this brush.
  PdfColor get color;
}

/// Solid color brush.
class PdfSolidBrush extends PdfBrush {
  @override
  final PdfColor color;

  PdfSolidBrush(this.color);
}
