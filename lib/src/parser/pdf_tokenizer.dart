import 'dart:typed_data';

/// Token types produced by the PDF tokenizer.
enum PdfTokenType {
  /// Integer or real number.
  number,

  /// PDF Name (e.g., /Type, /Page).
  name,

  /// Literal string in parentheses.
  literalString,

  /// Hex string in angle brackets.
  hexString,

  /// Keywords: true, false, null, obj, endobj, stream, endstream,
  /// xref, trailer, startxref, R.
  keyword,

  /// Start of array: [
  arrayStart,

  /// End of array: ]
  arrayEnd,

  /// Start of dictionary: <<
  dictStart,

  /// End of dictionary: >>
  dictEnd,

  /// End of input.
  eof,
}

/// A single token from the PDF byte stream.
class PdfToken {
  final PdfTokenType type;
  final dynamic value;
  final int offset;

  PdfToken(this.type, this.value, this.offset);

  @override
  String toString() => 'PdfToken($type, $value, @$offset)';
}

/// Low-level lexer for PDF byte streams.
///
/// Reads raw PDF bytes and produces a stream of [PdfToken]s.
class PdfTokenizer {
  final Uint8List _data;
  int _pos = 0;

  PdfTokenizer(this._data);

  /// Current byte position.
  int get position => _pos;

  /// Set position for random access.
  set position(int pos) => _pos = pos;

  /// Total number of bytes.
  int get length => _data.length;

  /// Whether we've reached the end.
  bool get isEof => _pos >= _data.length;

  /// Peek at the current byte without advancing.
  int _peek() => _pos < _data.length ? _data[_pos] : -1;

  /// Read the current byte and advance.
  int _read() => _pos < _data.length ? _data[_pos++] : -1;

