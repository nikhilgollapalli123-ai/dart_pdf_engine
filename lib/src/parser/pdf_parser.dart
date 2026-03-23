import 'dart:typed_data';
import 'pdf_tokenizer.dart';
import '../pdf_objects.dart';
import '../utils/zlib_codec.dart';

/// Parsed representation of a PDF page.
class ParsedPage {
  final double width;
  final double height;
  final Uint8List? contentStreamData;
  final Map<String, PdfDictionary> fontResources;
  final Map<String, dynamic> imageResources;

  ParsedPage({
    required this.width,
    required this.height,
    this.contentStreamData,
    this.fontResources = const {},
    this.imageResources = const {},
  });
}

/// Parsed representation of a bookmark.
class ParsedBookmark {
  final String title;
  final int pageIndex;

  ParsedBookmark({required this.title, required this.pageIndex});
}

/// High-level PDF parser.
///
/// Parses raw PDF bytes into structured data: pages, fonts,
/// bookmarks, and document metadata.
class PdfParser {
  final Uint8List _data;
  late final PdfTokenizer _tokenizer;

  /// All indirect objects keyed by object number.
  final Map<int, dynamic> _objects = {};

  /// Cross-reference table: obj number -> byte offset.
  final Map<int, int> _xrefTable = {};

  /// Parsed pages.
  final List<ParsedPage> pages = [];

  /// Parsed bookmarks.
  final List<ParsedBookmark> bookmarks = [];

  /// Document info.
  String? title;
  String? author;
  String? subject;
  String? creator;

  PdfParser(this._data) {
    _tokenizer = PdfTokenizer(_data);
  }

  /// Parse the PDF and populate all fields.
  void parse() {
    _readXRef();
    _readTrailer();
    _parsePages();
    _parseBookmarks();
  }

  // ═══════════════════════════════════════════════════════════
  // XREF PARSING
  // ═══════════════════════════════════════════════════════════

  void _readXRef() {
    // Find startxref position.
    final startxrefPos = _tokenizer.findLast('startxref');
    if (startxrefPos == null) {
      throw FormatException('Cannot find startxref in PDF');
    }

    // Read the xref offset.
    _tokenizer.position = startxrefPos + 'startxref'.length;
    final tok = _tokenizer.nextToken();
    if (tok.type != PdfTokenType.number) {
      throw FormatException('Expected xref offset after startxref');
    }
    final xrefOffset = (tok.value as num).toInt();

    // Jump to xref.
    _tokenizer.position = xrefOffset;

    // Check if it starts with 'xref' keyword (traditional table).
    final line = _readLineAt(xrefOffset);
    if (line.trim() == 'xref') {
      _parseTraditionalXRef(xrefOffset);
    } else {
      // Cross-reference stream (object stream) — parse it.
      _parseXRefStream(xrefOffset);
    }
  }

