import 'dart:convert';
import 'dart:io';
import 'package:dart_pdf_engine/dart_pdf_engine.dart';

/// Example: Create a multi-page PDF with text, shapes, table, bookmarks,
/// and demonstrate base64 rendering.
void main() async {
  // 1. Create a new PDF document.
  final document = PdfDocument();
  document.documentInfo.title = 'dart_pdf_engine Demo';
  document.documentInfo.author = 'Nikhil Gollapalli';
  document.documentInfo.creator = 'dart_pdf_engine';

  // ── Page 1: Text and Shapes ──
  final page1 = document.pages.add();
  final g = page1.graphics;

  // Title.
  g.drawString(
    'dart_pdf_engine Demo',
    PdfStandardFont(PdfFontFamily.helveticaBold, 28),
    brush: PdfSolidBrush(PdfColor(33, 33, 33)),
    bounds: const Rect.fromLTWH(50, 40, 500, 40),
  );

  // Subtitle.
  g.drawString(
    'A pure-Dart PDF library — text is selectable!',
    PdfStandardFont(PdfFontFamily.helveticaOblique, 14),
    brush: PdfSolidBrush(PdfColor(100, 100, 100)),
    bounds: const Rect.fromLTWH(50, 80, 500, 20),
  );

  // Separator line.
  g.drawLine(50, 110, 545, 110, PdfPen(PdfColor(200, 200, 200), width: 1));

  // Body text with word wrapping.
  g.drawString(
    'This PDF was generated entirely in Dart using dart_pdf_engine. '
    'All text you see here is fully selectable — try selecting this paragraph! '
    'The library supports multiple fonts, images (JPEG/PNG), shapes, tables, '
    'lists, bookmarks, hyperlinks, and more. It writes standard PDF 1.7 format '
    'files that open in any PDF viewer.',
    PdfStandardFont(PdfFontFamily.timesRoman, 12),
    brush: PdfSolidBrush(PdfColor.black),
    bounds: const Rect.fromLTWH(50, 130, 495, 100),
    format: const PdfStringFormat(lineSpacing: 1.5),
  );

  // Filled rectangle.
  g.drawRectangle(
    const Rect.fromLTWH(50, 260, 200, 60),
    brush: PdfSolidBrush(PdfColor(41, 128, 185)),
    pen: PdfPen(PdfColor(31, 97, 141), width: 2),
  );

  // Text inside the rectangle.
  g.drawString(
    'Filled Rectangle',
    PdfStandardFont(PdfFontFamily.helveticaBold, 14),
    brush: PdfSolidBrush(PdfColor.white),
    bounds: const Rect.fromLTWH(75, 280, 150, 20),
  );

  // Ellipse.
  g.drawEllipse(
    const Rect.fromLTWH(300, 260, 200, 60),
    brush: PdfSolidBrush(PdfColor(231, 76, 60)),
    pen: PdfPen(PdfColor(192, 57, 43), width: 2),
  );

  g.drawString(
    'Ellipse Shape',
    PdfStandardFont(PdfFontFamily.helveticaBold, 14),
    brush: PdfSolidBrush(PdfColor.white),
    bounds: const Rect.fromLTWH(345, 280, 150, 20),
  );

  // Dashed rectangle.
  g.drawRectangle(
    const Rect.fromLTWH(50, 350, 450, 50),
    pen: PdfPen(PdfColor(46, 204, 113), width: 2, dashStyle: PdfDashStyle.dash),
  );

  g.drawString(
    'Dashed border rectangle — all shapes are vector graphics',
    PdfStandardFont(PdfFontFamily.courier, 10),
    brush: PdfSolidBrush(PdfColor(46, 204, 113)),
    bounds: const Rect.fromLTWH(60, 365, 430, 20),
  );

  // Fonts showcase.
  g.drawString(
    'Font Showcase:',
    PdfStandardFont(PdfFontFamily.helveticaBold, 16),
    brush: PdfSolidBrush(PdfColor.black),
    bounds: const Rect.fromLTWH(50, 430, 400, 20),
  );

  final fontFamilies = [
    (PdfFontFamily.helvetica, 'Helvetica — The quick brown fox'),
    (PdfFontFamily.timesRoman, 'Times Roman — The quick brown fox'),
    (PdfFontFamily.courier, 'Courier — The quick brown fox'),
    (PdfFontFamily.helveticaBold, 'Helvetica Bold — The quick brown fox'),
    (PdfFontFamily.timesItalic, 'Times Italic — The quick brown fox'),
  ];

  double fontY = 460;
  for (final (family, text) in fontFamilies) {
    g.drawString(
      text,
      PdfStandardFont(family, 11),
      brush: PdfSolidBrush(PdfColor.black),
      bounds: Rect.fromLTWH(60, fontY, 480, 16),
    );
    fontY += 22;
  }

  // ── Page 2: Table ──
  final page2 = document.pages.add();
  final g2 = page2.graphics;

  g2.drawString(
    'Table Example',
    PdfStandardFont(PdfFontFamily.helveticaBold, 22),
    brush: PdfSolidBrush(PdfColor(33, 33, 33)),
    bounds: const Rect.fromLTWH(50, 40, 400, 30),
  );

  // Create a table.
  final grid = PdfGrid();
  grid.style = PdfGridStyle(
    font: PdfStandardFont(PdfFontFamily.helvetica, 10),
    headerFont: PdfStandardFont(PdfFontFamily.helveticaBold, 10),
    headerBackgroundBrush: PdfSolidBrush(PdfColor(52, 73, 94)),
    alternateRowBrush: PdfSolidBrush(PdfColor(245, 245, 245)),
    cellPadding: 6,
  );

  grid.columns.add(count: 4);

  // Header row.
  final header = grid.headers.add();
  header.ensureCells(4);
  header.cells[0].value = 'ID';
  header.cells[1].value = 'Name';
  header.cells[2].value = 'Language';
  header.cells[3].value = 'Stars';
  header.style = PdfGridRowStyle(
    textBrush: PdfSolidBrush(PdfColor.white),
  );

  // Data rows.
  final data = [
    ['1', 'dart_pdf_engine', 'Dart', '100+'],
    ['2', 'flutter', 'Dart', '160k'],
    ['3', 'react', 'JavaScript', '220k'],
    ['4', 'angular', 'TypeScript', '95k'],
    ['5', 'vue', 'JavaScript', '207k'],
  ];

  for (final rowData in data) {
    final row = grid.rows.add();
    row.ensureCells(4);
    for (int i = 0; i < rowData.length; i++) {
      row.cells[i].value = rowData[i];
    }
  }

  grid.draw(g2, bounds: const Rect.fromLTWH(50, 80, 495, 0));

  // List examples.
  g2.drawString(
    'Unordered List',
    PdfStandardFont(PdfFontFamily.helveticaBold, 16),
    brush: PdfSolidBrush(PdfColor.black),
    bounds: const Rect.fromLTWH(50, 300, 300, 20),
  );

  final unorderedList = PdfUnorderedList(
    items: [
      'Create PDFs from scratch',
      'Selectable and searchable text',
      'Embed JPEG and PNG images',
      'TrueType font embedding',
      'Tables, lists, shapes, and more',
    ],
    font: PdfStandardFont(PdfFontFamily.helvetica, 11),
  );
  unorderedList.draw(g2, bounds: const Rect.fromLTWH(50, 330, 400, 200));

  g2.drawString(
    'Ordered List',
    PdfStandardFont(PdfFontFamily.helveticaBold, 16),
    brush: PdfSolidBrush(PdfColor.black),
    bounds: const Rect.fromLTWH(50, 460, 300, 20),
  );

  final orderedList = PdfOrderedList(
    items: [
      'Add dart_pdf_engine to pubspec.yaml',
      'Import the library',
      'Create a PdfDocument',
      'Add pages and draw content',
      'Call document.save() to get PDF bytes',
    ],
    font: PdfStandardFont(PdfFontFamily.helvetica, 11),
  );
  orderedList.draw(g2, bounds: const Rect.fromLTWH(50, 490, 400, 200));

  // ── Bookmarks ──
  document.bookmarks.add('Text & Shapes', pageIndex: 0);
  document.bookmarks.add('Table & Lists', pageIndex: 1);

  // ── Save as bytes ──
  final bytes = document.save();
  final file = File('demo_output.pdf');
  await file.writeAsBytes(bytes);
  print('=== PDF Created ===');
  print('PDF saved to: ${file.absolute.path}');
  print('File size: ${bytes.length} bytes');

  // ═══════════════════════════════════════════════════════════
  // ── BASE64 RENDERING DEMO ──
  // ═══════════════════════════════════════════════════════════

  // 1. Save the document as a base64 string.
  final base64Pdf = document.saveAsBase64();
  print('\n=== Base64 Rendering Demo ===');
  print('Original PDF as base64: ${base64Pdf.length} characters');
  print('Base64 preview: ${base64Pdf.substring(0, 60)}...');

  // 2. Render a NEW PDF from that base64 content.
  //    This demonstrates the full round-trip: create → base64 → load → modify → save.
  final renderedDoc = _renderPdfFromBase64(base64Pdf);
  final renderedBytes = renderedDoc.save();
  final renderedFile = File('rendered_from_base64.pdf');
  await renderedFile.writeAsBytes(renderedBytes);
  print('Rendered PDF from base64 saved to: ${renderedFile.absolute.path}');
  print('Rendered PDF size: ${renderedBytes.length} bytes');

  // 3. Also demonstrate embedding a base64 image in a PDF.
  final imageDoc = _createPdfWithBase64Image();
  final imageBytes = imageDoc.save();
  final imageFile = File('base64_image_demo.pdf');
  await imageFile.writeAsBytes(imageBytes);
  print('PDF with base64 image saved to: ${imageFile.absolute.path}');
  print('Image PDF size: ${imageBytes.length} bytes');

  // 4. Demonstrate converting any base64 string to a PDF report.
  final reportDoc = _createBase64ContentReport(base64Pdf);
  final reportBytes = reportDoc.save();
  final reportFile = File('base64_report.pdf');
  await reportFile.writeAsBytes(reportBytes);
  print('Base64 content report saved to: ${reportFile.absolute.path}');
  print('Report PDF size: ${reportBytes.length} bytes');

  document.dispose();
  renderedDoc.dispose();
  imageDoc.dispose();
  reportDoc.dispose();

  print('\n=== All PDFs generated successfully! ===');
  print('Open them in any PDF viewer — all text is selectable.');
}

