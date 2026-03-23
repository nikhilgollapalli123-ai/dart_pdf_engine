import 'dart:convert';
import 'dart:typed_data';
import 'pdf_objects.dart';
import 'pdf_stream.dart';
import 'pdf_cross_reference.dart';
import 'pdf_page.dart';
import 'fonts/pdf_standard_font.dart';
import 'fonts/pdf_truetype_font.dart';
import 'bookmarks/pdf_bookmark.dart';
import 'utils/pdf_constants.dart';
import 'parser/pdf_parser.dart';

/// The main entry point for creating PDF documents.
///
/// Example:
/// ```dart
/// final document = PdfDocument();
/// document.pages.add().graphics.drawString(
///   'Hello World!',
///   PdfStandardFont(PdfFontFamily.helvetica, 12),
///   brush: PdfSolidBrush(PdfColor(0, 0, 0)),
///   bounds: Rect.fromLTWH(0, 0, 200, 50),
/// );
/// final bytes = document.save();
/// document.dispose();
/// ```
class PdfDocument {
  final PdfPageCollection pages = PdfPageCollection();
  final PdfDocumentInfo documentInfo = PdfDocumentInfo();
  final PdfBookmarkCollection bookmarks = PdfBookmarkCollection();

  /// Raw bytes of the original PDF (if loaded from bytes/base64).
  Uint8List? _rawBytes;

  /// Whether this document was loaded from existing PDF data.
  bool get isLoaded => _rawBytes != null;

  /// Get the raw bytes of the original PDF (if loaded).
  Uint8List? get rawBytes => _rawBytes;

  /// Create a new empty PDF document.
  PdfDocument();

  /// Create a PdfDocument from base64-encoded PDF data.
  factory PdfDocument.fromBase64(String base64Data) {
    final bytes = base64Decode(base64Data);
    return PdfDocument.fromBytes(bytes);
  }

  /// Create a PdfDocument from raw PDF bytes.
  ///
  /// Parses the PDF structure including pages, fonts, bookmarks,
  /// and document metadata.
  factory PdfDocument.fromBytes(Uint8List bytes) {
    final doc = PdfDocument();
    doc._rawBytes = bytes;

    try {
      final parser = PdfParser(bytes);
      parser.parse();

      // Populate document info.
      if (parser.title != null) doc.documentInfo.title = parser.title;
      if (parser.author != null) doc.documentInfo.author = parser.author;
      if (parser.subject != null) doc.documentInfo.subject = parser.subject;
      if (parser.creator != null) doc.documentInfo.creator = parser.creator;

      // Populate pages.
      for (final parsedPage in parser.pages) {
        String? contentStreamStr;
        if (parsedPage.contentStreamData != null) {
          contentStreamStr =
              String.fromCharCodes(parsedPage.contentStreamData!);
        }

        final page = PdfPage.fromParsed(
          width: parsedPage.width,
          height: parsedPage.height,
          contentStream: contentStreamStr,
        );
        doc.pages._pages.add(page);
      }

      // Populate bookmarks.
      for (final bm in parser.bookmarks) {
        doc.bookmarks.add(bm.title, pageIndex: bm.pageIndex);
      }
    } catch (e) {
      // If parsing fails, store the raw bytes and return an empty doc.
      // Users can still access rawBytes for their own purposes.
    }

    return doc;
  }

  /// Save the document and return PDF bytes.
  ///
  /// If the document was loaded from existing bytes, returns the
  /// original bytes (preserving all fonts, images, etc.).
  /// For new documents, serializes the current state.
  List<int> save() {
    // If loaded from bytes, return original (preserves embedded fonts/images).
    if (_rawBytes != null) {
      return _rawBytes!;
    }
    return _serialize();
  }

  /// Save only the original bytes (if loaded from base64/bytes).
  /// Returns null if this is a newly created document.
  List<int>? saveOriginalBytes() => _rawBytes != null ? List<int>.from(_rawBytes!) : null;

