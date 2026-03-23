import 'fonts/pdf_font.dart';
import 'graphics/pdf_brush.dart';
import 'graphics/pdf_color.dart';
import 'graphics/pdf_pen.dart';
import 'graphics/pdf_image.dart';
import 'graphics/pdf_path.dart';

/// Canvas-like graphics API for drawing on a PDF page.
///
/// Text drawn with this API uses proper PDF text operators (BT/ET/Tf/Tj)
/// so all text is natively selectable and searchable in PDF viewers.
class PdfGraphics {
  final double _pageWidth;
  final double _pageHeight;
  final StringBuffer _contentStream = StringBuffer();

  // Track resources used on this page.
  final Map<String, PdfFont> _fonts = {};
  final Map<String, PdfBitmap> _images = {};
  int _fontCounter = 0;
  int _imageCounter = 0;

  PdfGraphics(this._pageWidth, this._pageHeight);

  /// Create graphics with an existing content stream (from parsed PDF).
  PdfGraphics.fromParsed(
    this._pageWidth,
    this._pageHeight,
    String existingContentStream,
  ) {
    _contentStream.write(existingContentStream);
  }

  /// Set the content stream directly (used by the parser).
  void setContentStream(String content) {
    _contentStream.clear();
    _contentStream.write(content);
  }

  /// Get the content stream as a string.
  String get contentStream => _contentStream.toString();

  /// Get the fonts used on this page.
  Map<String, PdfFont> get fonts => _fonts;

  /// Get the images used on this page.
  Map<String, PdfBitmap> get images => _images;

  /// Get the page width.
  double get pageWidth => _pageWidth;

  /// Get the page height.
  double get pageHeight => _pageHeight;

  // ─── Font Resource Management ───

  String _registerFont(PdfFont font) {
    // Check if already registered.
    for (final entry in _fonts.entries) {
      if (entry.value == font) return entry.key;
    }
    _fontCounter++;
    final name = 'F$_fontCounter';
    _fonts[name] = font;
    return name;
  }

  String _registerImage(PdfBitmap image) {
    for (final entry in _images.entries) {
      if (entry.value == image) return entry.key;
    }
    _imageCounter++;
    final name = 'Im$_imageCounter';
    _images[name] = image;
    return name;
  }

  // ─── Text Drawing ───

  /// Draw a string at the specified position.
  ///
  /// Uses proper PDF text operators (BT/ET) so text is selectable.
  /// [text] The text to draw.
  /// [font] The font to use.
  /// [brush] Optional fill brush (defaults to black).
  /// [pen] Optional stroke pen for outlined text.
  /// [bounds] Rectangle defining position and optional wrapping area.
  /// [format] Optional string format for alignment.
  void drawString(
    String text,
    PdfFont font, {
    PdfBrush? brush,
    PdfPen? pen,
    required Rect bounds,
    PdfStringFormat? format,
  }) {
    final fontName = _registerFont(font);
    final color = brush?.color ?? PdfColor.black;

    // PDF coordinate system: origin at bottom-left, Y increases upward.
    // Flutter-style bounds: origin at top-left, Y increases downward.
    // We need to transform.

    if (bounds.width > 0 && text.isNotEmpty) {
      // Word-wrap text within bounds.
      final lines = _wrapText(text, font, bounds.width);
      double yOffset = 0;

      for (final line in lines) {
        if (bounds.height > 0 && yOffset + font.lineHeight > bounds.height) {
          break; // Don't overflow bounds.
        }

        final pdfY = _pageHeight - bounds.top - yOffset - font.ascent;
        double pdfX = bounds.left;

        // Handle alignment.
        if (format != null) {
          final lineWidth = font.measureString(line);
          switch (format.alignment) {
            case PdfTextAlignment.center:
              pdfX = bounds.left + (bounds.width - lineWidth) / 2;
              break;
            case PdfTextAlignment.right:
              pdfX = bounds.left + bounds.width - lineWidth;
              break;
            case PdfTextAlignment.left:
            case PdfTextAlignment.justify:
              break;
          }
        }

        _contentStream.writeln('BT');
        _contentStream.writeln(color.toFillOperator());
        _contentStream.writeln('/$fontName ${_fmt(font.size)} Tf');
        _contentStream.writeln('${_fmt(pdfX)} ${_fmt(pdfY)} Td');
        _contentStream.writeln('(${_escapePdfString(line)}) Tj');
        _contentStream.writeln('ET');

        yOffset += font.lineHeight * (format?.lineSpacing ?? 1.2);
      }
    } else {
      // Simple single-line draw.
      final pdfY = _pageHeight - bounds.top - font.ascent;

      _contentStream.writeln('BT');
      _contentStream.writeln(color.toFillOperator());
      _contentStream.writeln('/$fontName ${_fmt(font.size)} Tf');
      _contentStream.writeln('${_fmt(bounds.left)} ${_fmt(pdfY)} Td');
      _contentStream.writeln('(${_escapePdfString(text)}) Tj');
      _contentStream.writeln('ET');
    }
  }

