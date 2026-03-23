import 'dart:typed_data';

/// Base class for all PDF objects.
abstract class PdfObject {
  /// Serialize this object to PDF syntax bytes.
  void writeTo(StringBuffer buffer);

  @override
  String toString() {
    final buffer = StringBuffer();
    writeTo(buffer);
    return buffer.toString();
  }
}

/// PDF Boolean value.
class PdfBoolean extends PdfObject {
  final bool value;
  PdfBoolean(this.value);

  @override
  void writeTo(StringBuffer buffer) {
    buffer.write(value ? 'true' : 'false');
  }
}

/// PDF Null value.
class PdfNull extends PdfObject {
  @override
  void writeTo(StringBuffer buffer) {
    buffer.write('null');
  }
}

/// PDF numeric value (int or double).
class PdfNumber extends PdfObject {
  final num value;
  PdfNumber(this.value);

  PdfNumber.fromInt(int v) : value = v;
  PdfNumber.fromDouble(double v) : value = v;

  @override
  void writeTo(StringBuffer buffer) {
    if (value is int || value == value.roundToDouble()) {
      buffer.write(value.toInt().toString());
    } else {
      // Format with up to 6 decimal places, trimming trailing zeros.
      String s = value.toStringAsFixed(6);
      // Remove trailing zeros after decimal point.
      if (s.contains('.')) {
        s = s.replaceAll(RegExp(r'0+$'), '');
        s = s.replaceAll(RegExp(r'\.$'), '');
      }
      buffer.write(s);
    }
  }
}

/// PDF Name object (e.g., /Type, /Page).
class PdfName extends PdfObject {
  final String name;
  PdfName(this.name);

  @override
  void writeTo(StringBuffer buffer) {
    buffer.write('/');
    // Escape special characters in name.
    for (int i = 0; i < name.length; i++) {
      final c = name.codeUnitAt(i);
      if (c < 0x21 ||
          c > 0x7E ||
          c == 0x23 || // #
          c == 0x28 || // (
          c == 0x29 || // )
          c == 0x3C || // <
          c == 0x3E || // >
          c == 0x5B || // [
          c == 0x5D || // ]
          c == 0x7B || // {
          c == 0x7D || // }
          c == 0x2F) {
        // /
        buffer.write('#${c.toRadixString(16).padLeft(2, '0').toUpperCase()}');
      } else {
        buffer.writeCharCode(c);
      }
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PdfName && name == other.name;

  @override
  int get hashCode => name.hashCode;
}

/// PDF String (literal or hexadecimal).
class PdfString extends PdfObject {
  final String value;
  final bool hex;

  PdfString(this.value, {this.hex = false});

  /// Create from raw bytes as hex string.
  PdfString.fromBytes(Uint8List bytes)
      : value = bytes
            .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
            .join(),
        hex = true;

  @override
  void writeTo(StringBuffer buffer) {
    if (hex) {
      buffer.write('<$value>');
    } else {
      buffer.write('(');
      for (int i = 0; i < value.length; i++) {
        final c = value[i];
        switch (c) {
          case '\\':
            buffer.write('\\\\');
            break;
          case '(':
            buffer.write('\\(');
            break;
          case ')':
            buffer.write('\\)');
            break;
          case '\n':
            buffer.write('\\n');
            break;
          case '\r':
            buffer.write('\\r');
            break;
          case '\t':
            buffer.write('\\t');
            break;
          default:
            buffer.write(c);
        }
      }
      buffer.write(')');
    }
  }
}

/// PDF Array.
class PdfArray extends PdfObject {
  final List<PdfObject> elements;

  PdfArray([List<PdfObject>? elements]) : elements = elements ?? [];

  void add(PdfObject obj) => elements.add(obj);

  @override
  void writeTo(StringBuffer buffer) {
    buffer.write('[');
    for (int i = 0; i < elements.length; i++) {
      if (i > 0) buffer.write(' ');
      elements[i].writeTo(buffer);
    }
    buffer.write(']');
  }
}

/// PDF Dictionary.
class PdfDictionary extends PdfObject {
  final Map<PdfName, PdfObject> entries;

  PdfDictionary([Map<PdfName, PdfObject>? entries])
      : entries = entries ?? <PdfName, PdfObject>{};

  void set(String key, PdfObject value) {
    entries[PdfName(key)] = value;
  }

  PdfObject? get(String key) {
    return entries[PdfName(key)];
  }

  bool containsKey(String key) {
    return entries.containsKey(PdfName(key));
  }

  @override
  void writeTo(StringBuffer buffer) {
    buffer.write('<<');
    entries.forEach((key, value) {
      buffer.write('\n');
      key.writeTo(buffer);
      buffer.write(' ');
      value.writeTo(buffer);
    });
    buffer.write('\n>>');
  }
}

/// PDF indirect object reference (e.g., "5 0 R").
class PdfReference extends PdfObject {
  final int objectNumber;
  final int generationNumber;

  PdfReference(this.objectNumber, [this.generationNumber = 0]);

  @override
  void writeTo(StringBuffer buffer) {
    buffer.write('$objectNumber $generationNumber R');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfReference &&
          objectNumber == other.objectNumber &&
          generationNumber == other.generationNumber;

  @override
  int get hashCode => objectNumber.hashCode ^ generationNumber.hashCode;
}

/// PDF indirect object — wraps any PdfObject with an object number.
class PdfIndirectObject {
  final int objectNumber;
  final int generationNumber;
  final PdfObject object;

  PdfIndirectObject(this.objectNumber, this.object,
      [this.generationNumber = 0]);

  /// Get a reference to this object.
  PdfReference get reference =>
      PdfReference(objectNumber, generationNumber);

  /// Write the full indirect object definition.
  void writeTo(StringBuffer buffer) {
    buffer.write('$objectNumber $generationNumber obj\n');
    object.writeTo(buffer);
    buffer.write('\nendobj\n');
  }
}
