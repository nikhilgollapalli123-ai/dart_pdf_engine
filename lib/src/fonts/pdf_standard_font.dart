import 'pdf_font.dart';
import 'font_metrics.dart';

/// The 14 standard PDF font families.
enum PdfFontFamily {
  helvetica,
  helveticaBold,
  helveticaOblique,
  helveticaBoldOblique,
  timesRoman,
  timesBold,
  timesItalic,
  timesBoldItalic,
  courier,
  courierBold,
  courierOblique,
  courierBoldOblique,
  symbol,
  zapfDingbats,
}

/// A standard PDF font (one of the 14 built-in fonts).
/// These fonts do not need to be embedded in the PDF.
class PdfStandardFont extends PdfFont {
  final PdfFontFamily family;
  @override
  final double size;

  PdfStandardFont(this.family, this.size);

  @override
  String get name => _fontNames[family]!;

  @override
  FontMetrics get metrics => StandardFontMetrics.getMetrics(name);

  /// Mapping from enum to PDF font name.
  static const Map<PdfFontFamily, String> _fontNames = {
    PdfFontFamily.helvetica: 'Helvetica',
    PdfFontFamily.helveticaBold: 'Helvetica-Bold',
    PdfFontFamily.helveticaOblique: 'Helvetica-Oblique',
    PdfFontFamily.helveticaBoldOblique: 'Helvetica-BoldOblique',
    PdfFontFamily.timesRoman: 'Times-Roman',
    PdfFontFamily.timesBold: 'Times-Bold',
    PdfFontFamily.timesItalic: 'Times-Italic',
    PdfFontFamily.timesBoldItalic: 'Times-BoldItalic',
    PdfFontFamily.courier: 'Courier',
    PdfFontFamily.courierBold: 'Courier-Bold',
    PdfFontFamily.courierOblique: 'Courier-Oblique',
    PdfFontFamily.courierBoldOblique: 'Courier-BoldOblique',
    PdfFontFamily.symbol: 'Symbol',
    PdfFontFamily.zapfDingbats: 'ZapfDingbats',
  };
}
