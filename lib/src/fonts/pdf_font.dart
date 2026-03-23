import 'font_metrics.dart';

/// Abstract base class for all PDF fonts.
abstract class PdfFont {
  /// The font size in points.
  double get size;

  /// The internal PDF font name.
  String get name;

  /// Get the font metrics.
  FontMetrics get metrics;

  /// Measure the width of a string in points.
  double measureString(String text) {
    return metrics.measureString(text, size);
  }

  /// Get the line height in points.
  double get lineHeight => metrics.getLineHeight(size);

  /// Get the ascent in points.
  double get ascent => metrics.ascent * size / 1000.0;

  /// Get the descent in points (negative value).
  double get descent => metrics.descent * size / 1000.0;
}
