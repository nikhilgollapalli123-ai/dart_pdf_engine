/// Font metrics for the 14 standard PDF fonts.
class FontMetrics {
  final String fontName;
  final double ascent;
  final double descent;
  final double avgWidth;
  final Map<int, double> _widths; // char code -> width in 1000 units

  const FontMetrics({
    required this.fontName,
    required this.ascent,
    required this.descent,
    required this.avgWidth,
    required Map<int, double> widths,
  }) : _widths = widths;

  /// Get width of a character in 1000ths of a unit.
  double getCharWidth(int charCode) {
    return _widths[charCode] ?? avgWidth;
  }

  /// Measure the width of a string in points at the given font size.
  double measureString(String text, double fontSize) {
    double total = 0;
    for (int i = 0; i < text.length; i++) {
      total += getCharWidth(text.codeUnitAt(i));
    }
    return total * fontSize / 1000.0;
  }

  /// Get the line height in points at the given font size.
  double getLineHeight(double fontSize) {
    return (ascent - descent) * fontSize / 1000.0;
  }
}

/// Pre-built metrics for the 14 standard PDF fonts.
/// These use the standard AFM (Adobe Font Metrics) values.
class StandardFontMetrics {
  StandardFontMetrics._();

  static FontMetrics getMetrics(String fontName) {
    switch (fontName) {
      case 'Helvetica':
        return _helvetica;
      case 'Helvetica-Bold':
        return _helveticaBold;
      case 'Helvetica-Oblique':
        return _helveticaOblique;
      case 'Helvetica-BoldOblique':
        return _helveticaBoldOblique;
      case 'Times-Roman':
        return _timesRoman;
      case 'Times-Bold':
        return _timesBold;
      case 'Times-Italic':
        return _timesItalic;
      case 'Times-BoldItalic':
        return _timesBoldItalic;
      case 'Courier':
        return _courier;
      case 'Courier-Bold':
        return _courierBold;
      case 'Courier-Oblique':
        return _courierOblique;
      case 'Courier-BoldOblique':
        return _courierBoldOblique;
      case 'Symbol':
        return _symbol;
      case 'ZapfDingbats':
        return _zapfDingbats;
      default:
        return _helvetica;
    }
  }

  // Common ASCII widths for Helvetica (close approximation from AFM data).
  static const _defaultWidths = <int, double>{
    32: 278, 33: 278, 34: 355, 35: 556, 36: 556, 37: 889, 38: 667, 39: 191,
    40: 333, 41: 333, 42: 389, 43: 584, 44: 278, 45: 333, 46: 278, 47: 278,
    48: 556, 49: 556, 50: 556, 51: 556, 52: 556, 53: 556, 54: 556, 55: 556,
    56: 556, 57: 556, 58: 278, 59: 278, 60: 584, 61: 584, 62: 584, 63: 556,
    64: 1015, 65: 667, 66: 667, 67: 722, 68: 722, 69: 667, 70: 611, 71: 778,
    72: 722, 73: 278, 74: 500, 75: 667, 76: 556, 77: 833, 78: 722, 79: 778,
    80: 667, 81: 778, 82: 722, 83: 667, 84: 611, 85: 722, 86: 667, 87: 944,
    88: 667, 89: 667, 90: 611,
    91: 278, 92: 278, 93: 278, 94: 469, 95: 556, 96: 333,
    97: 556, 98: 556, 99: 500, 100: 556, 101: 556, 102: 278, 103: 556,
    104: 556, 105: 222, 106: 222, 107: 500, 108: 222, 109: 833, 110: 556,
    111: 556, 112: 556, 113: 556, 114: 333, 115: 500, 116: 278, 117: 556,
    118: 500, 119: 722, 120: 500, 121: 500, 122: 500,
    123: 334, 124: 260, 125: 334, 126: 584,
  };

  static const FontMetrics _helvetica = FontMetrics(
    fontName: 'Helvetica',
    ascent: 718,
    descent: -207,
    avgWidth: 556,
    widths: _defaultWidths,
  );

