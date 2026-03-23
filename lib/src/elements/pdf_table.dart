import '../pdf_graphics.dart';
import '../fonts/pdf_font.dart';
import '../fonts/font_metrics.dart';
import '../graphics/pdf_brush.dart';
import '../graphics/pdf_color.dart';
import '../graphics/pdf_pen.dart';

/// A table (grid) element that can be drawn on a PDF page.
///
/// Example:
/// ```dart
/// final grid = PdfGrid();
/// grid.columns.add(count: 3);
/// final row = grid.rows.add();
/// row.cells[0].value = 'Name';
/// row.cells[1].value = 'Age';
/// row.cells[2].value = 'City';
/// grid.draw(page.graphics, bounds: Rect.fromLTWH(50, 100, 500, 0));
/// ```
class PdfGrid {
  final PdfGridColumnCollection columns = PdfGridColumnCollection();
  final PdfGridRowCollection rows = PdfGridRowCollection();
  PdfGridStyle style = PdfGridStyle();
  final PdfGridHeaderCollection headers = PdfGridHeaderCollection();

  /// Draw the grid on the given graphics at the specified bounds.
  /// Returns the total height used.
  double draw(PdfGraphics graphics, {required Rect bounds}) {
    if (columns.count == 0 || (rows.count == 0 && headers.count == 0)) {
      return 0;
    }

    final font = style.font;
    final cellPadding = style.cellPadding;
    final availableWidth = bounds.width;

    // Calculate column widths.
    final colWidths = _calculateColumnWidths(availableWidth, font);
    double currentY = bounds.top;

    // Draw header rows.
    for (int h = 0; h < headers.count; h++) {
      final row = headers[h];
      final rowHeight = _calculateRowHeight(row, colWidths, font, cellPadding);

      double currentX = bounds.left;
      for (int c = 0; c < columns.count && c < row.cells.length; c++) {
        final cell = row.cells[c];
        final cellW = colWidths[c];

        // Draw cell background.
        final bgBrush = cell.style?.backgroundBrush ??
            row.style?.backgroundBrush ??
            style.headerBackgroundBrush;
        if (bgBrush != null) {
          graphics.drawRectangle(
            Rect.fromLTWH(currentX, currentY, cellW, rowHeight),
            brush: bgBrush,
          );
        }

        // Draw cell border.
        final borderPen = cell.style?.borderPen ??
            row.style?.borderPen ??
            style.borderPen ??
            PdfPen(PdfColor.black, width: 0.5);
        graphics.drawRectangle(
          Rect.fromLTWH(currentX, currentY, cellW, rowHeight),
          pen: borderPen,
        );

        // Draw cell text.
        final cellFont = cell.style?.font ?? row.style?.font ?? style.headerFont ?? font;
        final cellBrush = cell.style?.textBrush ??
            row.style?.textBrush ??
            PdfSolidBrush(PdfColor.black);
        if (cell.value.isNotEmpty) {
          graphics.drawString(
            cell.value,
            cellFont,
            brush: cellBrush,
            bounds: Rect.fromLTWH(
              currentX + cellPadding,
              currentY + cellPadding,
              cellW - cellPadding * 2,
              rowHeight - cellPadding * 2,
            ),
            format: cell.style?.stringFormat,
          );
        }

        currentX += cellW;
      }
      currentY += rowHeight;
    }

    // Draw data rows.
    for (int r = 0; r < rows.count; r++) {
      final row = rows[r];
      final rowHeight = _calculateRowHeight(row, colWidths, font, cellPadding);

      double currentX = bounds.left;
      for (int c = 0; c < columns.count && c < row.cells.length; c++) {
        final cell = row.cells[c];
        final cellW = colWidths[c];

        // Draw cell background.
        final bgBrush = cell.style?.backgroundBrush ??
            row.style?.backgroundBrush ??
            (r % 2 == 1 ? style.alternateRowBrush : null);
        if (bgBrush != null) {
          graphics.drawRectangle(
            Rect.fromLTWH(currentX, currentY, cellW, rowHeight),
            brush: bgBrush,
          );
        }

        // Draw cell border.
        final borderPen = cell.style?.borderPen ??
            row.style?.borderPen ??
            style.borderPen ??
            PdfPen(PdfColor.black, width: 0.5);
        graphics.drawRectangle(
          Rect.fromLTWH(currentX, currentY, cellW, rowHeight),
          pen: borderPen,
        );

        // Draw cell text.
        final cellFont = cell.style?.font ?? row.style?.font ?? font;
        final cellBrush = cell.style?.textBrush ??
            row.style?.textBrush ??
            PdfSolidBrush(PdfColor.black);
        if (cell.value.isNotEmpty) {
          graphics.drawString(
            cell.value,
            cellFont,
            brush: cellBrush,
            bounds: Rect.fromLTWH(
              currentX + cellPadding,
              currentY + cellPadding,
              cellW - cellPadding * 2,
              rowHeight - cellPadding * 2,
            ),
            format: cell.style?.stringFormat,
          );
        }

        currentX += cellW;
      }
      currentY += rowHeight;
    }

    return currentY - bounds.top;
  }

  List<double> _calculateColumnWidths(double availableWidth, PdfFont font) {
    final count = columns.count;
    if (count == 0) return [];

    // Check for explicit widths.
    final widths = <double>[];
    double usedWidth = 0;
    int autoCount = 0;

    for (int i = 0; i < count; i++) {
      if (columns[i].width > 0) {
        widths.add(columns[i].width);
        usedWidth += columns[i].width;
      } else {
        widths.add(0);
        autoCount++;
      }
    }

    // Distribute remaining width to auto columns.
    if (autoCount > 0) {
      final autoWidth = (availableWidth - usedWidth) / autoCount;
      for (int i = 0; i < count; i++) {
        if (widths[i] == 0) {
          widths[i] = autoWidth;
        }
      }
    }

    return widths;
  }