  void _parseTraditionalXRef(int offset) {
    _tokenizer.position = offset;
    _tokenizer.readLine(); // skip 'xref'

    while (true) {
      final line = _tokenizer.readLine().trim();
      if (line.isEmpty) continue;
      if (line.startsWith('trailer')) break;

      // Subsection header: startObj count
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 2) break;

      final startObj = int.tryParse(parts[0]);
      final count = int.tryParse(parts[1]);
      if (startObj == null || count == null) break;

      for (int i = 0; i < count; i++) {
        final entryLine = _tokenizer.readLine().trim();
        if (entryLine.length < 18) continue;

        final entryParts = entryLine.split(RegExp(r'\s+'));
        if (entryParts.length < 3) continue;

        final byteOffset = int.tryParse(entryParts[0]) ?? 0;
        final flag = entryParts[2];

        if (flag == 'n' && startObj + i > 0) {
          _xrefTable[startObj + i] = byteOffset;
        }
      }

      // Check if next line starts a new subsection or is 'trailer'.
      if (_tokenizer.isEof) break;
    }
  }

  void _parseXRefStream(int offset) {
    // For cross-reference streams, parse the object at this offset.
    _tokenizer.position = offset;
    final obj = _parseIndirectObject();
    if (obj == null) return;

    final dict = obj['dict'];
    if (dict is! Map<String, dynamic>) return;

    final size = _getIntFromDict(dict, 'Size') ?? 0;
    final wArray = dict['W'];
    if (wArray is! List || wArray.length < 3) return;

    final w1 = (wArray[0] as num).toInt();
    final w2 = (wArray[1] as num).toInt();
    final w3 = (wArray[2] as num).toInt();
    final entrySize = w1 + w2 + w3;

    // Get the stream data.
    Uint8List streamData = obj['streamData'] ?? Uint8List(0);

    // Decompress if needed.
    final filter = dict['Filter'];
    if (filter == 'FlateDecode' && streamData.isNotEmpty) {
      try {
        streamData = ZlibCodec.decompress(streamData);
      } catch (_) {}
    }

    // Parse index array or default.
    List<int> indexArray = [0, size];
    if (dict['Index'] is List) {
      indexArray = (dict['Index'] as List).map((e) => (e as num).toInt()).toList();
    }

    int dataOffset = 0;
    for (int idx = 0; idx < indexArray.length; idx += 2) {
      final startObj = indexArray[idx];
      final count = idx + 1 < indexArray.length ? indexArray[idx + 1] : 0;

      for (int i = 0; i < count; i++) {
        if (dataOffset + entrySize > streamData.length) break;

        int type = 1;
        if (w1 > 0) {
          type = _readIntFromBytes(streamData, dataOffset, w1);
        }

        final field2 = w2 > 0
            ? _readIntFromBytes(streamData, dataOffset + w1, w2)
            : 0;

        // type 1 = regular object with byte offset.
        if (type == 1 && startObj + i > 0) {
          _xrefTable[startObj + i] = field2;
        }

        dataOffset += entrySize;
      }
    }

    // Also check for /Prev to follow xref chain.
    final prev = _getIntFromDict(dict, 'Prev');
    if (prev != null) {
      final prevLine = _readLineAt(prev);
      if (prevLine.trim() == 'xref') {
        _parseTraditionalXRef(prev);
      } else {
        _parseXRefStream(prev);
      }
    }
  }

  int _readIntFromBytes(Uint8List data, int offset, int width) {
    int val = 0;
    for (int i = 0; i < width; i++) {
      val = (val << 8) | data[offset + i];
    }
    return val;
  }

  // ═══════════════════════════════════════════════════════════
  // TRAILER PARSING
  // ═══════════════════════════════════════════════════════════

  Map<String, dynamic>? _trailerDict;

  void _readTrailer() {
    // Try to find traditional trailer.
    final trailerPos = _tokenizer.findLast('trailer');
    if (trailerPos != null) {
      _tokenizer.position = trailerPos + 'trailer'.length;
      _trailerDict = _parseDict();
    } else {
      // The trailer info might be in the xref stream object.
      // Find startxref and parse the stream object's dict as trailer.
      final startxrefPos = _tokenizer.findLast('startxref');
      if (startxrefPos != null) {
        _tokenizer.position = startxrefPos + 'startxref'.length;
        final tok = _tokenizer.nextToken();
        if (tok.type == PdfTokenType.number) {
          final xrefOffset = (tok.value as num).toInt();
          _tokenizer.position = xrefOffset;
          final obj = _parseIndirectObject();
          if (obj != null && obj['dict'] is Map<String, dynamic>) {
            _trailerDict = obj['dict'];
          }
        }
      }
    }

    if (_trailerDict == null) return;

    // Parse document info.
    final infoRef = _trailerDict!['Info'];
    if (infoRef is Map && infoRef['ref'] is int) {
      final infoDict = _resolveObject(infoRef['ref']);
      if (infoDict is Map<String, dynamic>) {
        title = infoDict['Title'] as String?;
        author = infoDict['Author'] as String?;
        subject = infoDict['Subject'] as String?;
        creator = infoDict['Creator'] as String?;
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // PAGE PARSING
  // ═══════════════════════════════════════════════════════════

  void _parsePages() {
    if (_trailerDict == null) return;

    // Get Root (Catalog).
    final rootRef = _trailerDict!['Root'];
    if (rootRef is! Map || rootRef['ref'] is! int) return;

    final catalog = _resolveObject(rootRef['ref']);
    if (catalog is! Map<String, dynamic>) return;

    // Get Pages.
    final pagesRef = catalog['Pages'];
    if (pagesRef is! Map || pagesRef['ref'] is! int) return;

    final pagesDict = _resolveObject(pagesRef['ref']);
    if (pagesDict is! Map<String, dynamic>) return;

    // Recursively collect all Page objects.
    _collectPages(pagesDict, null);
  }

  void _collectPages(Map<String, dynamic> node, List<num>? inheritedMediaBox) {
    final type = node['Type'] as String?;
    final mediaBox = node['MediaBox'] as List? ?? inheritedMediaBox;

    if (type == 'Page') {
      // This is a leaf page.
      double width = 612;
      double height = 792;

      if (mediaBox != null && mediaBox.length >= 4) {
        width = (mediaBox[2] as num).toDouble();
        height = (mediaBox[3] as num).toDouble();
      }

      // Resolve content stream.
      Uint8List? contentData;
      final contents = node['Contents'];
      if (contents is Map && contents['ref'] is int) {
        final contentsObj = _resolveObjectRaw(contents['ref']);
        if (contentsObj != null) {
          contentData = _getStreamData(contentsObj);
        }
      } else if (contents is List) {
        // Multiple content streams — concatenate.
        final allData = <int>[];
        for (final item in contents) {
          if (item is Map && item['ref'] is int) {
            final obj = _resolveObjectRaw(item['ref']);
            if (obj != null) {
              final data = _getStreamData(obj);
              if (data != null) {
                allData.addAll(data);
                allData.add(0x0A); // newline separator.
              }
            }
          }
        }
        if (allData.isNotEmpty) {
          contentData = Uint8List.fromList(allData);
        }
      }

      // Resolve font resources.
      final fontResources = <String, PdfDictionary>{};
      var resources = node['Resources'];
      // Resolve indirect Resources reference.
      if (resources is Map && resources['ref'] is int) {
        resources = _resolveObject(resources['ref']);
      }
      if (resources is Map<String, dynamic>) {
        var fonts = resources['Font'];
        // Resolve indirect Font dict reference.
        if (fonts is Map && fonts['ref'] is int) {
          fonts = _resolveObject(fonts['ref']);
        }
        if (fonts is Map<String, dynamic>) {
          for (final entry in fonts.entries) {
            if (entry.value is Map && (entry.value as Map)['ref'] is int) {
              final fontDict = _resolveObject((entry.value as Map)['ref']);
              if (fontDict is Map<String, dynamic>) {
                // Convert to PdfDictionary for compatibility.
                final pdfDict = PdfDictionary();
                fontDict.forEach((k, v) {
                  if (v is String) {
                    pdfDict.set(k, PdfName(v));
                  } else if (v is num) {
                    pdfDict.set(k, PdfNumber(v));
                  }
                });
                fontResources[entry.key] = pdfDict;
              }
            }
          }
        }
      }

      pages.add(ParsedPage(
        width: width,
        height: height,
        contentStreamData: contentData,
        fontResources: fontResources,
      ));
    } else if (type == 'Pages') {
      // Pages node — recurse into Kids.
      final kids = node['Kids'] as List?;
      if (kids != null) {
        for (final kid in kids) {
          if (kid is Map && kid['ref'] is int) {
            final kidDict = _resolveObject(kid['ref']);
            if (kidDict is Map<String, dynamic>) {
              _collectPages(
                kidDict,
                mediaBox?.cast<num>(),
              );
            }
          }
        }
      }
    }
  }

  Uint8List? _getStreamData(Map<String, dynamic> obj) {
    final streamData = obj['_streamData'];
    if (streamData is! Uint8List || streamData.isEmpty) return null;

    // Check for filter.
    final dict = obj['_dict'] as Map<String, dynamic>? ?? obj;
    final filter = dict['Filter'] as String?;

    if (filter == 'FlateDecode') {
      try {
        return ZlibCodec.decompress(streamData);
      } catch (_) {
        return streamData;
      }
    }
    return streamData;
  }

  // ═══════════════════════════════════════════════════════════
  // BOOKMARK PARSING
  // ═══════════════════════════════════════════════════════════

  void _parseBookmarks() {
    if (_trailerDict == null) return;

    final rootRef = _trailerDict!['Root'];
    if (rootRef is! Map || rootRef['ref'] is! int) return;

    final catalog = _resolveObject(rootRef['ref']);
    if (catalog is! Map<String, dynamic>) return;

    final outlinesRef = catalog['Outlines'];
    if (outlinesRef is! Map || outlinesRef['ref'] is! int) return;

    final outlines = _resolveObject(outlinesRef['ref']);
    if (outlines is! Map<String, dynamic>) return;

    // Walk the bookmark tree.
    var firstRef = outlines['First'];
    while (firstRef is Map && firstRef['ref'] is int) {
      final bm = _resolveObject(firstRef['ref']);
      if (bm is! Map<String, dynamic>) break;

      final bmTitle = bm['Title'] as String? ?? '';

      // Parse destination to find page index.
      int pageIndex = 0;
      final dest = bm['Dest'];
      if (dest is List && dest.isNotEmpty) {
        final pageRef = dest[0];
        if (pageRef is Map && pageRef['ref'] is int) {
          pageIndex = _findPageIndex(pageRef['ref']);
        }
      }

      bookmarks.add(ParsedBookmark(title: bmTitle, pageIndex: pageIndex));

      // Move to next sibling.
      firstRef = bm['Next'];
    }
  }

  int _findPageIndex(int objNum) {
    // This is a simplification — we match page object numbers.
    // During page collection, we'd need to track which obj nums map to which pages.
    // For now, use a heuristic based on the Dest array.
    return 0;
  }

  // ═══════════════════════════════════════════════════════════
  // OBJECT RESOLUTION
  // ═══════════════════════════════════════════════════════════

  /// Resolve an indirect object by its number, returning the parsed value.
  dynamic _resolveObject(int objNum) {
    if (_objects.containsKey(objNum)) return _objects[objNum];

    final raw = _resolveObjectRaw(objNum);
    if (raw == null) return null;

    final result = raw['_dict'] ?? raw;
    _objects[objNum] = result;
    return result;
  }

  /// Resolve an indirect object, returning the raw parsed structure
  /// including stream data.
  Map<String, dynamic>? _resolveObjectRaw(int objNum) {
    final offset = _xrefTable[objNum];
    if (offset == null) return null;

    _tokenizer.position = offset;
    return _parseIndirectObject();
  }

  /// Parse an indirect object at the current tokenizer position.
  /// Returns a map with '_dict' and optionally '_streamData'.
  Map<String, dynamic>? _parseIndirectObject() {
    final objNumTok = _tokenizer.nextToken();
    if (objNumTok.type != PdfTokenType.number) return null;

    final genTok = _tokenizer.nextToken();
    if (genTok.type != PdfTokenType.number) return null;

    final objKw = _tokenizer.nextToken();
    if (objKw.type != PdfTokenType.keyword || objKw.value != 'obj') return null;

    // Parse the object value.
    final value = _parseValue();

    // Check for stream.
    Uint8List? streamData;
    final savedPos = _tokenizer.position;
    final nextTok = _tokenizer.nextToken();

    if (nextTok.type == PdfTokenType.keyword && nextTok.value == 'stream') {
      // Skip the newline after 'stream'.
      while (_tokenizer.position < _tokenizer.length) {
        final c = _data[_tokenizer.position];
        if (c == 0x0A) {
          _tokenizer.position++;
          break;
        } else if (c == 0x0D) {
          _tokenizer.position++;
          if (_tokenizer.position < _tokenizer.length &&
              _data[_tokenizer.position] == 0x0A) {
            _tokenizer.position++;
          }
          break;
        }
        _tokenizer.position++;
      }

      // Determine stream length.
      int streamLength = 0;
      if (value is Map<String, dynamic>) {
        final len = value['Length'];
        if (len is int) {
          streamLength = len;
        } else if (len is Map && len['ref'] is int) {
          // Indirect length reference.
          final lenObj = _resolveObject(len['ref']);
          if (lenObj is int) {
            streamLength = lenObj;
          } else if (lenObj is Map<String, dynamic>) {
            // Sometimes the resolved object is just a number.
            streamLength = 0;
          }
        }
      }

      if (streamLength > 0 &&
          _tokenizer.position + streamLength <= _tokenizer.length) {
        streamData = _tokenizer.readBytes(streamLength);
      } else {
        // Fallback: search for 'endstream'.
        final endPos = _tokenizer.findForward(
            'endstream', _tokenizer.position);
        if (endPos != null) {
          final startPos = _tokenizer.position;
          var end = endPos;
          // Trim trailing whitespace.
          while (end > startPos && (_data[end - 1] == 0x0A ||
              _data[end - 1] == 0x0D)) {
            end--;
          }
          streamData = _data.sublist(startPos, end);
          _tokenizer.position = endPos + 'endstream'.length;
        }
      }
    } else {
      _tokenizer.position = savedPos;
    }

    if (value is Map<String, dynamic>) {
      final result = Map<String, dynamic>.from(value);
      if (streamData != null) {
        result['_streamData'] = streamData;
        result['_dict'] = value;
      }
      return result;
    }

    // Non-dict object (e.g., a number).
    return {'_value': value, if (streamData != null) '_streamData': streamData};
  }

  // ═══════════════════════════════════════════════════════════
  // VALUE PARSING
  // ═══════════════════════════════════════════════════════════

  /// Parse a single PDF value (number, name, string, array, dict, ref).
  dynamic _parseValue() {
    final tok = _tokenizer.nextToken();

    switch (tok.type) {
      case PdfTokenType.number:
        // Could be a number or start of an indirect reference (N N R).
        final savedPos = _tokenizer.position;
        final next1 = _tokenizer.nextToken();
        if (next1.type == PdfTokenType.number) {
          final next2 = _tokenizer.nextToken();
          if (next2.type == PdfTokenType.keyword && next2.value == 'R') {
            return {'ref': (tok.value as num).toInt()};
          }
        }
        _tokenizer.position = savedPos;
        return tok.value;

      case PdfTokenType.name:
        return tok.value as String;

      case PdfTokenType.literalString:
        return tok.value as String;

      case PdfTokenType.hexString:
        return _decodeHexString(tok.value as String);

      case PdfTokenType.dictStart:
        return _parseDictValues();

      case PdfTokenType.arrayStart:
        return _parseArrayValues();

      case PdfTokenType.keyword:
        if (tok.value == true) return true;
        if (tok.value == false) return false;
        if (tok.value == null) return null;
        return tok.value;

      default:
        return null;
    }
  }

  /// Parse the inside of a dictionary (after <<).
  Map<String, dynamic> _parseDictValues() {
    final dict = <String, dynamic>{};

    while (true) {
      final tok = _tokenizer.nextToken();
      if (tok.type == PdfTokenType.dictEnd || tok.type == PdfTokenType.eof) {
        break;
      }
      if (tok.type != PdfTokenType.name) continue;

      final key = tok.value as String;
      final value = _parseValue();
      dict[key] = value;
    }

    return dict;
  }

  /// Parse the inside of an array (after [).
  List<dynamic> _parseArrayValues() {
    final arr = <dynamic>[];

    while (true) {
      final savedPos = _tokenizer.position;
      final tok = _tokenizer.nextToken();
      if (tok.type == PdfTokenType.arrayEnd || tok.type == PdfTokenType.eof) {
        break;
      }
      _tokenizer.position = savedPos;
      final value = _parseValue();
      arr.add(value);
    }

    return arr;
  }

  /// Parse a dictionary from current position (expects << to be next).
  Map<String, dynamic>? _parseDict() {
    final tok = _tokenizer.nextToken();
    if (tok.type == PdfTokenType.dictStart) {
      return _parseDictValues();
    }
    return null;
  }

  /// Decode a hex string, handling UTF-16BE BOM.
  String _decodeHexString(String hex) {
    final bytes = <int>[];
    for (int i = 0; i < hex.length - 1; i += 2) {
      final hi = int.tryParse(hex[i], radix: 16) ?? 0;
      final lo = int.tryParse(hex[i + 1], radix: 16) ?? 0;
      bytes.add((hi << 4) | lo);
    }
    if (hex.length.isOdd) {
      bytes.add((int.tryParse(hex[hex.length - 1], radix: 16) ?? 0) << 4);
    }

    // Check for UTF-16BE BOM (FEFF).
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      final chars = <int>[];
      for (int i = 2; i < bytes.length - 1; i += 2) {
        chars.add((bytes[i] << 8) | bytes[i + 1]);
      }
      return String.fromCharCodes(chars);
    }

    return String.fromCharCodes(bytes);
  }

  // ─── Helpers ───

  String _readLineAt(int offset) {
    _tokenizer.position = offset;
    return _tokenizer.readLine();
  }

  int? _getIntFromDict(Map<String, dynamic> dict, String key) {
    final val = dict[key];
    if (val is int) return val;
    if (val is double) return val.toInt();
    return null;
  }
}