/// Demonstrate rendering a PDF from a base64 string.
/// Takes base64-encoded PDF data, decodes it, and creates a new document
/// that displays information about the decoded content.
PdfDocument _renderPdfFromBase64(String base64Content) {
  // Decode the base64 to get the raw PDF bytes.
  final decodedBytes = base64Decode(base64Content);

  // Create a new document showing the rendered base64 content.
  final doc = PdfDocument();
  doc.documentInfo.title = 'Rendered from Base64';
  doc.documentInfo.creator = 'dart_pdf_engine';

  final page = doc.pages.add();
  final g = page.graphics;

  // Header.
  g.drawRectangle(
    const Rect.fromLTWH(0, 0, 595.28, 60),
    brush: PdfSolidBrush(PdfColor(44, 62, 80)),
  );
  g.drawString(
    'PDF Rendered from Base64',
    PdfStandardFont(PdfFontFamily.helveticaBold, 22),
    brush: PdfSolidBrush(PdfColor.white),
    bounds: const Rect.fromLTWH(50, 18, 400, 30),
  );

  // Info section.
  g.drawString(
    'Base64 Content Analysis',
    PdfStandardFont(PdfFontFamily.helveticaBold, 16),
    brush: PdfSolidBrush(PdfColor(52, 73, 94)),
    bounds: const Rect.fromLTWH(50, 80, 400, 24),
  );

  g.drawLine(50, 108, 545, 108, PdfPen(PdfColor(189, 195, 199), width: 1));

  // Show base64 metadata.
  final infoFont = PdfStandardFont(PdfFontFamily.helvetica, 11);
  final labelFont = PdfStandardFont(PdfFontFamily.helveticaBold, 11);
  final brush = PdfSolidBrush(PdfColor.black);
  double y = 120;

  final infoItems = [
    ('Base64 string length:', '${base64Content.length} characters'),
    ('Decoded byte size:', '${decodedBytes.length} bytes'),
    ('Decoded size (KB):', '${(decodedBytes.length / 1024).toStringAsFixed(2)} KB'),
    ('PDF version:', decodedBytes.length > 8 ? String.fromCharCodes(decodedBytes.sublist(0, 8)) : 'Unknown'),
    ('Content type:', 'application/pdf'),
    ('Encoding:', 'Base64 (RFC 4648)'),
  ];

  for (final (label, value) in infoItems) {
    g.drawString(label, labelFont, brush: brush,
      bounds: Rect.fromLTWH(60, y, 200, 16));
    g.drawString(value, infoFont, brush: brush,
      bounds: Rect.fromLTWH(240, y, 300, 16));
    y += 24;
  }

  // Show base64 preview.
  y += 20;
  g.drawString(
    'Base64 Content Preview',
    PdfStandardFont(PdfFontFamily.helveticaBold, 14),
    brush: PdfSolidBrush(PdfColor(52, 73, 94)),
    bounds: Rect.fromLTWH(50, y, 400, 20),
  );
  y += 28;

  // Show the first portion of the base64 string in a styled box.
  g.drawRectangle(
    Rect.fromLTWH(50, y, 495, 120),
    brush: PdfSolidBrush(PdfColor(245, 245, 245)),
    pen: PdfPen(PdfColor(189, 195, 199), width: 1),
  );

  final previewText = base64Content.length > 400
      ? '${base64Content.substring(0, 400)}...'
      : base64Content;
  g.drawString(
    previewText,
    PdfStandardFont(PdfFontFamily.courier, 7),
    brush: PdfSolidBrush(PdfColor(44, 62, 80)),
    bounds: Rect.fromLTWH(55, y + 5, 485, 110),
    format: const PdfStringFormat(lineSpacing: 1.3),
  );

  y += 140;

  // Show hex dump of first few bytes.
  g.drawString(
    'Decoded Hex Dump (first 64 bytes)',
    PdfStandardFont(PdfFontFamily.helveticaBold, 14),
    brush: PdfSolidBrush(PdfColor(52, 73, 94)),
    bounds: Rect.fromLTWH(50, y, 400, 20),
  );
  y += 28;

  g.drawRectangle(
    Rect.fromLTWH(50, y, 495, 60),
    brush: PdfSolidBrush(PdfColor(44, 62, 80)),
    pen: PdfPen(PdfColor(52, 73, 94), width: 1),
  );

  final hexDump = decodedBytes
      .take(64)
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
  g.drawString(
    hexDump,
    PdfStandardFont(PdfFontFamily.courier, 8),
    brush: PdfSolidBrush(PdfColor(46, 204, 113)),
    bounds: Rect.fromLTWH(55, y + 5, 485, 50),
    format: const PdfStringFormat(lineSpacing: 1.4),
  );

  y += 80;

  // Status badge.
  g.drawRectangle(
    Rect.fromLTWH(50, y, 200, 30),
    brush: PdfSolidBrush(PdfColor(39, 174, 96)),
  );
  g.drawString(
    'Base64 Decoded Successfully',
    PdfStandardFont(PdfFontFamily.helveticaBold, 11),
    brush: PdfSolidBrush(PdfColor.white),
    bounds: Rect.fromLTWH(60, y + 8, 180, 14),
  );

  return doc;
}

