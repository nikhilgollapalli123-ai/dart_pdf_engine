import 'dart:typed_data';
import 'pdf_font.dart';
import 'font_metrics.dart';

/// A TrueType font that can be embedded in the PDF.
/// Supports Unicode text rendering.
class PdfTrueTypeFont extends PdfFont {
  final Uint8List fontData;
  @override
  final double size;
  late final _TrueTypeParser _parser;
  late final FontMetrics _metrics;

  PdfTrueTypeFont(this.fontData, this.size) {
    _parser = _TrueTypeParser(fontData);
    _parser.parse();
    _metrics = FontMetrics(
      fontName: _parser.fontName,
      ascent: _parser.ascent.toDouble(),
      descent: _parser.descent.toDouble(),
      avgWidth: _parser.avgWidth.toDouble(),
      widths: _parser.glyphWidths,
    );
  }

  @override
  String get name => _parser.fontName;

  @override
  FontMetrics get metrics => _metrics;

  /// Get the raw font data for embedding.
  Uint8List get rawData => fontData;

  /// Get the font name from the name table.
  String get fontFamily => _parser.fontName;

  /// Get the cmap (character to glyph) mapping.
  Map<int, int> get cmap => _parser.cmap;

  /// Get the width of a glyph by glyph index.
  Map<int, double> get glyphWidths => _parser.glyphWidths;

  /// Get bounding box.
  List<int> get bbox => _parser.bbox;

  /// Get italic angle.
  double get italicAngle => _parser.italicAngle;

  /// Get flags for font descriptor.
  int get flags => _parser.flags;

  /// Get cap height.
  int get capHeight => _parser.capHeight;

  /// Get stem V.
  int get stemV => _parser.stemV;
}

/// Minimal TrueType font parser to extract metrics and mappings.
class _TrueTypeParser {
  final Uint8List data;
  late ByteData _bytes;

  String fontName = 'Unknown';
  int ascent = 800;
  int descent = -200;
  int avgWidth = 500;
  int unitsPerEm = 1000;
  double italicAngle = 0;
  int flags = 32; // Nonsymbolic
  int capHeight = 700;
  int stemV = 80;
  List<int> bbox = [0, -200, 1000, 800];
  Map<int, int> cmap = {};
  Map<int, double> glyphWidths = {};

  int _numGlyphs = 0;
  List<int> _hmtxWidths = [];

  _TrueTypeParser(this.data) {
    _bytes = ByteData.view(data.buffer, data.offsetInBytes, data.lengthInBytes);
  }

  void parse() {
    if (data.length < 12) return;

    // Read table directory.
    final numTables = _bytes.getUint16(4);
    final tables = <String, _TableRecord>{};

    for (int i = 0; i < numTables; i++) {
      final offset = 12 + i * 16;
      if (offset + 16 > data.length) break;
      final tag = String.fromCharCodes(data.sublist(offset, offset + 4));
      final tableOffset = _bytes.getUint32(offset + 8);
      final tableLength = _bytes.getUint32(offset + 12);
      tables[tag] = _TableRecord(tableOffset, tableLength);
    }

    // Parse 'head' table.
    if (tables.containsKey('head')) {
      _parseHead(tables['head']!);
    }

    // Parse 'name' table.
    if (tables.containsKey('name')) {
      _parseName(tables['name']!);
    }

    // Parse 'hhea' table.
    if (tables.containsKey('hhea')) {
      _parseHhea(tables['hhea']!);
    }

    // Parse 'maxp' table.
    if (tables.containsKey('maxp')) {
      _parseMaxp(tables['maxp']!);
    }

    // Parse 'hmtx' table.
    if (tables.containsKey('hmtx')) {
      _parseHmtx(tables['hmtx']!);
    }

    // Parse 'OS/2' table.
    if (tables.containsKey('OS/2')) {
      _parseOs2(tables['OS/2']!);
    }

    // Parse 'cmap' table.
    if (tables.containsKey('cmap')) {
      _parseCmap(tables['cmap']!);
    }

    // Build character widths from cmap + hmtx.
    _buildCharWidths();
  }