  static final FontMetrics _helveticaBold = FontMetrics(
    fontName: 'Helvetica-Bold',
    ascent: 718,
    descent: -207,
    avgWidth: 575,
    widths: const <int, double>{
      32: 278, 33: 333, 34: 474, 35: 556, 36: 556, 37: 889, 38: 722, 39: 238,
      40: 333, 41: 333, 42: 389, 43: 584, 44: 278, 45: 333, 46: 278, 47: 278,
      48: 556, 49: 556, 50: 556, 51: 556, 52: 556, 53: 556, 54: 556, 55: 556,
      56: 556, 57: 556, 58: 333, 59: 333, 60: 584, 61: 584, 62: 584, 63: 611,
      64: 975, 65: 722, 66: 722, 67: 722, 68: 722, 69: 667, 70: 611, 71: 778,
      72: 722, 73: 278, 74: 556, 75: 722, 76: 611, 77: 833, 78: 722, 79: 778,
      80: 667, 81: 778, 82: 722, 83: 667, 84: 611, 85: 722, 86: 667, 87: 944,
      88: 667, 89: 667, 90: 611,
      91: 333, 92: 278, 93: 333, 94: 584, 95: 556, 96: 333,
      97: 556, 98: 611, 99: 556, 100: 611, 101: 556, 102: 333, 103: 611,
      104: 611, 105: 278, 106: 278, 107: 556, 108: 278, 109: 889, 110: 611,
      111: 611, 112: 611, 113: 611, 114: 389, 115: 556, 116: 333, 117: 611,
      118: 556, 119: 778, 120: 556, 121: 556, 122: 500,
      123: 389, 124: 280, 125: 389, 126: 584,
    },
  );

  static const FontMetrics _helveticaOblique = FontMetrics(
    fontName: 'Helvetica-Oblique',
    ascent: 718,
    descent: -207,
    avgWidth: 556,
    widths: _defaultWidths,
  );

  static const FontMetrics _helveticaBoldOblique = FontMetrics(
    fontName: 'Helvetica-BoldOblique',
    ascent: 718,
    descent: -207,
    avgWidth: 575,
    widths: _defaultWidths,
  );

  static const FontMetrics _timesRoman = FontMetrics(
    fontName: 'Times-Roman',
    ascent: 683,
    descent: -217,
    avgWidth: 500,
    widths: <int, double>{
      32: 250, 33: 333, 34: 408, 35: 500, 36: 500, 37: 833, 38: 778, 39: 180,
      40: 333, 41: 333, 42: 500, 43: 564, 44: 250, 45: 333, 46: 250, 47: 278,
      48: 500, 49: 500, 50: 500, 51: 500, 52: 500, 53: 500, 54: 500, 55: 500,
      56: 500, 57: 500, 58: 278, 59: 278, 60: 564, 61: 564, 62: 564, 63: 444,
      64: 921, 65: 722, 66: 667, 67: 667, 68: 722, 69: 611, 70: 556, 71: 722,
      72: 722, 73: 333, 74: 389, 75: 722, 76: 611, 77: 889, 78: 722, 79: 722,
      80: 556, 81: 722, 82: 667, 83: 556, 84: 611, 85: 722, 86: 722, 87: 944,
      88: 722, 89: 722, 90: 611,
      91: 333, 92: 278, 93: 333, 94: 469, 95: 500, 96: 333,
      97: 444, 98: 500, 99: 444, 100: 500, 101: 444, 102: 333, 103: 500,
      104: 500, 105: 278, 106: 278, 107: 500, 108: 278, 109: 778, 110: 500,
      111: 500, 112: 500, 113: 500, 114: 333, 115: 389, 116: 278, 117: 500,
      118: 500, 119: 722, 120: 500, 121: 500, 122: 444,
      123: 480, 124: 200, 125: 480, 126: 541,
    },
  );

  static const FontMetrics _timesBold = FontMetrics(
    fontName: 'Times-Bold',
    ascent: 683,
    descent: -217,
    avgWidth: 535,
    widths: <int, double>{
      32: 250, 33: 333, 34: 555, 35: 500, 36: 500, 37: 1000, 38: 833, 39: 278,
      40: 333, 41: 333, 42: 500, 43: 570, 44: 250, 45: 333, 46: 250, 47: 278,
      48: 500, 49: 500, 50: 500, 51: 500, 52: 500, 53: 500, 54: 500, 55: 500,
      56: 500, 57: 500, 58: 333, 59: 333, 60: 570, 61: 570, 62: 570, 63: 500,
      64: 930, 65: 722, 66: 667, 67: 722, 68: 722, 69: 667, 70: 611, 71: 778,
      72: 778, 73: 389, 74: 500, 75: 778, 76: 667, 77: 944, 78: 722, 79: 778,
      80: 611, 81: 778, 82: 722, 83: 556, 84: 667, 85: 722, 86: 722, 87: 1000,
      88: 722, 89: 722, 90: 667,
      91: 333, 92: 278, 93: 333, 94: 581, 95: 500, 96: 333,
      97: 500, 98: 556, 99: 444, 100: 556, 101: 444, 102: 333, 103: 500,
      104: 556, 105: 278, 106: 333, 107: 556, 108: 278, 109: 833, 110: 556,
      111: 500, 112: 556, 113: 556, 114: 444, 115: 389, 116: 333, 117: 556,
      118: 500, 119: 722, 120: 500, 121: 500, 122: 444,
      123: 394, 124: 220, 125: 394, 126: 520,
    },
  );