  /// Re-serialize the document from scratch (for new or modified documents).
  /// Note: For loaded documents, use [save] to preserve original formatting.
  List<int> saveAsNew() {
    return _serialize();
  }

  /// Save the document and return as base64 string.
  String saveAsBase64() {
    return base64Encode(save());
  }

  /// Dispose resources.
  void dispose() {
    _rawBytes = null;
  }

  /// Serialize the entire document to PDF bytes.
  List<int> _serialize() {
    final output = <int>[];
    int nextObjNum = 1;
    final objectOffsets = <int, int>{}; // objNum -> byte offset

    // 1. Write PDF header.
    _writeString(output, '${PdfConstants.pdfVersion}\n');
    output.addAll(PdfConstants.binaryMarker);
    output.add(PdfConstants.lf);

    // 2. Build object graph.
    // Catalog (object 1).
    final catalogNum = nextObjNum++;
    // Pages tree (object 2).
    final pagesNum = nextObjNum++;
    // Info dictionary.
    final infoNum = nextObjNum++;

    // 3. Build each page and its resources.
    final pageRefs = <PdfReference>[];
    final pageData = <_PageBuildData>[];

    for (final page in pages._pages) {
      final data = _buildPage(page, nextObjNum, pagesNum);
      pageData.add(data);
      pageRefs.add(PdfReference(data.pageObjNum));
      nextObjNum = data.nextObjNum;
    }

    // 4. Build bookmarks if any.
    int? outlinesObjNum;
    List<_BookmarkBuildData>? bookmarkData;
    if (bookmarks.bookmarks.isNotEmpty) {
      outlinesObjNum = nextObjNum++;
      bookmarkData = [];
      for (final bm in bookmarks.bookmarks) {
        final bmObjNum = nextObjNum++;
        bookmarkData.add(_BookmarkBuildData(
          objNum: bmObjNum,
          title: bm.title,
          pageRef: bm.pageIndex < pageData.length
              ? PdfReference(pageData[bm.pageIndex].pageObjNum)
              : pageRefs.isNotEmpty
                  ? pageRefs.first
                  : PdfReference(pagesNum),
        ));
      }
    }

    // 5. Write Info dictionary.
    objectOffsets[infoNum] = output.length;
    _writeString(output, '$infoNum 0 obj\n');
    final infoDict = PdfDictionary();
    if (documentInfo.title != null) {
      infoDict.set('Title', PdfString(documentInfo.title!));
    }
    if (documentInfo.author != null) {
      infoDict.set('Author', PdfString(documentInfo.author!));
    }
    if (documentInfo.subject != null) {
      infoDict.set('Subject', PdfString(documentInfo.subject!));
    }
    if (documentInfo.creator != null) {
      infoDict.set('Creator', PdfString(documentInfo.creator!));
    }
    infoDict.set('Producer', PdfString('dart_pdf_engine 1.0.0'));
    _writeString(output, infoDict.toString());
    _writeString(output, '\nendobj\n');

    // 6. Write Pages tree.
    objectOffsets[pagesNum] = output.length;
    _writeString(output, '$pagesNum 0 obj\n');
    final pagesDict = PdfDictionary();
    pagesDict.set('Type', PdfName('Pages'));
    pagesDict.set('Kids', PdfArray(pageRefs.cast<PdfObject>()));
    pagesDict.set('Count', PdfNumber(pages._pages.length));
    _writeString(output, pagesDict.toString());
    _writeString(output, '\nendobj\n');

    // 7. Write each page's objects.
    for (final pd in pageData) {
      for (final obj in pd.objects) {
        objectOffsets[obj.objectNumber] = output.length;
        _writeObjBytes(output, obj.objectNumber, obj.bytes);
      }
    }

    // 8. Write bookmarks.
    if (outlinesObjNum != null && bookmarkData != null) {
      // Outlines dictionary.
      objectOffsets[outlinesObjNum] = output.length;
      _writeString(output, '$outlinesObjNum 0 obj\n');
      final outlinesDict = PdfDictionary();
      outlinesDict.set('Type', PdfName('Outlines'));
      outlinesDict.set('Count', PdfNumber(bookmarkData.length));
      if (bookmarkData.isNotEmpty) {
        outlinesDict.set('First', PdfReference(bookmarkData.first.objNum));
        outlinesDict.set('Last', PdfReference(bookmarkData.last.objNum));
      }
      _writeString(output, outlinesDict.toString());
      _writeString(output, '\nendobj\n');

      // Each bookmark.
      for (int i = 0; i < bookmarkData.length; i++) {
        final bm = bookmarkData[i];
        objectOffsets[bm.objNum] = output.length;
        _writeString(output, '${bm.objNum} 0 obj\n');
        final bmDict = PdfDictionary();
        bmDict.set('Title', PdfString(bm.title));
        bmDict.set('Parent', PdfReference(outlinesObjNum));
        bmDict.set('Dest', PdfArray([
          bm.pageRef,
          PdfName('Fit'),
        ]));
        if (i > 0) {
          bmDict.set('Prev', PdfReference(bookmarkData[i - 1].objNum));
        }
        if (i < bookmarkData.length - 1) {
          bmDict.set('Next', PdfReference(bookmarkData[i + 1].objNum));
        }
        _writeString(output, bmDict.toString());
        _writeString(output, '\nendobj\n');
      }
    }

    // 9. Write Catalog.
    objectOffsets[catalogNum] = output.length;
    _writeString(output, '$catalogNum 0 obj\n');
    final catalogDict = PdfDictionary();
    catalogDict.set('Type', PdfName('Catalog'));
    catalogDict.set('Pages', PdfReference(pagesNum));
    if (outlinesObjNum != null) {
      catalogDict.set('Outlines', PdfReference(outlinesObjNum));
    }
    _writeString(output, catalogDict.toString());
    _writeString(output, '\nendobj\n');

    // 10. Write xref table.
    final xrefOffset = output.length;
    final xref = PdfCrossReference();
    final sortedObjNums = objectOffsets.keys.toList()..sort();
    for (final objNum in sortedObjNums) {
      xref.addEntry(objNum, objectOffsets[objNum]!);
    }
    output.addAll(xref.toBytes());

    // 11. Write trailer.
    _writeString(output, 'trailer\n');
    final trailerDict = PdfDictionary();
    trailerDict.set('Size', PdfNumber(nextObjNum));
    trailerDict.set('Root', PdfReference(catalogNum));
    trailerDict.set('Info', PdfReference(infoNum));
    _writeString(output, trailerDict.toString());
    _writeString(output, '\nstartxref\n$xrefOffset\n');
    _writeString(output, PdfConstants.eof);
    _writeString(output, '\n');

    return output;
  }

