/// PDF constants used throughout the library.
class PdfConstants {
  PdfConstants._();

  /// PDF version header.
  static const String pdfVersion = '%PDF-1.7';

  /// Binary marker after header (ensures binary-safe transport).
  static const List<int> binaryMarker = [0x25, 0xE2, 0xE3, 0xCF, 0xD3];

  /// End of file marker.
  static const String eof = '%%EOF';

  /// Line feed.
  static const int lf = 0x0A;

  /// Carriage return.
  static const int cr = 0x0D;

  /// Space.
  static const int space = 0x20;

  /// Standard page sizes in points (1 point = 1/72 inch).
  static const double pointsPerInch = 72.0;
}
