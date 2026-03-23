/// Represents a Bezier path for drawing complex shapes.
class PdfPath {
  final List<_PathSegment> _segments = [];

  /// Move to a point without drawing.
  void moveTo(double x, double y) {
    _segments.add(_PathSegment(_PathOp.moveTo, [x, y]));
  }

  /// Draw a line to a point.
  void lineTo(double x, double y) {
    _segments.add(_PathSegment(_PathOp.lineTo, [x, y]));
  }

  /// Draw a cubic Bezier curve.
  void curveTo(
      double x1, double y1, double x2, double y2, double x3, double y3) {
    _segments.add(_PathSegment(_PathOp.curveTo, [x1, y1, x2, y2, x3, y3]));
  }

  /// Close the current subpath.
  void closePath() {
    _segments.add(_PathSegment(_PathOp.close, []));
  }

  /// Add a rectangle to the path.
  void addRectangle(double x, double y, double width, double height) {
    _segments.add(_PathSegment(_PathOp.rectangle, [x, y, width, height]));
  }

  /// Add an ellipse approximated by Bezier curves.
  void addEllipse(double x, double y, double width, double height) {
    // Approximate ellipse with 4 cubic Bezier curves.
    final cx = x + width / 2;
    final cy = y + height / 2;
    final rx = width / 2;
    final ry = height / 2;
    // Magic number for Bezier approximation of a circle quadrant.
    const k = 0.5522847498;

    moveTo(cx + rx, cy);
    curveTo(cx + rx, cy + ry * k, cx + rx * k, cy + ry, cx, cy + ry);
    curveTo(cx - rx * k, cy + ry, cx - rx, cy + ry * k, cx - rx, cy);
    curveTo(cx - rx, cy - ry * k, cx - rx * k, cy - ry, cx, cy - ry);
    curveTo(cx + rx * k, cy - ry, cx + rx, cy - ry * k, cx + rx, cy);
    closePath();
  }

  /// Convert path to PDF content stream operators.
  String toOperators() {
    final buffer = StringBuffer();
    for (final seg in _segments) {
      switch (seg.op) {
        case _PathOp.moveTo:
          buffer.writeln(
              '${_fmt(seg.points[0])} ${_fmt(seg.points[1])} m');
          break;
        case _PathOp.lineTo:
          buffer.writeln(
              '${_fmt(seg.points[0])} ${_fmt(seg.points[1])} l');
          break;
        case _PathOp.curveTo:
          buffer.writeln(
              '${_fmt(seg.points[0])} ${_fmt(seg.points[1])} '
              '${_fmt(seg.points[2])} ${_fmt(seg.points[3])} '
              '${_fmt(seg.points[4])} ${_fmt(seg.points[5])} c');
          break;
        case _PathOp.close:
          buffer.writeln('h');
          break;
        case _PathOp.rectangle:
          buffer.writeln(
              '${_fmt(seg.points[0])} ${_fmt(seg.points[1])} '
              '${_fmt(seg.points[2])} ${_fmt(seg.points[3])} re');
          break;
      }
    }
    return buffer.toString();
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    String s = v.toStringAsFixed(4);
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
    return s;
  }
}

enum _PathOp { moveTo, lineTo, curveTo, close, rectangle }

class _PathSegment {
  final _PathOp op;
  final List<double> points;
  _PathSegment(this.op, this.points);
}