  /// Skip whitespace and comments.
  void _skipWhitespaceAndComments() {
    while (_pos < _data.length) {
      final c = _data[_pos];
      // Whitespace: space, tab, CR, LF, form feed, null.
      if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D ||
          c == 0x0C || c == 0x00) {
        _pos++;
      } else if (c == 0x25) {
        // Comment: skip to end of line.
        _pos++;
        while (_pos < _data.length &&
            _data[_pos] != 0x0A &&
            _data[_pos] != 0x0D) {
          _pos++;
        }
      } else {
        break;
      }
    }
  }

  /// Read the next token.
  PdfToken nextToken() {
    _skipWhitespaceAndComments();

    if (isEof) return PdfToken(PdfTokenType.eof, null, _pos);

    final startPos = _pos;
    final c = _peek();

    // Array delimiters.
    if (c == 0x5B) {
      // [
      _pos++;
      return PdfToken(PdfTokenType.arrayStart, '[', startPos);
    }
    if (c == 0x5D) {
      // ]
      _pos++;
      return PdfToken(PdfTokenType.arrayEnd, ']', startPos);
    }

    // Dictionary delimiters or hex string.
    if (c == 0x3C) {
      // <
      _pos++;
      if (_peek() == 0x3C) {
        // <<
        _pos++;
        return PdfToken(PdfTokenType.dictStart, '<<', startPos);
      }
      // Hex string.
      return _readHexString(startPos);
    }
    if (c == 0x3E) {
      // >
      _pos++;
      if (_peek() == 0x3E) {
        // >>
        _pos++;
        return PdfToken(PdfTokenType.dictEnd, '>>', startPos);
      }
      // Lone > shouldn't happen in valid PDF, but handle gracefully.
      return PdfToken(PdfTokenType.keyword, '>', startPos);
    }

    // Literal string.
    if (c == 0x28) {
      // (
      return _readLiteralString(startPos);
    }

    // Name.
    if (c == 0x2F) {
      // /
      return _readName(startPos);
    }

    // Number (digits, +, -, .).
    if (_isDigit(c) || c == 0x2B || c == 0x2D || c == 0x2E) {
      return _readNumber(startPos);
    }

    // Keyword (alphabetic).
    if (_isAlpha(c)) {
      return _readKeyword(startPos);
    }

    // Unknown — skip and try again.
    _pos++;
    return nextToken();
  }

  /// Read a hex string: <...>
  PdfToken _readHexString(int startPos) {
    final buf = StringBuffer();
    while (_pos < _data.length) {
      final c = _data[_pos];
      if (c == 0x3E) {
        // >
        _pos++;
        break;
      }
      if (_isHexDigit(c)) {
        buf.writeCharCode(c);
      }
      _pos++;
    }
    return PdfToken(PdfTokenType.hexString, buf.toString(), startPos);
  }

  /// Read a literal string: (...)
  PdfToken _readLiteralString(int startPos) {
    _pos++; // skip (
    final buf = <int>[];
    int parenDepth = 1;

    while (_pos < _data.length && parenDepth > 0) {
      final c = _data[_pos];
      if (c == 0x5C) {
        // backslash escape
        _pos++;
        if (_pos < _data.length) {
          final escaped = _data[_pos];
          switch (escaped) {
            case 0x6E: // n
              buf.add(0x0A);
              break;
            case 0x72: // r
              buf.add(0x0D);
              break;
            case 0x74: // t
              buf.add(0x09);
              break;
            case 0x62: // b
              buf.add(0x08);
              break;
            case 0x66: // f
              buf.add(0x0C);
              break;
            case 0x28: // (
              buf.add(0x28);
              break;
            case 0x29: // )
              buf.add(0x29);
              break;
            case 0x5C: // \
              buf.add(0x5C);
              break;
            case 0x0A: // line continuation (LF)
              break;
            case 0x0D: // line continuation (CR or CRLF)
              if (_pos + 1 < _data.length && _data[_pos + 1] == 0x0A) {
                _pos++;
              }
              break;
            default:
              // Octal escape.
              if (_isOctalDigit(escaped)) {
                int octal = escaped - 0x30;
                for (int i = 0; i < 2; i++) {
                  if (_pos + 1 < _data.length &&
                      _isOctalDigit(_data[_pos + 1])) {
                    _pos++;
                    octal = (octal << 3) | (_data[_pos] - 0x30);
                  }
                }
                buf.add(octal & 0xFF);
              } else {
                buf.add(escaped);
              }
          }
        }
      } else if (c == 0x28) {
        // (
        parenDepth++;
        buf.add(c);
      } else if (c == 0x29) {
        // )
        parenDepth--;
        if (parenDepth > 0) buf.add(c);
      } else {
        buf.add(c);
      }
      _pos++;
    }
    return PdfToken(
        PdfTokenType.literalString, String.fromCharCodes(buf), startPos);
  }

  /// Read a PDF name: /Name
  PdfToken _readName(int startPos) {
    _pos++; // skip /
    final buf = StringBuffer();
    while (_pos < _data.length) {
      final c = _data[_pos];
      if (_isWhitespace(c) || _isDelimiter(c)) break;
      if (c == 0x23 && _pos + 2 < _data.length) {
        // #xx hex escape.
        final hi = _hexVal(_data[_pos + 1]);
        final lo = _hexVal(_data[_pos + 2]);
        if (hi >= 0 && lo >= 0) {
          buf.writeCharCode((hi << 4) | lo);
          _pos += 3;
          continue;
        }
      }
      buf.writeCharCode(c);
      _pos++;
    }
    return PdfToken(PdfTokenType.name, buf.toString(), startPos);
  }

  /// Read a number: integer or real.
  PdfToken _readNumber(int startPos) {
    final buf = StringBuffer();
    bool hasDecimal = false;

    // Sign.
    if (_peek() == 0x2B || _peek() == 0x2D) {
      buf.writeCharCode(_read());
    }

    while (_pos < _data.length) {
      final c = _data[_pos];
      if (_isDigit(c)) {
        buf.writeCharCode(c);
        _pos++;
      } else if (c == 0x2E && !hasDecimal) {
        hasDecimal = true;
        buf.writeCharCode(c);
        _pos++;
      } else {
        break;
      }
    }

    final str = buf.toString();
    if (hasDecimal) {
      return PdfToken(PdfTokenType.number, double.tryParse(str) ?? 0.0, startPos);
    }
    return PdfToken(PdfTokenType.number, int.tryParse(str) ?? 0, startPos);
  }

  /// Read a keyword (alphabetic sequence).
  PdfToken _readKeyword(int startPos) {
    final buf = StringBuffer();
    while (_pos < _data.length) {
      final c = _data[_pos];
      if (_isAlpha(c)) {
        buf.writeCharCode(c);
        _pos++;
      } else {
        break;
      }
    }
    final kw = buf.toString();

    // Check for boolean/null special keywords.
    if (kw == 'true') {
      return PdfToken(PdfTokenType.keyword, true, startPos);
    }
    if (kw == 'false') {
      return PdfToken(PdfTokenType.keyword, false, startPos);
    }
    if (kw == 'null') {
      return PdfToken(PdfTokenType.keyword, null, startPos);
    }

    return PdfToken(PdfTokenType.keyword, kw, startPos);
  }

  // ─── Utility methods ───

  /// Read a line of text from the current position.
  String readLine() {
    final buf = StringBuffer();
    while (_pos < _data.length) {
      final c = _data[_pos++];
      if (c == 0x0A) break;
      if (c == 0x0D) {
        if (_pos < _data.length && _data[_pos] == 0x0A) _pos++;
        break;
      }
      buf.writeCharCode(c);
    }
    return buf.toString();
  }

  /// Read raw bytes from current position.
  Uint8List readBytes(int count) {
    final end = (_pos + count).clamp(0, _data.length);
    final result = _data.sublist(_pos, end);
    _pos = end;
    return result;
  }

  /// Find the byte offset of a string searching backwards from the end.
  int? findLast(String needle) {
    final needleBytes = needle.codeUnits;
    for (int i = _data.length - needleBytes.length; i >= 0; i--) {
      bool match = true;
      for (int j = 0; j < needleBytes.length; j++) {
        if (_data[i + j] != needleBytes[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return null;
  }

  /// Find the byte offset of a string searching forward from [start].
  int? findForward(String needle, [int start = 0]) {
    final needleBytes = needle.codeUnits;
    for (int i = start; i <= _data.length - needleBytes.length; i++) {
      bool match = true;
      for (int j = 0; j < needleBytes.length; j++) {
        if (_data[i + j] != needleBytes[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return null;
  }

  // ─── Character classification ───

  bool _isWhitespace(int c) =>
      c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D ||
      c == 0x0C || c == 0x00;

  bool _isDelimiter(int c) =>
      c == 0x28 || // (
      c == 0x29 || // )
      c == 0x3C || // <
      c == 0x3E || // >
      c == 0x5B || // [
      c == 0x5D || // ]
      c == 0x7B || // {
      c == 0x7D || // }
      c == 0x2F || // /
      c == 0x25; // %

  bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
  bool _isAlpha(int c) =>
      (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);
  bool _isHexDigit(int c) =>
      _isDigit(c) ||
      (c >= 0x41 && c <= 0x46) ||
      (c >= 0x61 && c <= 0x66);
  bool _isOctalDigit(int c) => c >= 0x30 && c <= 0x37;

  int _hexVal(int c) {
    if (c >= 0x30 && c <= 0x39) return c - 0x30;
    if (c >= 0x41 && c <= 0x46) return c - 0x41 + 10;
    if (c >= 0x61 && c <= 0x66) return c - 0x61 + 10;
    return -1;
  }
}
