import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../pdf_page.dart';

/// Renders a single PDF page's content stream to a Flutter [Canvas].
///
/// Interprets PDF operators (text, shapes, images) and draws them
/// using Flutter's rendering primitives. Works best with PDFs
/// created by `dart_pdf_engine` itself.
class PdfPageRenderer extends CustomPainter {
  /// The page to render.
  final PdfPage page;

  /// Scale factor for rendering.
  final double scale;

  PdfPageRenderer({
    required this.page,
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Scale to fit the size.
    final scaleX = size.width / page.width;
    final scaleY = size.height / page.height;
    final fitScale = math.min(scaleX, scaleY) * scale;

    canvas.save();
    canvas.scale(fitScale, fitScale);

    // Draw white background.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, page.width, page.height),
      Paint()..color = Colors.white,
    );

    // Parse and render content stream.
    final content = page.graphics.contentStream;
    if (content.isNotEmpty) {
      _renderContentStream(canvas, content, page.width, page.height);
    }

    canvas.restore();
  }

  /// Parse and render PDF content stream operators.
  void _renderContentStream(
    Canvas canvas,
    String content,
    double pageWidth,
    double pageHeight,
  ) {
    final tokens = _tokenize(content);
    final stateStack = <_GraphicsState>[];
    var state = _GraphicsState();

    int i = 0;
    while (i < tokens.length) {
      final token = tokens[i];

      switch (token) {
        // ── Graphics state ──
        case 'q':
          stateStack.add(state.copy());
          canvas.save();
          break;

        case 'Q':
          if (stateStack.isNotEmpty) {
            state = stateStack.removeLast();
            canvas.restore();
          }
          break;

        // ── Color operators ──
        case 'rg': // RGB fill color
          if (i >= 3) {
            final b = _parseDouble(tokens[i - 1]);
            final g = _parseDouble(tokens[i - 2]);
            final r = _parseDouble(tokens[i - 3]);
            state.fillColor = Color.fromARGB(
              255,
              (r * 255).round().clamp(0, 255),
              (g * 255).round().clamp(0, 255),
              (b * 255).round().clamp(0, 255),
            );
          }
          break;

        case 'RG': // RGB stroke color
          if (i >= 3) {
            final b = _parseDouble(tokens[i - 1]);
            final g = _parseDouble(tokens[i - 2]);
            final r = _parseDouble(tokens[i - 3]);
            state.strokeColor = Color.fromARGB(
              255,
              (r * 255).round().clamp(0, 255),
              (g * 255).round().clamp(0, 255),
              (b * 255).round().clamp(0, 255),
            );
          }
          break;

        case 'g': // Gray fill
          if (i >= 1) {
            final gray = (_parseDouble(tokens[i - 1]) * 255).round().clamp(0, 255);
            state.fillColor = Color.fromARGB(255, gray, gray, gray);
          }
          break;

        case 'G': // Gray stroke
          if (i >= 1) {
            final gray = (_parseDouble(tokens[i - 1]) * 255).round().clamp(0, 255);
            state.strokeColor = Color.fromARGB(255, gray, gray, gray);
          }
          break;

        // ── Line width ──
        case 'w':
          if (i >= 1) {
            state.lineWidth = _parseDouble(tokens[i - 1]);
          }
          break;

        // ── Dash pattern ──
        case 'd':
          // Skip dash pattern for now (visual only).
          break;

        // ── Path construction ──
        case 'm': // moveTo
          if (i >= 2) {
            final x = _parseDouble(tokens[i - 2]);
            final y = _parseDouble(tokens[i - 1]);
            state.path = ui.Path();
            state.pathStartX = x;
            state.pathStartY = y;
            state.currentX = x;
            state.currentY = y;
            state.path!.moveTo(x, pageHeight - y);
          }
          break;

        case 'l': // lineTo
          if (i >= 2) {
            final x = _parseDouble(tokens[i - 2]);
            final y = _parseDouble(tokens[i - 1]);
            state.currentX = x;
            state.currentY = y;
            state.path?.lineTo(x, pageHeight - y);
          }
          break;

        case 'c': // curveTo (cubic Bezier)
          if (i >= 6) {
            final x1 = _parseDouble(tokens[i - 6]);
            final y1 = _parseDouble(tokens[i - 5]);
            final x2 = _parseDouble(tokens[i - 4]);
            final y2 = _parseDouble(tokens[i - 3]);
            final x3 = _parseDouble(tokens[i - 2]);
            final y3 = _parseDouble(tokens[i - 1]);
            state.currentX = x3;
            state.currentY = y3;
            state.path?.cubicTo(
              x1, pageHeight - y1,
              x2, pageHeight - y2,
              x3, pageHeight - y3,
            );
          }
          break;

        case 'h': // closePath
          state.path?.close();
          break;

        case 're': // rectangle
          if (i >= 4) {
            final x = _parseDouble(tokens[i - 4]);
            final y = _parseDouble(tokens[i - 3]);
            final w = _parseDouble(tokens[i - 2]);
            final h = _parseDouble(tokens[i - 1]);
            state.path ??= ui.Path();
            state.path!.addRect(
              Rect.fromLTWH(x, pageHeight - y - h, w, h),
            );
          }
          break;

        // ── Path painting ──
        case 'S': // Stroke
          if (state.path != null) {
            canvas.drawPath(
              state.path!,
              Paint()
                ..color = state.strokeColor
                ..style = PaintingStyle.stroke
                ..strokeWidth = state.lineWidth,
            );
            state.path = null;
          }
          break;

        case 'f': // Fill (non-zero winding)
        case 'F':
          if (state.path != null) {
            canvas.drawPath(
              state.path!,
              Paint()
                ..color = state.fillColor
                ..style = PaintingStyle.fill,
            );
            state.path = null;
          }
          break;

        case 'B': // Fill and stroke
          if (state.path != null) {
            canvas.drawPath(
              state.path!,
              Paint()
                ..color = state.fillColor
                ..style = PaintingStyle.fill,
            );
            canvas.drawPath(
              state.path!,
              Paint()
                ..color = state.strokeColor
                ..style = PaintingStyle.stroke
                ..strokeWidth = state.lineWidth,
            );
            state.path = null;
          }
          break;

        case 'n': // End path (no-op painting)
          state.path = null;
          break;

        // ── Text operators ──
        case 'BT': // Begin text
          state.textX = 0;
          state.textY = 0;
          state.inText = true;
          break;

        case 'ET': // End text
          state.inText = false;
          break;

        case 'Tf': // Set font
          if (i >= 2) {
            state.fontSize = _parseDouble(tokens[i - 1]);
            state.fontName = tokens[i - 2];
          }
          break;

        case 'Td': // Move text position
          if (i >= 2) {
            state.textX = _parseDouble(tokens[i - 2]);
            state.textY = _parseDouble(tokens[i - 1]);
          }
          break;

        case 'Tj': // Show text
          if (i >= 1) {
            final text = _extractPdfString(tokens[i - 1]);
            _drawText(
              canvas,
              text,
              state.textX,
              pageHeight - state.textY,
              state.fontSize,
              state.fillColor,
              state.fontName,
            );
          }
          break;

        // ── Transformation matrix ──
        case 'cm':
          if (i >= 6) {
            final a = _parseDouble(tokens[i - 6]);
            final b = _parseDouble(tokens[i - 5]);
            final c = _parseDouble(tokens[i - 4]);
            final d = _parseDouble(tokens[i - 3]);
            final e = _parseDouble(tokens[i - 2]);
            final f = _parseDouble(tokens[i - 1]);
            // PDF cm operator: [a b c d e f]
            // Maps to Flutter transform with Y-flip.
            final matrix = Float64List(16);
            matrix[0] = a;
            matrix[1] = -b;
            matrix[4] = -c;
            matrix[5] = d;
            matrix[12] = e;
            matrix[13] = pageHeight - f;
            matrix[15] = 1;
            // Only apply simple translations for now.
            if (a == 1 && b == 0 && c == 0 && d == 1) {
              canvas.translate(e, pageHeight - f - pageHeight);
            }
          }
          break;

        // ── Image XObject ──
        case 'Do':
          // Image rendering is complex and requires decoding the
          // XObject stream. For basic preview, we show a placeholder.
          if (i >= 1) {
            // Image rendering requires decoding XObject stream.
            // For basic preview, we skip (images show as blank).
            if (state.path == null) {
              // Best effort — draw a gray box where an image would be.
            }
          }
          break;

        // ── Clipping ──
        case 'W': // Set clipping path
          // Combined with 'n' to set the clip.
          if (state.path != null) {
            canvas.clipPath(state.path!);
          }
          break;
      }

      i++;
    }
  }

