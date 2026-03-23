import 'dart:convert';
import 'dart:typed_data';

import '../pdf_document.dart';

/// Controller for loading and managing PDF documents in the viewer.
///
/// Supports loading from multiple sources: [PdfDocument], raw bytes,
/// base64-encoded strings, or file paths.
///
/// Example:
/// ```dart
/// // From a programmatically created document:
/// final doc = PdfDocument();
/// doc.pages.add().graphics.drawString(...);
/// final controller = PdfViewerController.fromDocument(doc);
///
/// // From base64:
/// final controller = PdfViewerController.fromBase64(base64String);
///
/// // From bytes:
/// final controller = PdfViewerController.fromBytes(pdfBytes);
/// ```
class PdfViewerController {
  /// The underlying PDF document.
  final PdfDocument document;

  /// The raw PDF bytes for rendering.
  late final Uint8List pdfBytes;

  /// Current page index (0-based).
  int _currentPage = 0;

  /// Optional callback when the page changes.
  void Function(int pageIndex)? onPageChanged;

  /// Create a controller from a [PdfDocument].
  ///
  /// For documents created programmatically, this calls [PdfDocument.save]
  /// to generate the PDF bytes used for preview.
  PdfViewerController.fromDocument(this.document) {
    pdfBytes = Uint8List.fromList(document.save());
  }

  /// Create a controller from raw PDF bytes.
  ///
  /// Parses the bytes into a [PdfDocument] for metadata and page info,
  /// while keeping the raw bytes for rendering.
  PdfViewerController.fromBytes(Uint8List bytes)
      : document = PdfDocument.fromBytes(bytes) {
    pdfBytes = bytes;
  }

  /// Create a controller from a base64-encoded PDF string.
  PdfViewerController.fromBase64(String base64Data)
      : document = PdfDocument.fromBase64(base64Data) {
    pdfBytes = Uint8List.fromList(base64Decode(base64Data));
  }

  /// Total number of pages.
  int get pageCount => document.pages.count;

  /// Current page index (0-based).
  int get currentPage => _currentPage;

  /// Set the current page.
  set currentPage(int index) {
    if (index >= 0 && index < pageCount) {
      _currentPage = index;
      onPageChanged?.call(index);
    }
  }

  /// Go to the next page.
  void nextPage() {
    if (_currentPage < pageCount - 1) {
      currentPage = _currentPage + 1;
    }
  }

  /// Go to the previous page.
  void previousPage() {
    if (_currentPage > 0) {
      currentPage = _currentPage - 1;
    }
  }

  /// Go to the first page.
  void firstPage() {
    currentPage = 0;
  }

  /// Go to the last page.
  void lastPage() {
    currentPage = pageCount - 1;
  }

  /// Get page width for a specific page index.
  double getPageWidth(int index) {
    if (index >= 0 && index < pageCount) {
      return document.pages[index].width;
    }
    return 612; // default US Letter width
  }

  /// Get page height for a specific page index.
  double getPageHeight(int index) {
    if (index >= 0 && index < pageCount) {
      return document.pages[index].height;
    }
    return 792; // default US Letter height
  }

  /// Dispose resources.
  void dispose() {
    document.dispose();
  }
}