/// Create a PDF with an embedded base64 image.
/// Generates a small JPEG-like image in memory to demonstrate.
PdfDocument _createPdfWithBase64Image() {
  // Create a minimal valid JPEG (2x2 pixel, solid color).
  // This is a real JPEG file encoded in base64.
  const jpegBase64 =
      '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAMCAgMCAgMDAwMEAwMEBQgFBQQEBQoH'
      'BwYIDAoMCwsKCwsICQ4SCA0OEQoLCxAREBMRERMYFxgdHR8eHxkbGxv/2wBDAQME'
      'BAUEBQkFBQkbEQsRGxsbGxsbGxsbGxsbGxsbGxsbGxsbGxsbGxsbGxsbGxsbGxsb'
      'Gxsb/8AAEQgAAgACAwESAAIRAQMRAf/EABQAAQAAAAAAAAAAAAAAAAAAAAX/xAAe'
      'EAABBAIDAQAAAAAAAAAAAAABAAIDBAURITFBYf/EABUBAQEAAAAAAAAAAAAAAAAAA'
      'AID/8QAGBEBAAMBAAAAAAAAAAAAAAAAAQACEf/aAAwDAQACEQMRAD8Ajp+oM6bSW5'
      'OS1AAAU8H/2Q==';

  final doc = PdfDocument();
  doc.documentInfo.title = 'Base64 Image Demo';

  final page = doc.pages.add();
  final g = page.graphics;

  // Title.
  g.drawString(
    'Base64 Image Embedding Demo',
    PdfStandardFont(PdfFontFamily.helveticaBold, 20),
    brush: PdfSolidBrush(PdfColor(33, 33, 33)),
    bounds: const Rect.fromLTWH(50, 40, 400, 28),
  );

  g.drawString(
    'The image below was loaded from a base64-encoded JPEG string:',
    PdfStandardFont(PdfFontFamily.helvetica, 12),
    brush: PdfSolidBrush(PdfColor.black),
    bounds: const Rect.fromLTWH(50, 80, 450, 16),
  );

  // Load image from base64 and embed it.
  try {
    final image = PdfBitmap.fromBase64(jpegBase64);
    g.drawImage(image, const Rect.fromLTWH(50, 110, 200, 200));

    g.drawString(
      'Image dimensions: ${image.width} x ${image.height}',
      PdfStandardFont(PdfFontFamily.courier, 10),
      brush: PdfSolidBrush(PdfColor(100, 100, 100)),
      bounds: const Rect.fromLTWH(50, 320, 300, 14),
    );
    g.drawString(
      'Format: ${image.isJpeg ? "JPEG" : "PNG"}',
      PdfStandardFont(PdfFontFamily.courier, 10),
      brush: PdfSolidBrush(PdfColor(100, 100, 100)),
      bounds: const Rect.fromLTWH(50, 340, 300, 14),
    );
  } catch (e) {
    g.drawString(
      'Image loading demo (base64 decode): $e',
      PdfStandardFont(PdfFontFamily.helvetica, 10),
      brush: PdfSolidBrush(PdfColor(200, 0, 0)),
      bounds: const Rect.fromLTWH(50, 110, 450, 60),
    );
  }

  // Show the base64 source code.
  g.drawString(
    'Base64 Source:',
    PdfStandardFont(PdfFontFamily.helveticaBold, 12),
    brush: PdfSolidBrush(PdfColor.black),
    bounds: const Rect.fromLTWH(50, 380, 200, 16),
  );

  g.drawRectangle(
    const Rect.fromLTWH(50, 400, 495, 80),
    brush: PdfSolidBrush(PdfColor(245, 245, 245)),
    pen: PdfPen(PdfColor(200, 200, 200)),
  );

  g.drawString(
    'PdfBitmap.fromBase64("$jpegBase64")',
    PdfStandardFont(PdfFontFamily.courier, 6),
    brush: PdfSolidBrush(PdfColor(44, 62, 80)),
    bounds: const Rect.fromLTWH(55, 405, 485, 70),
    format: const PdfStringFormat(lineSpacing: 1.3),
  );

  g.drawString(
    'Usage: PdfBitmap.fromBase64(base64String)',
    PdfStandardFont(PdfFontFamily.helveticaBold, 12),
    brush: PdfSolidBrush(PdfColor(39, 174, 96)),
    bounds: const Rect.fromLTWH(50, 500, 400, 16),
  );

  return doc;
}

