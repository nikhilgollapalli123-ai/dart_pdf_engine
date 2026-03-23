import '../pdf_graphics.dart';
import '../fonts/pdf_font.dart';
import '../fonts/pdf_standard_font.dart';
import '../graphics/pdf_brush.dart';
import '../graphics/pdf_color.dart';

/// An ordered (numbered) list element.
class PdfOrderedList {
  final List<String> items;
  final PdfFont? font;
  final PdfBrush? textBrush;
  final double indent;
  final double itemSpacing;

  PdfOrderedList({
    required this.items,
    this.font,
    this.textBrush,
    this.indent = 20,
    this.itemSpacing = 4,
  });

  /// Draw the list and return total height used.
  double draw(PdfGraphics graphics, {required Rect bounds}) {
    final usedFont = font ?? PdfStandardFont(PdfFontFamily.helvetica, 10);
    final brush = textBrush ?? PdfSolidBrush(PdfColor.black);
    double y = bounds.top;

    for (int i = 0; i < items.length; i++) {
      final marker = '${i + 1}. ';
      final text = '$marker${items[i]}';

      graphics.drawString(
        text,
        usedFont,
        brush: brush,
        bounds: Rect.fromLTWH(
          bounds.left + indent,
          y,
          bounds.width - indent,
          0,
        ),
      );

      y += usedFont.lineHeight + itemSpacing;
    }

    return y - bounds.top;
  }
}

/// An unordered (bulleted) list element.
class PdfUnorderedList {
  final List<String> items;
  final PdfFont? font;
  final PdfBrush? textBrush;
  final double indent;
  final double itemSpacing;
  final String bullet;

  PdfUnorderedList({
    required this.items,
    this.font,
    this.textBrush,
    this.indent = 20,
    this.itemSpacing = 4,
    this.bullet = '\u2022', // Bullet character •
  });

  /// Draw the list and return total height used.
  double draw(PdfGraphics graphics, {required Rect bounds}) {
    final usedFont = font ?? PdfStandardFont(PdfFontFamily.helvetica, 10);
    final brush = textBrush ?? PdfSolidBrush(PdfColor.black);
    double y = bounds.top;

    for (int i = 0; i < items.length; i++) {
      // Draw bullet.
      graphics.drawString(
        bullet,
        usedFont,
        brush: brush,
        bounds: Rect.fromLTWH(bounds.left, y, indent, 0),
      );

      // Draw item text.
      graphics.drawString(
        items[i],
        usedFont,
        brush: brush,
        bounds: Rect.fromLTWH(
          bounds.left + indent,
          y,
          bounds.width - indent,
          0,
        ),
      );

      y += usedFont.lineHeight + itemSpacing;
    }

    return y - bounds.top;
  }
}
