import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../pdf_page.dart';

/// Renders a single PDF page's content stream to a Flutter [Canvas].
///
/// Interprets PDF operators (text, shapes, image placeholders) and draws them
/// using Flutter's rendering primitives.
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
        // ── Graphics state save/restore ──
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

        // ── Color operators (Device colors) ──
        case 'rg': // RGB fill color
          if (i >= 3) {
            final b = _parseDouble(tokens[i - 1]);
            final g = _parseDouble(tokens[i - 2]);
            final r = _parseDouble(tokens[i - 3]);
            state.fillColor = _colorFromRGB(r, g, b);
          }
          break;

        case 'RG': // RGB stroke color
          if (i >= 3) {
            final b = _parseDouble(tokens[i - 1]);
            final g = _parseDouble(tokens[i - 2]);
            final r = _parseDouble(tokens[i - 3]);
            state.strokeColor = _colorFromRGB(r, g, b);
          }
          break;

        case 'g': // Gray fill
          if (i >= 1) {
            final gray =
                (_parseDouble(tokens[i - 1]) * 255).round().clamp(0, 255);
            state.fillColor = Color.fromARGB(255, gray, gray, gray);
          }
          break;

        case 'G': // Gray stroke
          if (i >= 1) {
            final gray =
                (_parseDouble(tokens[i - 1]) * 255).round().clamp(0, 255);
            state.strokeColor = Color.fromARGB(255, gray, gray, gray);
          }
          break;

        case 'k': // CMYK fill color
          if (i >= 4) {
            final kk = _parseDouble(tokens[i - 1]);
            final y = _parseDouble(tokens[i - 2]);
            final m = _parseDouble(tokens[i - 3]);
            final c = _parseDouble(tokens[i - 4]);
            state.fillColor = _colorFromCMYK(c, m, y, kk);
          }
          break;

        case 'K': // CMYK stroke color
          if (i >= 4) {
            final kk = _parseDouble(tokens[i - 1]);
            final y = _parseDouble(tokens[i - 2]);
            final m = _parseDouble(tokens[i - 3]);
            final c = _parseDouble(tokens[i - 4]);
            state.strokeColor = _colorFromCMYK(c, m, y, kk);
          }
          break;

        // ── Color space operators ──
        case 'cs': // Set fill color space
          if (i >= 1) {
            state.fillColorSpace = tokens[i - 1].replaceAll('/', '');
          }
          break;

        case 'CS': // Set stroke color space
          if (i >= 1) {
            state.strokeColorSpace = tokens[i - 1].replaceAll('/', '');
          }
          break;

        case 'sc': // Set fill color in current color space
        case 'scn':
          _setColorFromSpace(tokens, i, state, isFill: true);
          break;

        case 'SC': // Set stroke color in current color space
        case 'SCN':
          _setColorFromSpace(tokens, i, state, isFill: false);
          break;

        // ── Line style ──
        case 'w': // Line width
          if (i >= 1) {
            state.lineWidth = _parseDouble(tokens[i - 1]);
          }
          break;

        case 'J': // Line cap
          if (i >= 1) {
            state.lineCap = _parseInt(tokens[i - 1]);
          }
          break;

        case 'j': // Line join
          if (i >= 1) {
            state.lineJoin = _parseInt(tokens[i - 1]);
          }
          break;

        case 'M': // Miter limit
          if (i >= 1) {
            state.miterLimit = _parseDouble(tokens[i - 1]);
          }
          break;

        case 'd': // Dash pattern
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

        case 'c': // curveTo (cubic Bezier — 3 control points)
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
              x1,
              pageHeight - y1,
              x2,
              pageHeight - y2,
              x3,
              pageHeight - y3,
            );
          }
          break;

        case 'v': // curveTo (initial point replicated)
          if (i >= 4) {
            final x2 = _parseDouble(tokens[i - 4]);
            final y2 = _parseDouble(tokens[i - 3]);
            final x3 = _parseDouble(tokens[i - 2]);
            final y3 = _parseDouble(tokens[i - 1]);
            state.path?.cubicTo(
              state.currentX,
              pageHeight - state.currentY,
              x2,
              pageHeight - y2,
              x3,
              pageHeight - y3,
            );
            state.currentX = x3;
            state.currentY = y3;
          }
          break;

        case 'y': // curveTo (final point replicated)
          if (i >= 4) {
            final x1 = _parseDouble(tokens[i - 4]);
            final y1 = _parseDouble(tokens[i - 3]);
            final x3 = _parseDouble(tokens[i - 2]);
            final y3 = _parseDouble(tokens[i - 1]);
            state.path?.cubicTo(
              x1,
              pageHeight - y1,
              x3,
              pageHeight - y3,
              x3,
              pageHeight - y3,
            );
            state.currentX = x3;
            state.currentY = y3;
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
            canvas.drawPath(state.path!, _strokePaint(state));
            state.path = null;
          }
          break;

        case 's': // Close and stroke
          if (state.path != null) {
            state.path!.close();
            canvas.drawPath(state.path!, _strokePaint(state));
            state.path = null;
          }
          break;

        case 'f': // Fill (non-zero winding)
        case 'F':
          if (state.path != null) {
            canvas.drawPath(state.path!, _fillPaint(state));
            state.path = null;
          }
          break;

        case 'f*': // Fill (even-odd)
          if (state.path != null) {
            state.path!.fillType = ui.PathFillType.evenOdd;
            canvas.drawPath(state.path!, _fillPaint(state));
            state.path = null;
          }
          break;

        case 'B': // Fill and stroke (non-zero winding)
          if (state.path != null) {
            canvas.drawPath(state.path!, _fillPaint(state));
            canvas.drawPath(state.path!, _strokePaint(state));
            state.path = null;
          }
          break;

        case 'B*': // Fill and stroke (even-odd)
          if (state.path != null) {
            state.path!.fillType = ui.PathFillType.evenOdd;
            canvas.drawPath(state.path!, _fillPaint(state));
            canvas.drawPath(state.path!, _strokePaint(state));
            state.path = null;
          }
          break;

        case 'b': // Close, fill, and stroke (non-zero winding)
          if (state.path != null) {
            state.path!.close();
            canvas.drawPath(state.path!, _fillPaint(state));
            canvas.drawPath(state.path!, _strokePaint(state));
            state.path = null;
          }
          break;

        case 'b*': // Close, fill, and stroke (even-odd)
          if (state.path != null) {
            state.path!.close();
            state.path!.fillType = ui.PathFillType.evenOdd;
            canvas.drawPath(state.path!, _fillPaint(state));
            canvas.drawPath(state.path!, _strokePaint(state));
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
          state.textMatrixX = 0;
          state.textMatrixY = 0;
          state.lineMatrixX = 0;
          state.lineMatrixY = 0;
          state.inText = true;
          break;

        case 'ET': // End text
          state.inText = false;
          break;

        case 'Tf': // Set font and size
          if (i >= 2) {
            state.fontSize = _parseDouble(tokens[i - 1]);
            state.fontName = tokens[i - 2];
          }
          break;

        case 'TL': // Set text leading
          if (i >= 1) {
            state.textLeading = _parseDouble(tokens[i - 1]);
          }
          break;

        case 'Tc': // Set character spacing
          if (i >= 1) {
            state.charSpacing = _parseDouble(tokens[i - 1]);
          }
          break;

        case 'Tw': // Set word spacing
          if (i >= 1) {
            state.wordSpacing = _parseDouble(tokens[i - 1]);
          }
          break;

        case 'Tr': // Set text rendering mode
          // 0=fill, 1=stroke, 2=fill+stroke — we only handle fill currently.
          break;

        case 'Ts': // Set text rise
          break;

        case 'Td': // Move text position
          if (i >= 2) {
            final tx = _parseDouble(tokens[i - 2]);
            final ty = _parseDouble(tokens[i - 1]);
            state.textMatrixX = state.lineMatrixX + tx;
            state.textMatrixY = state.lineMatrixY + ty;
            state.lineMatrixX = state.textMatrixX;
            state.lineMatrixY = state.textMatrixY;
            state.textX = state.textMatrixX;
            state.textY = state.textMatrixY;
          }
          break;

        case 'TD': // Move text position and set leading
          if (i >= 2) {
            final tx = _parseDouble(tokens[i - 2]);
            final ty = _parseDouble(tokens[i - 1]);
            state.textLeading = -ty;
            state.textMatrixX = state.lineMatrixX + tx;
            state.textMatrixY = state.lineMatrixY + ty;
            state.lineMatrixX = state.textMatrixX;
            state.lineMatrixY = state.textMatrixY;
            state.textX = state.textMatrixX;
            state.textY = state.textMatrixY;
          }
          break;

        case 'Tm': // Set text matrix (absolute positioning)
          if (i >= 6) {
            final a = _parseDouble(tokens[i - 6]);
            // final b = _parseDouble(tokens[i - 5]);
            // final c = _parseDouble(tokens[i - 4]);
            final d = _parseDouble(tokens[i - 3]);
            final e = _parseDouble(tokens[i - 2]);
            final f = _parseDouble(tokens[i - 1]);
            state.textMatrixX = e;
            state.textMatrixY = f;
            state.lineMatrixX = e;
            state.lineMatrixY = f;
            state.textX = e;
            state.textY = f;
            // Use the scale from the matrix for font size adjustment.
            if (a != 0 && d != 0) {
              state.textScaleX = a.abs();
              state.textScaleY = d.abs();
            }
          }
          break;

        case 'T*': // Move to start of next line
          state.textMatrixX = state.lineMatrixX;
          state.textMatrixY = state.lineMatrixY - state.textLeading;
          state.lineMatrixX = state.textMatrixX;
          state.lineMatrixY = state.textMatrixY;
          state.textX = state.textMatrixX;
          state.textY = state.textMatrixY;
          break;

        case 'Tj': // Show text
          if (i >= 1) {
            final text = _extractPdfString(tokens[i - 1]);
            _drawText(
              canvas,
              text,
              state.textX,
              pageHeight - state.textY,
              state.fontSize * state.textScaleY,
              state.fillColor,
              state.fontName,
            );
            // Advance text position by text width (approximation).
            state.textX +=
                text.length * state.fontSize * state.textScaleX * 0.5;
          }
          break;

        case 'TJ': // Show text with individual glyph positioning
          // TJ expects an array of strings and numbers.
          // We look backwards for ']' and '[' to find the array.
          if (i >= 1) {
            _handleTJ(canvas, tokens, i, state, pageHeight);
          }
          break;

        case '\'': // Move to next line and show text
          // Equivalent to T* followed by Tj
          state.textMatrixX = state.lineMatrixX;
          state.textMatrixY = state.lineMatrixY - state.textLeading;
          state.lineMatrixX = state.textMatrixX;
          state.lineMatrixY = state.textMatrixY;
          state.textX = state.textMatrixX;
          state.textY = state.textMatrixY;
          if (i >= 1) {
            final text = _extractPdfString(tokens[i - 1]);
            _drawText(
              canvas,
              text,
              state.textX,
              pageHeight - state.textY,
              state.fontSize * state.textScaleY,
              state.fillColor,
              state.fontName,
            );
          }
          break;

        case '"': // Set word/char spacing, move to next line, show text
          if (i >= 3) {
            state.wordSpacing = _parseDouble(tokens[i - 3]);
            state.charSpacing = _parseDouble(tokens[i - 2]);
            state.textMatrixX = state.lineMatrixX;
            state.textMatrixY = state.lineMatrixY - state.textLeading;
            state.lineMatrixX = state.textMatrixX;
            state.lineMatrixY = state.textMatrixY;
            state.textX = state.textMatrixX;
            state.textY = state.textMatrixY;
            final text = _extractPdfString(tokens[i - 1]);
            _drawText(
              canvas,
              text,
              state.textX,
              pageHeight - state.textY,
              state.fontSize * state.textScaleY,
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
            // Apply the full transformation matrix.
            final matrix = Float64List(16);
            matrix[0] = a;
            matrix[1] = -b;
            matrix[4] = -c;
            matrix[5] = d;
            matrix[10] = 1;
            matrix[12] = e;
            matrix[13] = pageHeight - f;
            matrix[15] = 1;
            if (a == 1 && b == 0 && c == 0 && d == 1) {
              // Simple translation.
              canvas.translate(e, -f);
            } else if (b == 0 && c == 0) {
              // Scale + translate.
              canvas.translate(e, pageHeight - f - pageHeight);
              canvas.scale(a, d);
            }
          }
          break;

        // ── Image XObject ──
        case 'Do':
          // Image rendering requires decoding XObject stream.
          // For basic preview, we skip (images show as blank).
          break;

        // ── Clipping ──
        case 'W': // Set clipping path (non-zero winding)
          if (state.path != null) {
            canvas.clipPath(state.path!);
          }
          break;

        case 'W*': // Set clipping path (even-odd)
          if (state.path != null) {
            state.path!.fillType = ui.PathFillType.evenOdd;
            canvas.clipPath(state.path!);
          }
          break;

        // Handle the composite operator 'f*' when tokenizer splits '*'
        case '*':
          // Check if previous token was a fill/stroke/clip operator.
          if (i >= 1) {
            final prev = tokens[i - 1];
            if (prev == 'f' || prev == 'B' || prev == 'b' || prev == 'W') {
              // Already handled by the combined cases above, but if the
              // tokenizer split them, we skip the standalone '*'.
            }
          }
          break;

        // ── Inline image (BI/ID/EI) — skip ──
        case 'BI':
          // Skip to EI.
          while (i < tokens.length && tokens[i] != 'EI') {
            i++;
          }
          break;
      }

      i++;
    }
  }

  // ── TJ handler ──

  void _handleTJ(
    Canvas canvas,
    List<String> tokens,
    int tjIndex,
    _GraphicsState state,
    double pageHeight,
  ) {
    // Find the matching '[' before TJ.
    // Walk backwards from tjIndex - 1 to find the '[' token.
    int bracketStart = -1;
    for (int j = tjIndex - 1; j >= 0; j--) {
      if (tokens[j] == '[') {
        bracketStart = j;
        break;
      }
    }
    if (bracketStart < 0) return;

    // Collect all string and numeric tokens between '[' and ']'.
    final arrayContent = <String>[];
    for (int j = bracketStart + 1; j < tjIndex; j++) {
      if (tokens[j] == ']') break;
      arrayContent.add(tokens[j]);
    }

    // Render each string segment, adjusting position for kerning numbers.
    final fontSize = state.fontSize * state.textScaleY;
    for (final item in arrayContent) {
      if (item.startsWith('(') && item.endsWith(')')) {
        final text = _extractPdfString(item);
        if (text.isNotEmpty) {
          _drawText(
            canvas,
            text,
            state.textX,
            pageHeight - state.textY,
            fontSize,
            state.fillColor,
            state.fontName,
          );
          // Advance text position estimate.
          state.textX +=
              text.length * state.fontSize * state.textScaleX * 0.5;
        }
      } else if (item.startsWith('<') && item.endsWith('>')) {
        // Hex string — decode and draw.
        final hex = item.substring(1, item.length - 1);
        final text = _decodeHexToText(hex);
        if (text.isNotEmpty) {
          _drawText(
            canvas,
            text,
            state.textX,
            pageHeight - state.textY,
            fontSize,
            state.fillColor,
            state.fontName,
          );
          state.textX +=
              text.length * state.fontSize * state.textScaleX * 0.5;
        }
      } else {
        // Numeric kerning adjustment (in thousandths of a unit of text space).
        final num = double.tryParse(item);
        if (num != null) {
          state.textX -= num / 1000.0 * state.fontSize * state.textScaleX;
        }
      }
    }
  }

  String _decodeHexToText(String hex) {
    final chars = <int>[];
    for (int i = 0; i < hex.length - 1; i += 2) {
      final val = int.tryParse(hex.substring(i, i + 2), radix: 16);
      if (val != null && val >= 32) {
        chars.add(val);
      }
    }
    return String.fromCharCodes(chars);
  }

  // ── Color space helper ──

  void _setColorFromSpace(
    List<String> tokens,
    int opIndex,
    _GraphicsState state, {
    required bool isFill,
  }) {
    final colorSpace =
        isFill ? state.fillColorSpace : state.strokeColorSpace;

    switch (colorSpace) {
      case 'DeviceRGB':
        if (opIndex >= 3) {
          final b = _parseDouble(tokens[opIndex - 1]);
          final g = _parseDouble(tokens[opIndex - 2]);
          final r = _parseDouble(tokens[opIndex - 3]);
          if (isFill) {
            state.fillColor = _colorFromRGB(r, g, b);
          } else {
            state.strokeColor = _colorFromRGB(r, g, b);
          }
        }
        break;

      case 'DeviceGray':
        if (opIndex >= 1) {
          final gray =
              (_parseDouble(tokens[opIndex - 1]) * 255).round().clamp(0, 255);
          final c = Color.fromARGB(255, gray, gray, gray);
          if (isFill) {
            state.fillColor = c;
          } else {
            state.strokeColor = c;
          }
        }
        break;

      case 'DeviceCMYK':
        if (opIndex >= 4) {
          final kk = _parseDouble(tokens[opIndex - 1]);
          final y = _parseDouble(tokens[opIndex - 2]);
          final m = _parseDouble(tokens[opIndex - 3]);
          final c = _parseDouble(tokens[opIndex - 4]);
          final col = _colorFromCMYK(c, m, y, kk);
          if (isFill) {
            state.fillColor = col;
          } else {
            state.strokeColor = col;
          }
        }
        break;

      default:
        // For unknown color spaces, try treating as RGB if 3 operands.
        if (opIndex >= 3) {
          final v3 = _parseDouble(tokens[opIndex - 1]);
          final v2 = _parseDouble(tokens[opIndex - 2]);
          final v1 = _parseDouble(tokens[opIndex - 3]);
          if (v1 <= 1.0 && v2 <= 1.0 && v3 <= 1.0) {
            final c = _colorFromRGB(v1, v2, v3);
            if (isFill) {
              state.fillColor = c;
            } else {
              state.strokeColor = c;
            }
          }
        } else if (opIndex >= 1) {
          // Try as gray.
          final gray =
              (_parseDouble(tokens[opIndex - 1]) * 255).round().clamp(0, 255);
          final c = Color.fromARGB(255, gray, gray, gray);
          if (isFill) {
            state.fillColor = c;
          } else {
            state.strokeColor = c;
          }
        }
    }
  }

  // ── Paint helpers ──

  Paint _fillPaint(_GraphicsState state) {
    return Paint()
      ..color = state.fillColor
      ..style = PaintingStyle.fill;
  }

  Paint _strokePaint(_GraphicsState state) {
    return Paint()
      ..color = state.strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = state.lineWidth
      ..strokeCap = _toStrokeCap(state.lineCap)
      ..strokeJoin = _toStrokeJoin(state.lineJoin)
      ..strokeMiterLimit = state.miterLimit;
  }

  StrokeCap _toStrokeCap(int cap) {
    switch (cap) {
      case 1:
        return StrokeCap.round;
      case 2:
        return StrokeCap.square;
      default:
        return StrokeCap.butt;
    }
  }

  StrokeJoin _toStrokeJoin(int join) {
    switch (join) {
      case 1:
        return StrokeJoin.round;
      case 2:
        return StrokeJoin.bevel;
      default:
        return StrokeJoin.miter;
    }
  }

  // ── Color conversion helpers ──

  Color _colorFromRGB(double r, double g, double b) {
    return Color.fromARGB(
      255,
      (r * 255).round().clamp(0, 255),
      (g * 255).round().clamp(0, 255),
      (b * 255).round().clamp(0, 255),
    );
  }

  Color _colorFromCMYK(double c, double m, double y, double k) {
    final r = ((1 - c) * (1 - k) * 255).round().clamp(0, 255);
    final g = ((1 - m) * (1 - k) * 255).round().clamp(0, 255);
    final b = ((1 - y) * (1 - k) * 255).round().clamp(0, 255);
    return Color.fromARGB(255, r, g, b);
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
  ///
  /// Properly handles parenthesized strings, hex strings, and composite
  /// operators like `f*`, `B*`, `b*`, `W*`, `T*`.
  List<String> _tokenize(String content) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    bool inString = false;
    bool inHexString = false;
    int parenDepth = 0;

    for (int i = 0; i < content.length; i++) {
      final char = content[i];

      // Inside a literal string.
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

      // Inside a hex string.
      if (inHexString) {
        buffer.write(char);
        if (char == '>') {
          tokens.add(buffer.toString());
          buffer.clear();
          inHexString = false;
        }
        continue;
      }

      // Start of literal string.
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

      // Start of hex string.
      if (char == '<' &&
          i + 1 < content.length &&
          content[i + 1] != '<') {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        buffer.write(char);
        inHexString = true;
        continue;
      }

      // PDF name.
      if (char == '/' && buffer.isEmpty) {
        buffer.write(char);
        continue;
      }

      // Whitespace — flush buffer.
      if (char == ' ' || char == '\n' || char == '\r' || char == '\t') {
        if (buffer.isNotEmpty) {
          _flushToken(tokens, buffer.toString());
          buffer.clear();
        }
        continue;
      }

      // Array delimiters.
      if (char == '[' || char == ']') {
        if (buffer.isNotEmpty) {
          _flushToken(tokens, buffer.toString());
          buffer.clear();
        }
        tokens.add(char);
        continue;
      }

      // Dict delimiters << and >>
      if (char == '<' && i + 1 < content.length && content[i + 1] == '<') {
        if (buffer.isNotEmpty) {
          _flushToken(tokens, buffer.toString());
          buffer.clear();
        }
        tokens.add('<<');
        i++; // skip next <
        continue;
      }
      if (char == '>' && i + 1 < content.length && content[i + 1] == '>') {
        if (buffer.isNotEmpty) {
          _flushToken(tokens, buffer.toString());
          buffer.clear();
        }
        tokens.add('>>');
        i++; // skip next >
        continue;
      }

      buffer.write(char);
    }

    if (buffer.isNotEmpty) {
      _flushToken(tokens, buffer.toString());
    }

    return tokens;
  }

  /// Flush a token, merging composite operators like f*, B*, b*, W*, T*.
  void _flushToken(List<String> tokens, String raw) {
    // Check if this is '*' and the previous token forms a composite operator.
    if (raw == '*' && tokens.isNotEmpty) {
      final prev = tokens.last;
      if (prev == 'f' || prev == 'B' || prev == 'b' || prev == 'W' ||
          prev == 'T') {
        tokens[tokens.length - 1] = '$prev*';
        return;
      }
    }
    tokens.add(raw);
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

  /// Parse a token as an int.
  int _parseInt(String token) {
    return int.tryParse(token) ?? 0;
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
  int lineCap;
  int lineJoin;
  double miterLimit;
  ui.Path? path;
  double pathStartX;
  double pathStartY;
  double currentX;
  double currentY;

  // Color space tracking.
  String fillColorSpace;
  String strokeColorSpace;

  // Text state.
  bool inText;
  double textX;
  double textY;
  double textMatrixX;
  double textMatrixY;
  double lineMatrixX;
  double lineMatrixY;
  double fontSize;
  String fontName;
  double textLeading;
  double charSpacing;
  double wordSpacing;
  double textScaleX;
  double textScaleY;

  _GraphicsState({
    this.fillColor = const Color(0xFF000000),
    this.strokeColor = const Color(0xFF000000),
    this.lineWidth = 1.0,
    this.lineCap = 0,
    this.lineJoin = 0,
    this.miterLimit = 10.0,
    this.pathStartX = 0,
    this.pathStartY = 0,
    this.currentX = 0,
    this.currentY = 0,
    this.fillColorSpace = 'DeviceRGB',
    this.strokeColorSpace = 'DeviceRGB',
    this.inText = false,
    this.textX = 0,
    this.textY = 0,
    this.textMatrixX = 0,
    this.textMatrixY = 0,
    this.lineMatrixX = 0,
    this.lineMatrixY = 0,
    this.fontSize = 12,
    this.fontName = '',
    this.textLeading = 0,
    this.charSpacing = 0,
    this.wordSpacing = 0,
    this.textScaleX = 1.0,
    this.textScaleY = 1.0,
  });

  _GraphicsState copy() {
    return _GraphicsState(
      fillColor: fillColor,
      strokeColor: strokeColor,
      lineWidth: lineWidth,
      lineCap: lineCap,
      lineJoin: lineJoin,
      miterLimit: miterLimit,
      pathStartX: pathStartX,
      pathStartY: pathStartY,
      currentX: currentX,
      currentY: currentY,
      fillColorSpace: fillColorSpace,
      strokeColorSpace: strokeColorSpace,
      inText: inText,
      textX: textX,
      textY: textY,
      textMatrixX: textMatrixX,
      textMatrixY: textMatrixY,
      lineMatrixX: lineMatrixX,
      lineMatrixY: lineMatrixY,
      fontSize: fontSize,
      fontName: fontName,
      textLeading: textLeading,
      charSpacing: charSpacing,
      wordSpacing: wordSpacing,
      textScaleX: textScaleX,
      textScaleY: textScaleY,
    );
  }
}
