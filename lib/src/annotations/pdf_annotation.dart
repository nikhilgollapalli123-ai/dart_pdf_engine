import '../pdf_graphics.dart';

/// Base class for PDF annotations.
abstract class PdfAnnotation {
  final Rect bounds;
  PdfAnnotation(this.bounds);
}