  /// Draw text on the canvas using Flutter's text rendering.
  void _drawText(
    Canvas canvas,
    String text,
    double x,
    double y,
    double fontSize,
    Color color,
    String fontName,
  ) {
    if (text.isEmpty) return;

    // Map PDF font names to Flutter font families.
    String fontFamily = 'Roboto';
    FontWeight fontWeight = FontWeight.normal;
    FontStyle fontStyle = FontStyle.normal;

    final lowerName = fontName.toLowerCase();
    if (lowerName.contains('courier')) {
      fontFamily = 'Courier';
    } else if (lowerName.contains('times')) {
      fontFamily = 'Times New Roman';
    } else if (lowerName.contains('helvetica')) {
      fontFamily = 'Helvetica';
    }

    if (lowerName.contains('bold')) {
      fontWeight = FontWeight.bold;
    }
    if (lowerName.contains('italic') || lowerName.contains('oblique')) {
      fontStyle = FontStyle.italic;
    }

    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        height: 1.0,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset(x, y - fontSize));
  }

  /// Tokenize a PDF content stream into individual tokens.
  List<String> _tokenize(String content) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    bool inString = false;
    int parenDepth = 0;

    for (int i = 0; i < content.length; i++) {
      final char = content[i];

      if (inString) {
        buffer.write(char);
        if (char == '(' && (i == 0 || content[i - 1] != '\\')) {
          parenDepth++;
        } else if (char == ')' && (i == 0 || content[i - 1] != '\\')) {
          parenDepth--;
          if (parenDepth == 0) {
            tokens.add(buffer.toString());
            buffer.clear();
            inString = false;
          }
        }
        continue;
      }

      if (char == '(') {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        buffer.write(char);
        inString = true;
        parenDepth = 1;
        continue;
      }

      if (char == '/' && buffer.isEmpty) {
        // PDF name — read until whitespace.
        buffer.write(char);
        continue;
      }

      if (char == ' ' || char == '\n' || char == '\r' || char == '\t') {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        continue;
      }

      if (char == '[' || char == ']') {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        tokens.add(char);
        continue;
      }

      buffer.write(char);
    }

    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }

    return tokens;
  }

  /// Extract text from a PDF string literal like "(Hello World)".
  String _extractPdfString(String token) {
    if (token.startsWith('(') && token.endsWith(')')) {
      var text = token.substring(1, token.length - 1);
      // Unescape PDF string escapes.
      text = text
          .replaceAll('\\(', '(')
          .replaceAll('\\)', ')')
          .replaceAll('\\\\', '\\');
      return text;
    }
    return token;
  }

  /// Parse a token as a double.
  double _parseDouble(String token) {
    return double.tryParse(token) ?? 0.0;
  }

  @override
  bool shouldRepaint(PdfPageRenderer oldDelegate) {
    return oldDelegate.page != page || oldDelegate.scale != scale;
  }
}

/// Internal graphics state for rendering.
class _GraphicsState {
  Color fillColor;
  Color strokeColor;
  double lineWidth;
  ui.Path? path;
  double pathStartX;
  double pathStartY;
  double currentX;
  double currentY;

  // Text state.
  bool inText;
  double textX;
  double textY;
  double fontSize;
  String fontName;

  _GraphicsState({
    this.fillColor = const Color(0xFF000000),
    this.strokeColor = const Color(0xFF000000),
    this.lineWidth = 1.0,
    this.pathStartX = 0,
    this.pathStartY = 0,
    this.currentX = 0,
    this.currentY = 0,
    this.inText = false,
    this.textX = 0,
    this.textY = 0,
    this.fontSize = 12,
    this.fontName = '',
  });

  _GraphicsState copy() {
    return _GraphicsState(
      fillColor: fillColor,
      strokeColor: strokeColor,
      lineWidth: lineWidth,
      pathStartX: pathStartX,
      pathStartY: pathStartY,
      currentX: currentX,
      currentY: currentY,
      inText: inText,
      textX: textX,
      textY: textY,
      fontSize: fontSize,
      fontName: fontName,
    );
  }
}