  _PageBuildData _buildPage(PdfPage page, int startObjNum, int pagesObjNum) {
    int nextObj = startObjNum;
    final builtObjects = <_ObjBytes>[];

    final pageObjNum = nextObj++;
    final contentsObjNum = nextObj++;

    // Build font objects.
    final fontResourceEntries = <PdfName, PdfObject>{};

    for (final entry in page.graphics.fonts.entries) {
      final fontObjNum = nextObj++;

      final font = entry.value;
      final fontDict = PdfDictionary();
      fontDict.set('Type', PdfName('Font'));

      if (font is PdfStandardFont) {
        fontDict.set('Subtype', PdfName('Type1'));
        fontDict.set('BaseFont', PdfName(font.name));
        fontDict.set('Encoding', PdfName('WinAnsiEncoding'));

        final fontBuf = StringBuffer();
        fontDict.writeTo(fontBuf);
        builtObjects.add(_ObjBytes(fontObjNum, fontBuf.toString().codeUnits));
      } else if (font is PdfTrueTypeFont) {
        // TrueType font with embedding for selectable text.
        fontDict.set('Subtype', PdfName('TrueType'));
        fontDict.set('BaseFont', PdfName(font.name.replaceAll(' ', '-')));
        fontDict.set('Encoding', PdfName('WinAnsiEncoding'));

        // Font descriptor.
        final descriptorObjNum = nextObj++;
        fontDict.set('FontDescriptor', PdfReference(descriptorObjNum));

        // First/Last char + Widths array.
        const firstChar = 32;
        const lastChar = 255;
        fontDict.set('FirstChar', PdfNumber(firstChar));
        fontDict.set('LastChar', PdfNumber(lastChar));

        final widthsArray = PdfArray();
        for (int c = firstChar; c <= lastChar; c++) {
          final w = font.metrics.getCharWidth(c);
          widthsArray.add(PdfNumber(w.round()));
        }
        fontDict.set('Widths', widthsArray);

        // Font descriptor object.
        final fontFileObjNum = nextObj++;

        final descDict = PdfDictionary();
        descDict.set('Type', PdfName('FontDescriptor'));
        descDict.set('FontName', PdfName(font.name.replaceAll(' ', '-')));
        descDict.set('Flags', PdfNumber(font.flags));
        descDict.set('FontBBox', PdfArray(
            font.bbox.map((v) => PdfNumber(v)).toList()));
        descDict.set('ItalicAngle', PdfNumber(font.italicAngle));
        descDict.set('Ascent', PdfNumber(font.metrics.ascent));
        descDict.set('Descent', PdfNumber(font.metrics.descent));
        descDict.set('CapHeight', PdfNumber(font.capHeight));
        descDict.set('StemV', PdfNumber(font.stemV));
        descDict.set('FontFile2', PdfReference(fontFileObjNum));

        final descBuf = StringBuffer();
        descDict.writeTo(descBuf);
        builtObjects
            .add(_ObjBytes(descriptorObjNum, descBuf.toString().codeUnits));

        // Font file stream (embedded TrueType data).
        final fontStream = PdfStream(data: font.rawData, compress: true);
        fontStream.dictionary.set('Length1', PdfNumber(font.rawData.length));
        builtObjects.add(_ObjBytes(fontFileObjNum, fontStream.toBytes()));

        // ToUnicode CMap for text selection/copy.
        final toUnicodeObjNum = nextObj++;
        fontDict.set('ToUnicode', PdfReference(toUnicodeObjNum));

        final cmapData = _buildToUnicodeCMap(firstChar, lastChar);
        final cmapStream = PdfStream(
          data: Uint8List.fromList(cmapData.codeUnits),
          compress: true,
        );
        builtObjects
            .add(_ObjBytes(toUnicodeObjNum, cmapStream.toBytes()));

        // Write fontDict (after ToUnicode was added).
        final fontBuf = StringBuffer();
        fontDict.writeTo(fontBuf);
        builtObjects.add(_ObjBytes(fontObjNum, fontBuf.toString().codeUnits));
      }

      fontResourceEntries[PdfName(entry.key)] =
          PdfReference(fontObjNum);
    }

    // Build image objects.
    final imageResourceEntries = <PdfName, PdfObject>{};
    for (final entry in page.graphics.images.entries) {
      final imgObjNum = nextObj++;
      final imgStream = entry.value.toImageStream();
      builtObjects.add(_ObjBytes(imgObjNum, imgStream.toBytes()));
      imageResourceEntries[PdfName(entry.key)] = PdfReference(imgObjNum);
    }

    // Content stream.
    final contentData = page.graphics.contentStream;
    final contentStream = PdfStream(
      data: Uint8List.fromList(contentData.codeUnits),
      compress: true,
    );
    builtObjects.add(_ObjBytes(contentsObjNum, contentStream.toBytes()));

    // Resources dictionary.
    final resourcesDict = PdfDictionary();
    if (fontResourceEntries.isNotEmpty) {
      resourcesDict.set('Font', PdfDictionary(fontResourceEntries));
    }
    if (imageResourceEntries.isNotEmpty) {
      resourcesDict.set('XObject', PdfDictionary(imageResourceEntries));
    }

    // Page dictionary.
    final pageDict = PdfDictionary();
    pageDict.set('Type', PdfName('Page'));
    pageDict.set('Parent', PdfReference(pagesObjNum));
    pageDict.set('MediaBox', PdfArray([
      PdfNumber(0),
      PdfNumber(0),
      PdfNumber.fromDouble(page.width),
      PdfNumber.fromDouble(page.height),
    ]));
    pageDict.set('Contents', PdfReference(contentsObjNum));
    pageDict.set('Resources', resourcesDict);

    final pageBuf = StringBuffer();
    pageDict.writeTo(pageBuf);
    builtObjects.insert(0, _ObjBytes(pageObjNum, pageBuf.toString().codeUnits));

    return _PageBuildData(
      pageObjNum: pageObjNum,
      nextObjNum: nextObj,
      objects: builtObjects,
    );
  }

