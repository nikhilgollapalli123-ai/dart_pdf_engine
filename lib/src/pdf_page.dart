import 'pdf_graphics.dart';

/// Represents a single page in a PDF document.
class PdfPage {
  final PdfPageSettings settings;
  late final PdfGraphics _graphics;

  PdfPage({PdfPageSettings? settings})
      : settings = settings ?? PdfPageSettings() {
    _graphics = PdfGraphics(
      this.settings.size.width,
      this.settings.size.height,
    );
  }

  /// Create a page from parsed PDF data.
  PdfPage.fromParsed({
    required double width,
    required double height,
    String? contentStream,
  }) : settings = PdfPageSettings(size: PdfPageSize(width, height)) {
    if (contentStream != null) {
      _graphics = PdfGraphics.fromParsed(width, height, contentStream);
    } else {
      _graphics = PdfGraphics(width, height);
    }
  }

  /// Get the graphics object for drawing on this page.
  PdfGraphics get graphics => _graphics;

  /// Get the page width in points.
  double get width => settings.size.width;

  /// Get the page height in points.
  double get height => settings.size.height;
}

/// Page settings: size, orientation, margins.
class PdfPageSettings {
  PdfPageSize size;
  PdfPageOrientation orientation;
  PdfMargins margins;

  PdfPageSettings({
    PdfPageSize? size,
    this.orientation = PdfPageOrientation.portrait,
    PdfMargins? margins,
  })  : size = size ?? PdfPageSize.a4,
        margins = margins ?? PdfMargins.all(40) {
    // Apply orientation.
    if (orientation == PdfPageOrientation.landscape) {
      this.size = PdfPageSize(this.size.height, this.size.width);
    }
  }
}

/// Page orientation.
enum PdfPageOrientation {
  portrait,
  landscape,
}

/// Standard page sizes in points.
class PdfPageSize {
  final double width;
  final double height;

  const PdfPageSize(this.width, this.height);

  /// A4: 210mm × 297mm = 595.28 × 841.89 points.
  static const PdfPageSize a4 = PdfPageSize(595.28, 841.89);

  /// US Letter: 8.5" × 11" = 612 × 792 points.
  static const PdfPageSize letter = PdfPageSize(612, 792);

  /// US Legal: 8.5" × 14" = 612 × 1008 points.
  static const PdfPageSize legal = PdfPageSize(612, 1008);

  /// A3: 297mm × 420mm.
  static const PdfPageSize a3 = PdfPageSize(841.89, 1190.55);

  /// A5: 148mm × 210mm.
  static const PdfPageSize a5 = PdfPageSize(419.53, 595.28);

  /// B5: 176mm × 250mm.
  static const PdfPageSize b5 = PdfPageSize(498.90, 708.66);

  /// Executive: 7.25" × 10.5".
  static const PdfPageSize executive = PdfPageSize(522, 756);

  /// Tabloid: 11" × 17".
  static const PdfPageSize tabloid = PdfPageSize(792, 1224);
}

/// Page margins in points.
class PdfMargins {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const PdfMargins({
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
  });

  /// Create uniform margins.
  const PdfMargins.all(double value)
      : left = value,
        top = value,
        right = value,
        bottom = value;

  /// Create symmetric margins.
  const PdfMargins.symmetric({double horizontal = 0, double vertical = 0})
      : left = horizontal,
        right = horizontal,
        top = vertical,
        bottom = vertical;
}
