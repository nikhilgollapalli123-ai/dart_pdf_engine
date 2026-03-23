import 'dart:io';
import 'package:dart_pdf_engine/dart_pdf_engine.dart';

/// Renders a PDF from base64 data using dart_pdf_engine.
///
/// Usage:
///   dart run render_base64.dart
///
/// Reads the base64 file, parses it with PdfDocument.fromBase64(),
/// and saves the rendered PDF that you can open in any viewer.
void main() async {
  // ── Read the base64 data ──
  final base64File = File('JVBERi0xLjcKJcOkw7zDtsOfCjIgMCBvYmoKPDwv.pl');
  if (!base64File.existsSync()) {
    print('❌ Base64 file not found!');
    return;
  }

  final base64String = base64File.readAsStringSync().trim();
  print('📄 Reading base64 data: ${base64String.length} characters');

  // ── Parse the PDF using dart_pdf_engine ──
  final document = PdfDocument.fromBase64(base64String);

  print('\n═══════════════════════════════════════');
  print('  PARSED PDF INFORMATION');
  print('═══════════════════════════════════════');
  print('  Title:    ${document.documentInfo.title ?? "N/A"}');
  print('  Author:   ${document.documentInfo.author ?? "N/A"}');
  print('  Creator:  ${document.documentInfo.creator ?? "N/A"}');
  print('  Pages:    ${document.pages.count}');
  print('  Bookmarks: ${document.bookmarks.bookmarks.length}');
  print('  Loaded from bytes: ${document.isLoaded}');

  if (document.pages.count > 0) {
    for (int i = 0; i < document.pages.count; i++) {
      final page = document.pages[i];
      print('  Page ${i + 1}: ${page.width} x ${page.height} points');
    }
  }

  if (document.bookmarks.bookmarks.isNotEmpty) {
    print('\n  Bookmarks:');
    for (final bm in document.bookmarks.bookmarks) {
      print('    • ${bm.title} (page ${bm.pageIndex + 1})');
    }
  }

  // ── Save the PDF — this displays it! ──
  final outputBytes = document.save();
  final outputFile = File('output.pdf');
  await outputFile.writeAsBytes(outputBytes);

  print('\n═══════════════════════════════════════');
  print('  ✅ PDF RENDERED SUCCESSFULLY');
  print('═══════════════════════════════════════');
  print('  Output: ${outputFile.absolute.path}');
  print('  Size:   ${outputBytes.length} bytes');
  print('\n  Open output.pdf in any PDF viewer to see the result!');

  document.dispose();
}