  double _calculateRowHeight(
      PdfGridRow row, List<double> colWidths, PdfFont font, double padding) {
    double maxHeight = font.lineHeight + padding * 2;

    for (int c = 0; c < row.cells.length && c < colWidths.length; c++) {
      final cell = row.cells[c];
      final cellFont = cell.style?.font ?? font;
      if (cell.value.isNotEmpty) {
        // Estimate height based on text wrapping.
        final textWidth = cellFont.measureString(cell.value);
        final cellWidth = colWidths[c] - padding * 2;
        if (cellWidth > 0) {
          final lines = (textWidth / cellWidth).ceil();
          final h = lines * cellFont.lineHeight + padding * 2;
          if (h > maxHeight) maxHeight = h;
        }
      }
    }

    return maxHeight;
  }
}

/// Grid style configuration.
class PdfGridStyle {
  final PdfFont? _font;
  PdfFont? headerFont;
  PdfPen? borderPen;
  PdfBrush? headerBackgroundBrush;
  PdfBrush? alternateRowBrush;
  double cellPadding;

  PdfGridStyle({
    PdfFont? font,
    this.headerFont,
    this.borderPen,
    this.headerBackgroundBrush,
    this.alternateRowBrush,
    this.cellPadding = 5,
  }) : _font = font;

  PdfFont get font => _font ?? _defaultFont;

  static final PdfFont _defaultFont = _PlaceholderFont();
}

/// Placeholder font used when no font is specified.
class _PlaceholderFont extends PdfFont {
  @override
  double get size => 10;

  @override
  String get name => 'Helvetica';

  @override
  FontMetrics get metrics => FontMetrics(
    fontName: 'Helvetica',
    ascent: 718,
    descent: -207,
    avgWidth: 556,
    widths: const <int, double>{
      32: 278, 33: 278, 34: 355, 35: 556, 36: 556, 37: 889, 38: 667, 39: 191,
      40: 333, 41: 333, 42: 389, 43: 584, 44: 278, 45: 333, 46: 278, 47: 278,
      48: 556, 49: 556, 50: 556, 51: 556, 52: 556, 53: 556, 54: 556, 55: 556,
      56: 556, 57: 556, 58: 278, 59: 278, 60: 584, 61: 584, 62: 584, 63: 556,
      64: 1015, 65: 667, 66: 667, 67: 722, 68: 722, 69: 667, 70: 611, 71: 778,
      72: 722, 73: 278, 74: 500, 75: 667, 76: 556, 77: 833, 78: 722, 79: 778,
      80: 667, 81: 778, 82: 722, 83: 667, 84: 611, 85: 722, 86: 667, 87: 944,
      88: 667, 89: 667, 90: 611,
      97: 556, 98: 556, 99: 500, 100: 556, 101: 556, 102: 278, 103: 556,
      104: 556, 105: 222, 106: 222, 107: 500, 108: 222, 109: 833, 110: 556,
      111: 556, 112: 556, 113: 556, 114: 333, 115: 500, 116: 278, 117: 556,
      118: 500, 119: 722, 120: 500, 121: 500, 122: 500,
    },
  );
}

/// Column collection.
class PdfGridColumnCollection {
  final List<PdfGridColumn> _columns = [];

  /// Add columns.
  void add({int count = 1}) {
    for (int i = 0; i < count; i++) {
      _columns.add(PdfGridColumn());
    }
  }

  int get count => _columns.length;
  PdfGridColumn operator [](int index) => _columns[index];
}

/// A single column.
class PdfGridColumn {
  double width = 0; // 0 means auto.
}

/// Row collection.
class PdfGridRowCollection {
  final List<PdfGridRow> _rows = [];

  PdfGridRow add() {
    final row = PdfGridRow();
    _rows.add(row);
    return row;
  }

  int get count => _rows.length;
  PdfGridRow operator [](int index) => _rows[index];
}

/// Header row collection.
class PdfGridHeaderCollection {
  final List<PdfGridRow> _rows = [];

  PdfGridRow add() {
    final row = PdfGridRow();
    _rows.add(row);
    return row;
  }

  int get count => _rows.length;
  PdfGridRow operator [](int index) => _rows[index];
}

/// A single row in the grid.
class PdfGridRow {
  final List<PdfGridCell> cells = [];
  PdfGridRowStyle? style;

  PdfGridRow();

  /// Ensure the row has enough cells for the given column count.
  void ensureCells(int count) {
    while (cells.length < count) {
      cells.add(PdfGridCell());
    }
  }
}

/// A single cell.
class PdfGridCell {
  String value = '';
  PdfGridCellStyle? style;
}

/// Row style.
class PdfGridRowStyle {
  PdfFont? font;
  PdfBrush? textBrush;
  PdfBrush? backgroundBrush;
  PdfPen? borderPen;

  PdfGridRowStyle({
    this.font,
    this.textBrush,
    this.backgroundBrush,
    this.borderPen,
  });
}

/// Cell style.
class PdfGridCellStyle {
  PdfFont? font;
  PdfBrush? textBrush;
  PdfBrush? backgroundBrush;
  PdfPen? borderPen;
  PdfStringFormat? stringFormat;
}