  String _buildToUnicodeCMap(int firstChar, int lastChar) {
    final buf = StringBuffer();
    buf.writeln('/CIDInit /ProcSet findresource begin');
    buf.writeln('12 dict begin');
    buf.writeln('begincmap');
    buf.writeln('/CIDSystemInfo');
    buf.writeln('<< /Registry (Adobe)');
    buf.writeln('/Ordering (UCS)');
    buf.writeln('/Supplement 0');
    buf.writeln('>> def');
    buf.writeln('/CMapName /Adobe-Identity-UCS def');
    buf.writeln('/CMapType 2 def');
    buf.writeln('1 begincodespacerange');
    buf.writeln('<${firstChar.toRadixString(16).padLeft(2, '0')}> <${lastChar.toRadixString(16).padLeft(2, '0')}>');
    buf.writeln('endcodespacerange');

    // Map each char to its Unicode value.
    final count = lastChar - firstChar + 1;
    const batchSize = 100;
    for (int start = 0; start < count; start += batchSize) {
      final end = (start + batchSize > count) ? count : start + batchSize;
      final n = end - start;
      buf.writeln('$n beginbfchar');
      for (int i = start; i < end; i++) {
        final charCode = firstChar + i;
        final hex = charCode.toRadixString(16).padLeft(2, '0').toUpperCase();
        final unicode =
            charCode.toRadixString(16).padLeft(4, '0').toUpperCase();
        buf.writeln('<$hex> <$unicode>');
      }
      buf.writeln('endbfchar');
    }

    buf.writeln('endcmap');
    buf.writeln('CMapName currentdict /CMap defineresource pop');
    buf.writeln('end');
    buf.writeln('end');
    return buf.toString();
  }