  void _parseHead(_TableRecord table) {
    if (table.offset + 54 > data.length) return;
    unitsPerEm = _bytes.getUint16(table.offset + 18);
    final xMin = _bytes.getInt16(table.offset + 36);
    final yMin = _bytes.getInt16(table.offset + 38);
    final xMax = _bytes.getInt16(table.offset + 40);
    final yMax = _bytes.getInt16(table.offset + 42);
    bbox = [
      (xMin * 1000 / unitsPerEm).round(),
      (yMin * 1000 / unitsPerEm).round(),
      (xMax * 1000 / unitsPerEm).round(),
      (yMax * 1000 / unitsPerEm).round(),
    ];
  }

  void _parseName(_TableRecord table) {
    if (table.offset + 6 > data.length) return;
    final count = _bytes.getUint16(table.offset + 2);
    final stringOffset = _bytes.getUint16(table.offset + 4);

    for (int i = 0; i < count; i++) {
      final recordOffset = table.offset + 6 + i * 12;
      if (recordOffset + 12 > data.length) break;

      final nameId = _bytes.getUint16(recordOffset + 6);
      final length = _bytes.getUint16(recordOffset + 8);
      final offset = _bytes.getUint16(recordOffset + 10);
      final platformId = _bytes.getUint16(recordOffset);

      // Name ID 4 = full font name, 1 = font family.
      if (nameId == 4 || (nameId == 1 && fontName == 'Unknown')) {
        final strStart = table.offset + stringOffset + offset;
        if (strStart + length <= data.length) {
          if (platformId == 1) {
            // Macintosh: single-byte encoding.
            fontName = String.fromCharCodes(
                data.sublist(strStart, strStart + length));
          } else if (platformId == 3) {
            // Windows: UTF-16BE.
            final chars = <int>[];
            for (int j = 0; j < length - 1; j += 2) {
              chars.add(_bytes.getUint16(strStart + j));
            }
            fontName = String.fromCharCodes(chars);
          }
          if (nameId == 4) break; // Prefer full name.
        }
      }
    }
  }

  void _parseHhea(_TableRecord table) {
    if (table.offset + 36 > data.length) return;
    ascent = _bytes.getInt16(table.offset + 4);
    descent = _bytes.getInt16(table.offset + 6);
    // Number of long hor. metrics.
    _numGlyphs = _bytes.getUint16(table.offset + 34);
  }

  void _parseMaxp(_TableRecord table) {
    if (table.offset + 6 > data.length) return;
    final numGlyphsMaxp = _bytes.getUint16(table.offset + 4);
    if (_numGlyphs == 0) _numGlyphs = numGlyphsMaxp;
  }

  void _parseHmtx(_TableRecord table) {
    _hmtxWidths = [];
    for (int i = 0; i < _numGlyphs; i++) {
      final off = table.offset + i * 4;
      if (off + 4 > data.length) break;
      _hmtxWidths.add(_bytes.getUint16(off));
    }
    if (_hmtxWidths.isNotEmpty) {
      int sum = 0;
      for (final w in _hmtxWidths) {
        sum += w;
      }
      avgWidth = (sum / _hmtxWidths.length).round();
    }
  }

  void _parseOs2(_TableRecord table) {
    if (table.offset + 78 > data.length) return;
    // sTypoAscender and sTypoDescender (preferred over hhea).
    final typoAscent = _bytes.getInt16(table.offset + 68);
    final typoDescent = _bytes.getInt16(table.offset + 70);
    if (typoAscent != 0) ascent = typoAscent;
    if (typoDescent != 0) descent = typoDescent;

    // sCapHeight
    if (table.offset + 88 <= data.length) {
      capHeight = _bytes.getInt16(table.offset + 88);
    }
  }