  static const FontMetrics _timesItalic = FontMetrics(
    fontName: 'Times-Italic',
    ascent: 683,
    descent: -217,
    avgWidth: 500,
    widths: <int, double>{
      32: 250, 33: 333, 34: 420, 35: 500, 36: 500, 37: 833, 38: 778, 39: 214,
      40: 333, 41: 333, 42: 500, 43: 675, 44: 250, 45: 333, 46: 250, 47: 278,
      48: 500, 49: 500, 50: 500, 51: 500, 52: 500, 53: 500, 54: 500, 55: 500,
      56: 500, 57: 500, 58: 333, 59: 333, 60: 675, 61: 675, 62: 675, 63: 500,
      64: 920, 65: 611, 66: 611, 67: 667, 68: 722, 69: 611, 70: 611, 71: 722,
      72: 722, 73: 333, 74: 444, 75: 667, 76: 556, 77: 833, 78: 667, 79: 722,
      80: 611, 81: 722, 82: 611, 83: 500, 84: 556, 85: 722, 86: 611, 87: 833,
      88: 611, 89: 556, 90: 556,
      91: 389, 92: 278, 93: 389, 94: 422, 95: 500, 96: 333,
      97: 500, 98: 500, 99: 444, 100: 500, 101: 444, 102: 278, 103: 500,
      104: 500, 105: 278, 106: 278, 107: 444, 108: 278, 109: 722, 110: 500,
      111: 500, 112: 500, 113: 500, 114: 389, 115: 389, 116: 278, 117: 500,
      118: 444, 119: 667, 120: 444, 121: 444, 122: 389,
      123: 400, 124: 275, 125: 400, 126: 541,
    },
  );

  static const FontMetrics _timesBoldItalic = FontMetrics(
    fontName: 'Times-BoldItalic',
    ascent: 683,
    descent: -217,
    avgWidth: 535,
    widths: <int, double>{
      32: 250, 33: 389, 34: 555, 35: 500, 36: 500, 37: 833, 38: 778, 39: 278,
      40: 333, 41: 333, 42: 500, 43: 570, 44: 250, 45: 333, 46: 250, 47: 278,
      48: 500, 49: 500, 50: 500, 51: 500, 52: 500, 53: 500, 54: 500, 55: 500,
      56: 500, 57: 500, 58: 333, 59: 333, 60: 570, 61: 570, 62: 570, 63: 500,
      64: 832, 65: 667, 66: 667, 67: 667, 68: 722, 69: 667, 70: 667, 71: 722,
      72: 778, 73: 389, 74: 500, 75: 667, 76: 611, 77: 889, 78: 722, 79: 722,
      80: 611, 81: 722, 82: 667, 83: 556, 84: 611, 85: 722, 86: 667, 87: 889,
      88: 667, 89: 611, 90: 611,
      91: 333, 92: 278, 93: 333, 94: 570, 95: 500, 96: 333,
      97: 500, 98: 500, 99: 444, 100: 500, 101: 444, 102: 333, 103: 500,
      104: 556, 105: 278, 106: 278, 107: 500, 108: 278, 109: 778, 110: 556,
      111: 500, 112: 500, 113: 500, 114: 389, 115: 389, 116: 278, 117: 556,
      118: 444, 119: 667, 120: 500, 121: 444, 122: 389,
      123: 348, 124: 220, 125: 348, 126: 570,
    },
  );

  static const FontMetrics _courier = FontMetrics(
    fontName: 'Courier',
    ascent: 629,
    descent: -157,
    avgWidth: 600,
    widths: <int, double>{}, // Courier is monospaced — all chars are 600
  );

  static const FontMetrics _courierBold = FontMetrics(
    fontName: 'Courier-Bold',
    ascent: 629,
    descent: -157,
    avgWidth: 600,
    widths: <int, double>{},
  );

  static const FontMetrics _courierOblique = FontMetrics(
    fontName: 'Courier-Oblique',
    ascent: 629,
    descent: -157,
    avgWidth: 600,
    widths: <int, double>{},
  );

  static const FontMetrics _courierBoldOblique = FontMetrics(
    fontName: 'Courier-BoldOblique',
    ascent: 629,
    descent: -157,
    avgWidth: 600,
    widths: <int, double>{},
  );

  static const FontMetrics _symbol = FontMetrics(
    fontName: 'Symbol',
    ascent: 683,
    descent: -217,
    avgWidth: 500,
    widths: <int, double>{},
  );

  static const FontMetrics _zapfDingbats = FontMetrics(
    fontName: 'ZapfDingbats',
    ascent: 683,
    descent: -217,
    avgWidth: 500,
    widths: <int, double>{},
  );
}