  void _writeString(List<int> output, String s) {
    output.addAll(s.codeUnits);
  }

  void _writeObjBytes(List<int> output, int objNum, List<int> bodyBytes) {
    _writeString(output, '$objNum 0 obj\n');
    output.addAll(bodyBytes);
    _writeString(output, '\nendobj\n');
  }
}

/// Collection of pages in a document.
class PdfPageCollection {
  final List<PdfPage> _pages = [];

  /// Add a new page with optional settings.
  PdfPage add([PdfPageSettings? settings]) {
    final page = PdfPage(settings: settings);
    _pages.add(page);
    return page;
  }

  /// Get a page by index.
  PdfPage operator [](int index) => _pages[index];

  /// Get the page count.
  int get count => _pages.length;

  /// Iterate over pages.
  Iterator<PdfPage> get iterator => _pages.iterator;
}

/// Document metadata.
class PdfDocumentInfo {
  String? title;
  String? author;
  String? subject;
  String? creator;
  String? keywords;
}

class _PageBuildData {
  final int pageObjNum;
  final int nextObjNum;
  final List<_ObjBytes> objects;
  _PageBuildData({
    required this.pageObjNum,
    required this.nextObjNum,
    required this.objects,
  });
}

class _ObjBytes {
  final int objectNumber;
  final List<int> bytes;
  _ObjBytes(this.objectNumber, this.bytes);
}

class _BookmarkBuildData {
  final int objNum;
  final String title;
  final PdfReference pageRef;
  _BookmarkBuildData({
    required this.objNum,
    required this.title,
    required this.pageRef,
  });
}