  /// Word-wrap text to fit within the given width.
  List<String> _wrapText(String text, PdfFont font, double maxWidth) {
    if (maxWidth <= 0) return [text];

    final lines = <String>[];
    final paragraphs = text.split('\n');

    for (final paragraph in paragraphs) {
      if (paragraph.isEmpty) {
        lines.add('');
        continue;
      }

      final words = paragraph.split(' ');
      var currentLine = StringBuffer();

      for (final word in words) {
        final testLine = currentLine.isEmpty
            ? word
            : '$currentLine $word';
        final testWidth = font.measureString(testLine);

        if (testWidth > maxWidth && currentLine.isNotEmpty) {
          lines.add(currentLine.toString());
          currentLine = StringBuffer(word);
        } else {
          currentLine = StringBuffer(testLine);
        }
      }

      if (currentLine.isNotEmpty) {
        lines.add(currentLine.toString());
      }
    }

    return lines;
  }

  // ─── Shape Drawing ───

  /// Draw a line between two points.
  void drawLine(
    double x1, double y1, double x2, double y2,
    PdfPen pen,
  ) {
    final py1 = _pageHeight - y1;
    final py2 = _pageHeight - y2;

    _contentStream.writeln('q');
    _contentStream.writeln(pen.color.toStrokeOperator());
    _contentStream.writeln('${_fmt(pen.width)} w');
    _contentStream.writeln(pen.toDashOperator());
    _contentStream.writeln('${_fmt(x1)} ${_fmt(py1)} m');
    _contentStream.writeln('${_fmt(x2)} ${_fmt(py2)} l');
    _contentStream.writeln('S');
    _contentStream.writeln('Q');
  }

  /// Draw a rectangle.
  void drawRectangle(
    Rect bounds, {
    PdfBrush? brush,
    PdfPen? pen,
  }) {
    final pdfY = _pageHeight - bounds.top - bounds.height;

    _contentStream.writeln('q');

    if (brush != null) {
      _contentStream.writeln(brush.color.toFillOperator());
    }
    if (pen != null) {
      _contentStream.writeln(pen.color.toStrokeOperator());
      _contentStream.writeln('${_fmt(pen.width)} w');
      _contentStream.writeln(pen.toDashOperator());
    }

    _contentStream.writeln(
        '${_fmt(bounds.left)} ${_fmt(pdfY)} ${_fmt(bounds.width)} ${_fmt(bounds.height)} re');

    if (brush != null && pen != null) {
      _contentStream.writeln('B'); // Fill and stroke.
    } else if (brush != null) {
      _contentStream.writeln('f'); // Fill only.
    } else {
      _contentStream.writeln('S'); // Stroke only.
    }

    _contentStream.writeln('Q');
  }

