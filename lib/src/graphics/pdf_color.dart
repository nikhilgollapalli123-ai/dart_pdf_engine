/// Represents a color in PDF (RGB, 0-255 per channel).
class PdfColor {
  final int red;
  final int green;
  final int blue;
  final int alpha;

  const PdfColor(this.red, this.green, this.blue, [this.alpha = 255]);

  // Named constructors for common colors.
  static const PdfColor black = PdfColor(0, 0, 0);
  static const PdfColor white = PdfColor(255, 255, 255);
  static const PdfColor red_ = PdfColor(255, 0, 0);
  static const PdfColor green_ = PdfColor(0, 128, 0);
  static const PdfColor blue_ = PdfColor(0, 0, 255);
  static const PdfColor gray = PdfColor(128, 128, 128);
  static const PdfColor lightGray = PdfColor(211, 211, 211);
  static const PdfColor darkGray = PdfColor(64, 64, 64);
  static const PdfColor transparent = PdfColor(0, 0, 0, 0);

  /// Get the red component as 0.0–1.0.
  double get r => red / 255.0;

  /// Get the green component as 0.0–1.0.
  double get g => green / 255.0;

  /// Get the blue component as 0.0–1.0.
  double get b => blue / 255.0;

  /// Get the alpha component as 0.0–1.0.
  double get a => alpha / 255.0;

  /// Returns the PDF color operator string for fill (rg).
  String toFillOperator() {
    return '${_fmt(r)} ${_fmt(g)} ${_fmt(b)} rg';
  }

  /// Returns the PDF color operator string for stroke (RG).
  String toStrokeOperator() {
    return '${_fmt(r)} ${_fmt(g)} ${_fmt(b)} RG';
  }

  String _fmt(double v) {
    if (v == 0) return '0';
    if (v == 1) return '1';
    String s = v.toStringAsFixed(4);
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
    return s;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfColor &&
          red == other.red &&
          green == other.green &&
          blue == other.blue &&
          alpha == other.alpha;

  @override
  int get hashCode => Object.hash(red, green, blue, alpha);
}