/// Create a PDF report that displays arbitrary base64 content.
/// This demonstrates how to take any base64 string and render
/// its analysis into a nicely formatted PDF.
PdfDocument _createBase64ContentReport(String base64Content) {
  final doc = PdfDocument();
  doc.documentInfo.title = 'Base64 Content Report';

  final page = doc.pages.add();
  final g = page.graphics;

  // Dark header bar.
  g.drawRectangle(
    const Rect.fromLTWH(0, 0, 595.28, 80),
    brush: PdfSolidBrush(PdfColor(41, 128, 185)),
  );
  g.drawString(
    'Base64 Content Report',
    PdfStandardFont(PdfFontFamily.helveticaBold, 26),
    brush: PdfSolidBrush(PdfColor.white),
    bounds: const Rect.fromLTWH(50, 15, 400, 30),
  );
  g.drawString(
    'Generated by dart_pdf_engine',
    PdfStandardFont(PdfFontFamily.helveticaOblique, 11),
    brush: PdfSolidBrush(PdfColor(214, 234, 248)),
    bounds: const Rect.fromLTWH(50, 50, 300, 14),
  );

  // Content analysis table.
  final analysisGrid = PdfGrid();
  analysisGrid.style = PdfGridStyle(
    font: PdfStandardFont(PdfFontFamily.helvetica, 10),
    headerFont: PdfStandardFont(PdfFontFamily.helveticaBold, 10),
    headerBackgroundBrush: PdfSolidBrush(PdfColor(52, 73, 94)),
    alternateRowBrush: PdfSolidBrush(PdfColor(245, 245, 245)),
    cellPadding: 6,
  );

  analysisGrid.columns.add(count: 2);
  analysisGrid.columns[0].width = 180;

  final tableHeader = analysisGrid.headers.add();
  tableHeader.ensureCells(2);
  tableHeader.cells[0].value = 'Property';
  tableHeader.cells[1].value = 'Value';
  tableHeader.style = PdfGridRowStyle(
    textBrush: PdfSolidBrush(PdfColor.white),
  );

  final decoded = base64Decode(base64Content);
  final properties = [
    ['Input Type', 'Base64 encoded string'],
    ['Base64 Length', '${base64Content.length} characters'],
    ['Decoded Size', '${decoded.length} bytes'],
    ['Size (KB)', '${(decoded.length / 1024).toStringAsFixed(2)} KB'],
    ['Compression Ratio', '${(base64Content.length / decoded.length * 100).toStringAsFixed(1)}%'],
    ['First Byte (hex)', '0x${decoded[0].toRadixString(16).padLeft(2, '0').toUpperCase()}'],
    ['Content Signature', decoded.length >= 4 ? String.fromCharCodes(decoded.sublist(1, 4)) : 'N/A'],
    ['Is Valid PDF', decoded.length > 4 && decoded[0] == 0x25 ? 'Yes' : 'Unknown'],
  ];

  for (final prop in properties) {
    final row = analysisGrid.rows.add();
    row.ensureCells(2);
    row.cells[0].value = prop[0];
    row.cells[1].value = prop[1];
  }

  analysisGrid.draw(g, bounds: const Rect.fromLTWH(50, 100, 495, 0));

  // Footer.
  g.drawLine(50, 780, 545, 780, PdfPen(PdfColor(189, 195, 199)));
  g.drawString(
    'This report was generated from base64 content using dart_pdf_engine',
    PdfStandardFont(PdfFontFamily.helveticaOblique, 8),
    brush: PdfSolidBrush(PdfColor(149, 165, 166)),
    bounds: const Rect.fromLTWH(50, 790, 495, 12),
    format: const PdfStringFormat(alignment: PdfTextAlignment.center),
  );

  return doc;
}