  /// Draw an ellipse.
  void drawEllipse(
    Rect bounds, {
    PdfBrush? brush,
    PdfPen? pen,
  }) {
    final path = PdfPath();
    path.addEllipse(
        bounds.left, _pageHeight - bounds.top - bounds.height,
        bounds.width, bounds.height);

    _contentStream.writeln('q');

    if (brush != null) {
      _contentStream.writeln(brush.color.toFillOperator());
    }
    if (pen != null) {
      _contentStream.writeln(pen.color.toStrokeOperator());
      _contentStream.writeln('${_fmt(pen.width)} w');
    }

    _contentStream.write(path.toOperators());

    if (brush != null && pen != null) {
      _contentStream.writeln('B');
    } else if (brush != null) {
      _contentStream.writeln('f');
    } else {
      _contentStream.writeln('S');
    }

    _contentStream.writeln('Q');
  }

  /// Draw a path.
  void drawPath(
    PdfPath path, {
    PdfBrush? brush,
    PdfPen? pen,
  }) {
    _contentStream.writeln('q');

    if (brush != null) {
      _contentStream.writeln(brush.color.toFillOperator());
    }
    if (pen != null) {
      _contentStream.writeln(pen.color.toStrokeOperator());
      _contentStream.writeln('${_fmt(pen.width)} w');
    }

    _contentStream.write(path.toOperators());

    if (brush != null && pen != null) {
      _contentStream.writeln('B');
    } else if (brush != null) {
      _contentStream.writeln('f');
    } else {
      _contentStream.writeln('S');
    }

    _contentStream.writeln('Q');
  }

  // ─── Image Drawing ───

  /// Draw an image at the specified bounds.
  void drawImage(PdfBitmap image, Rect bounds) {
    final imageName = _registerImage(image);
    final pdfY = _pageHeight - bounds.top - bounds.height;

    _contentStream.writeln('q');
    // Image transformation matrix: scale and position.
    _contentStream.writeln(
        '${_fmt(bounds.width)} 0 0 ${_fmt(bounds.height)} ${_fmt(bounds.left)} ${_fmt(pdfY)} cm');
    _contentStream.writeln('/$imageName Do');
    _contentStream.writeln('Q');
  }

  // ─── State Management ───

  /// Save the current graphics state.
  void save() {
    _contentStream.writeln('q');
  }

  /// Restore the previously saved graphics state.
  void restore() {
    _contentStream.writeln('Q');
  }

  /// Set a clipping rectangle.
  void setClip(Rect bounds) {
    final pdfY = _pageHeight - bounds.top - bounds.height;
    _contentStream.writeln(
        '${_fmt(bounds.left)} ${_fmt(pdfY)} ${_fmt(bounds.width)} ${_fmt(bounds.height)} re');
    _contentStream.writeln('W n');
  }

  /// Translate the coordinate system.
  void translateTransform(double dx, double dy) {
    _contentStream.writeln('1 0 0 1 ${_fmt(dx)} ${_fmt(-dy)} cm');
  }

  // ─── Helpers ───

  String _escapePdfString(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)');
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    String s = v.toStringAsFixed(4);
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
    return s;
  }
}

/// Simple rectangle class (to avoid Flutter dependency).
class Rect {
  final double left;
  final double top;
  final double width;
  final double height;

  const Rect.fromLTWH(this.left, this.top, this.width, this.height);

  double get right => left + width;
  double get bottom => top + height;

  static const Rect zero = Rect.fromLTWH(0, 0, 0, 0);
}

/// Text alignment options.
enum PdfTextAlignment {
  left,
  center,
  right,
  justify,
}

/// String format options for text drawing.
class PdfStringFormat {
  final PdfTextAlignment alignment;
  final double lineSpacing;

  const PdfStringFormat({
    this.alignment = PdfTextAlignment.left,
    this.lineSpacing = 1.2,
  });
}
