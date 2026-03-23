// dart_pdf_engine viewer example — demonstrates both programmatic and preview modes.

import 'package:flutter/material.dart';
import 'package:dart_pdf_engine/dart_pdf_engine_viewer.dart';

/// Example Flutter app demonstrating both modes of dart_pdf_engine:
///
/// **Mode 1 — Programmatic (existing):**
///   Create PDFs in code with text, shapes, tables, etc.
///   Get bytes via `document.save()` or base64 via `document.saveAsBase64()`.
///
/// **Mode 2 — Direct Preview (new):**
///   Use `PdfViewer` widget to display PDFs directly in your Flutter app.
///   Supports loading from `PdfDocument`, bytes, or base64.
void main() {
  runApp(const PdfViewerExampleApp());
}

class PdfViewerExampleApp extends StatelessWidget {
  const PdfViewerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'dart_pdf_engine Viewer Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1976D2),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const ViewerDemoPage(),
    );
  }
}

class ViewerDemoPage extends StatefulWidget {
  const ViewerDemoPage({super.key});

  @override
  State<ViewerDemoPage> createState() => _ViewerDemoPageState();
}

class _ViewerDemoPageState extends State<ViewerDemoPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PdfViewerController _programmaticController;
  PdfViewerController? _base64Controller;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _programmaticController = _createProgrammaticPdf();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _programmaticController.dispose();
    _base64Controller?.dispose();
    super.dispose();
  }

  /// Create a PDF programmatically and wrap it in a controller for preview.
  PdfViewerController _createProgrammaticPdf() {
    final doc = PdfDocument();
    doc.documentInfo.title = 'Viewer Demo';
    doc.documentInfo.author = 'dart_pdf_engine';

    // ── Page 1: Title and text ──
    final page1 = doc.pages.add();
    final g = page1.graphics;

    // Header bar.
    g.drawRectangle(
      const Rect.fromLTWH(0, 0, 595.28, 70),
      brush: PdfSolidBrush(PdfColor(25, 118, 210)),
    );
    g.drawString(
      'dart_pdf_engine — Viewer Demo',
      PdfStandardFont(PdfFontFamily.helveticaBold, 24),
      brush: PdfSolidBrush(PdfColor.white),
      bounds: const Rect.fromLTWH(40, 20, 500, 30),
    );

    // Body text.
    g.drawString(
      'This PDF was created programmatically using dart_pdf_engine '
      'and is being previewed directly in your Flutter app using '
      'the PdfViewer widget. All text you see here is rendered '
      'from the PDF content stream to the Flutter Canvas in real-time.',
      PdfStandardFont(PdfFontFamily.helvetica, 12),
      brush: PdfSolidBrush(PdfColor.black),
      bounds: const Rect.fromLTWH(40, 90, 515, 100),
      format: const PdfStringFormat(lineSpacing: 1.5),
    );

    // Shapes demo.
    g.drawRectangle(
      const Rect.fromLTWH(40, 220, 200, 60),
      brush: PdfSolidBrush(PdfColor(41, 128, 185)),
      pen: PdfPen(PdfColor(31, 97, 141), width: 2),
    );
    g.drawString(
      'Rectangle Shape',
      PdfStandardFont(PdfFontFamily.helveticaBold, 14),
      brush: PdfSolidBrush(PdfColor.white),
      bounds: const Rect.fromLTWH(65, 240, 150, 20),
    );

    g.drawEllipse(
      const Rect.fromLTWH(280, 220, 200, 60),
      brush: PdfSolidBrush(PdfColor(231, 76, 60)),
      pen: PdfPen(PdfColor(192, 57, 43), width: 2),
    );
    g.drawString(
      'Ellipse Shape',
      PdfStandardFont(PdfFontFamily.helveticaBold, 14),
      brush: PdfSolidBrush(PdfColor.white),
      bounds: const Rect.fromLTWH(325, 240, 150, 20),
    );

    // Line.
    g.drawLine(
      40, 310, 555, 310,
      PdfPen(PdfColor(200, 200, 200), width: 1),
    );

    // Font showcase.
    g.drawString(
      'Font Showcase:',
      PdfStandardFont(PdfFontFamily.helveticaBold, 16),
      brush: PdfSolidBrush(PdfColor.black),
      bounds: const Rect.fromLTWH(40, 330, 400, 20),
    );

    final fontFamilies = [
      (PdfFontFamily.helvetica, 'Helvetica — The quick brown fox'),
      (PdfFontFamily.timesRoman, 'Times Roman — The quick brown fox'),
      (PdfFontFamily.courier, 'Courier — The quick brown fox'),
      (PdfFontFamily.helveticaBold, 'Helvetica Bold — The quick brown fox'),
    ];

    double fontY = 360;
    for (final (family, text) in fontFamilies) {
      g.drawString(
        text,
        PdfStandardFont(family, 11),
        brush: PdfSolidBrush(PdfColor.black),
        bounds: Rect.fromLTWH(50, fontY, 480, 16),
      );
      fontY += 22;
    }

    // ── Page 2: Table ──
    final page2 = doc.pages.add();
    final g2 = page2.graphics;

    g2.drawRectangle(
      const Rect.fromLTWH(0, 0, 595.28, 70),
      brush: PdfSolidBrush(PdfColor(56, 142, 60)),
    );
    g2.drawString(
      'Page 2 — Table Demo',
      PdfStandardFont(PdfFontFamily.helveticaBold, 24),
      brush: PdfSolidBrush(PdfColor.white),
      bounds: const Rect.fromLTWH(40, 20, 500, 30),
    );

    // Create a simple table.
    final grid = PdfGrid();
    grid.style = PdfGridStyle(
      font: PdfStandardFont(PdfFontFamily.helvetica, 10),
      headerFont: PdfStandardFont(PdfFontFamily.helveticaBold, 10),
      headerBackgroundBrush: PdfSolidBrush(PdfColor(52, 73, 94)),
      alternateRowBrush: PdfSolidBrush(PdfColor(245, 245, 245)),
      cellPadding: 6,
    );

    grid.columns.add(count: 3);
    final header = grid.headers.add();
    header.ensureCells(3);
    header.cells[0].value = 'Feature';
    header.cells[1].value = 'Supported';
    header.cells[2].value = 'Notes';
    header.style = PdfGridRowStyle(
      textBrush: PdfSolidBrush(PdfColor.white),
    );

    final features = [
      ['Text (selectable)', 'Yes', 'BT/ET operators'],
      ['Shapes', 'Yes', 'Rect, ellipse, path'],
      ['Images', 'Yes', 'JPEG/PNG'],
      ['Tables', 'Yes', 'PdfGrid widget'],
      ['Fonts', 'Yes', 'Standard + TrueType'],
      ['Bookmarks', 'Yes', 'Outline tree'],
      ['In-app Preview', 'Yes', 'PdfViewer widget'],
    ];

    for (final row in features) {
      final r = grid.rows.add();
      r.ensureCells(3);
      for (int i = 0; i < row.length; i++) {
        r.cells[i].value = row[i];
      }
    }

    grid.draw(g2, bounds: const Rect.fromLTWH(40, 90, 515, 0));

    // Bookmarks.
    doc.bookmarks.add('Title & Shapes', pageIndex: 0);
    doc.bookmarks.add('Table Demo', pageIndex: 1);

    return PdfViewerController.fromDocument(doc);
  }

  /// Load a PDF from the first document's base64 representation.
  void _loadFromBase64() {
    final base64Pdf = _programmaticController.document.saveAsBase64();
    setState(() {
      _base64Controller?.dispose();
      _base64Controller = PdfViewerController.fromBase64(base64Pdf);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('dart_pdf_engine Viewer'),
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.code),
              text: 'Programmatic',
            ),
            Tab(
              icon: Icon(Icons.visibility),
              text: 'From Base64',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Programmatic PDF preview.
          PdfViewer(
            controller: _programmaticController,
            showNavigationControls: true,
            showPageIndicator: true,
            enableZoom: true,
            continuousScroll: true,
          ),

          // Tab 2: Load from Base64 preview.
          _base64Controller != null
              ? PdfViewer(
                  controller: _base64Controller!,
                  showNavigationControls: true,
                  showPageIndicator: true,
                  continuousScroll: false,
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.upload_file,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Load a PDF from Base64',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _loadFromBase64,
                        icon: const Icon(Icons.transform),
                        label: const Text('Convert & Preview'),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}