  void _parseCmap(_TableRecord table) {
    if (table.offset + 4 > data.length) return;
    final numSubtables = _bytes.getUint16(table.offset + 2);

    // Find a Unicode cmap subtable.
    for (int i = 0; i < numSubtables; i++) {
      final subOffset = table.offset + 4 + i * 8;
      if (subOffset + 8 > data.length) break;

      final platformId = _bytes.getUint16(subOffset);
      final encodingId = _bytes.getUint16(subOffset + 2);
      final offset = _bytes.getUint32(subOffset + 4);

      // Unicode (0, 3) or Windows Unicode (3, 1).
      if ((platformId == 0 && encodingId == 3) ||
          (platformId == 3 && encodingId == 1)) {
        _parseCmapSubtable(table.offset + offset);
        if (cmap.isNotEmpty) break;
      }
    }

    // Fallback: try any format 4 subtable.
    if (cmap.isEmpty) {
      for (int i = 0; i < numSubtables; i++) {
        final subOffset = table.offset + 4 + i * 8;
        if (subOffset + 8 > data.length) break;
        final offset = _bytes.getUint32(subOffset + 4);
        _parseCmapSubtable(table.offset + offset);
        if (cmap.isNotEmpty) break;
      }
    }
  }

  void _parseCmapSubtable(int offset) {
    if (offset + 2 > data.length) return;
    final format = _bytes.getUint16(offset);

    if (format == 4) {
      _parseCmapFormat4(offset);
    }
  }

  void _parseCmapFormat4(int offset) {
    if (offset + 14 > data.length) return;
    final segCount = _bytes.getUint16(offset + 6) ~/ 2;

    final endCodes = <int>[];
    final startCodes = <int>[];
    final idDeltas = <int>[];
    final idRangeOffsets = <int>[];

    // End codes.
    for (int i = 0; i < segCount; i++) {
      final off = offset + 14 + i * 2;
      if (off + 2 > data.length) return;
      endCodes.add(_bytes.getUint16(off));
    }

    // Skip reservedPad.
    final startCodeOffset = offset + 14 + segCount * 2 + 2;

    // Start codes.
    for (int i = 0; i < segCount; i++) {
      final off = startCodeOffset + i * 2;
      if (off + 2 > data.length) return;
      startCodes.add(_bytes.getUint16(off));
    }

    // ID deltas.
    final idDeltaOffset = startCodeOffset + segCount * 2;
    for (int i = 0; i < segCount; i++) {
      final off = idDeltaOffset + i * 2;
      if (off + 2 > data.length) return;
      idDeltas.add(_bytes.getInt16(off));
    }

    // ID range offsets.
    final idRangeOffsetStart = idDeltaOffset + segCount * 2;
    for (int i = 0; i < segCount; i++) {
      final off = idRangeOffsetStart + i * 2;
      if (off + 2 > data.length) return;
      idRangeOffsets.add(_bytes.getUint16(off));
    }

    // Build cmap.
    for (int i = 0; i < segCount; i++) {
      if (endCodes[i] == 0xFFFF) continue;
      for (int charCode = startCodes[i];
          charCode <= endCodes[i];
          charCode++) {
        int glyphIndex;
        if (idRangeOffsets[i] == 0) {
          glyphIndex = (charCode + idDeltas[i]) & 0xFFFF;
        } else {
          final glyphOffset = idRangeOffsetStart +
              i * 2 +
              idRangeOffsets[i] +
              (charCode - startCodes[i]) * 2;
          if (glyphOffset + 2 > data.length) continue;
          glyphIndex = _bytes.getUint16(glyphOffset);
          if (glyphIndex != 0) {
            glyphIndex = (glyphIndex + idDeltas[i]) & 0xFFFF;
          }
        }
        if (glyphIndex != 0) {
          cmap[charCode] = glyphIndex;
        }
      }
    }
  }

  void _buildCharWidths() {
    // Normalize to 1000 units.
    final scale = 1000.0 / unitsPerEm;
    ascent = (ascent * scale).round();
    descent = (descent * scale).round();
    avgWidth = (avgWidth * scale).round();
    capHeight = (capHeight * scale).round();

    // Build character code -> width mapping.
    glyphWidths = {};
    cmap.forEach((charCode, glyphIndex) {
      if (glyphIndex < _hmtxWidths.length) {
        glyphWidths[charCode] = (_hmtxWidths[glyphIndex] * scale);
      } else if (_hmtxWidths.isNotEmpty) {
        glyphWidths[charCode] = (_hmtxWidths.last * scale);
      }
    });

    // Estimate stemV from average width.
    stemV = (avgWidth * 0.13).round();
    if (stemV < 50) stemV = 80;
  }
}

class _TableRecord {
  final int offset;
  final int length;
  _TableRecord(this.offset, this.length);
}
