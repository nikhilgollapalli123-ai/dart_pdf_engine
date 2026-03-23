/// dart_pdf_engine viewer — Flutter widgets for displaying PDF documents.
///
/// Import this library to use the [PdfViewer] widget and related
/// components for directly previewing PDFs in your Flutter app.
///
/// This re-exports the core library, so you only need one import:
/// ```dart
/// import 'package:dart_pdf_engine/dart_pdf_engine_viewer.dart';
/// ```
///
/// ## Quick Start
///
/// ### Preview a programmatically created PDF:
/// ```dart
/// final doc = PdfDocument();
/// doc.pages.add().graphics.drawString(
///   'Hello World!',
///   PdfStandardFont(PdfFontFamily.helvetica, 20),
///   brush: PdfSolidBrush(PdfColor.black),
///   bounds: Rect.fromLTWH(50, 50, 200, 30),
/// );
///
/// PdfViewer(
///   controller: PdfViewerController.fromDocument(doc),
/// )
/// ```
///
/// ### Preview a PDF from base64:
/// ```dart
/// PdfViewer(
///   controller: PdfViewerController.fromBase64(base64PdfString),
/// )
/// ```
library dart_pdf_engine_viewer;

// Re-export core library.
export 'dart_pdf_engine.dart';

// Viewer widgets.
export 'src/viewer/pdf_viewer.dart';
export 'src/viewer/pdf_viewer_controller.dart';
export 'src/viewer/pdf_page_view.dart';
export 'src/viewer/pdf_page_renderer.dart';
