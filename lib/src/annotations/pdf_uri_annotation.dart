import '../pdf_graphics.dart';
import 'pdf_annotation.dart';

/// A URI annotation that creates a clickable hyperlink on the page.
class PdfUriAnnotation extends PdfAnnotation {
  final String uri;

  PdfUriAnnotation({
    required Rect bounds,
    required this.uri,
  }) : super(bounds);
}
