# dart_pdf_engine

A **pure-Dart** library for creating, reading, and manipulating PDF documents programmatically. No native dependencies — works on all Flutter platforms (Android, iOS, Web, Desktop).

[![pub package](https://img.shields.io/pub/v/dart_pdf_engine.svg)](https://pub.dev/packages/dart_pdf_engine)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

## Features

- ✅ **Create PDF documents** from scratch with PDF 1.7 compliance
- ✅ **Selectable & searchable text** — all text uses proper PDF text operators
- ✅ **14 standard PDF fonts** — Helvetica, Times, Courier, Symbol, ZapfDingbats
- ✅ **TrueType font embedding** with Unicode support and ToUnicode CMap
- ✅ **JPEG & PNG images** — embed from bytes or base64 strings
- ✅ **Shapes** — lines, rectangles, ellipses, Bezier paths with fill/stroke
- ✅ **Tables** — `PdfGrid` with headers, cell styling, borders, alternating rows
- ✅ **Lists** — ordered and unordered with customizable markers
- ✅ **Bookmarks** — document outline for navigation
- ✅ **Multi-page** — standard sizes (A4, Letter, Legal, A3, A5, etc.)
- ✅ **Base64 support** — load from base64, save as base64
- ✅ **PDF Parsing** — load existing PDFs from bytes or base64, extract pages, metadata, bookmarks
- ✅ **Word wrapping** — automatic text wrapping within bounds
- ✅ **Text alignment** — left, center, right

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dart_pdf_engine: ^1.1.0
```

## Quick Start

```dart
import 'dart:io';
import 'package:dart_pdf_engine/dart_pdf_engine.dart';

void main() async {
  // Create a document.
  final document = PdfDocument();

  // Add a page and draw text.
  document.pages.add().graphics.drawString(
    'Hello World!',
    PdfStandardFont(PdfFontFamily.helvetica, 24),
    brush: PdfSolidBrush(PdfColor(0, 0, 0)),
    bounds: const Rect.fromLTWH(50, 50, 400, 40),
  );

  // Save to file.
  File('hello.pdf').writeAsBytesSync(document.save());
  document.dispose();
}
```

## Load & Display PDF from Base64

```dart
import 'dart:io';
import 'package:dart_pdf_engine/dart_pdf_engine.dart';

void main() async {
  // Your base64-encoded PDF string.
  final base64Pdf = '...';

  // Parse the PDF from base64.
  final document = PdfDocument.fromBase64(base64Pdf);

  // Inspect parsed data.
  print('Pages: ${document.pages.count}');
  print('Title: ${document.documentInfo.title}');
  print('Author: ${document.documentInfo.author}');
  print('Bookmarks: ${document.bookmarks.bookmarks.length}');

  // Save as a viewable PDF file.
  File('output.pdf').writeAsBytesSync(document.save());
  document.dispose();
}
```

You can also load from raw bytes:

```dart
final bytes = File('input.pdf').readAsBytesSync();
final document = PdfDocument.fromBytes(bytes);
print('Loaded ${document.pages.count} pages');
```

## Usage Examples

### Text with Word Wrapping

```dart
page.graphics.drawString(
  'This is a long paragraph that will automatically wrap...',
  PdfStandardFont(PdfFontFamily.timesRoman, 12),
  brush: PdfSolidBrush(PdfColor.black),
  bounds: const Rect.fromLTWH(50, 100, 400, 200),
  format: const PdfStringFormat(lineSpacing: 1.5),
);
```

### Images (from file or base64)

```dart
// From file bytes:
final imageData = File('photo.jpg').readAsBytesSync();
final image = PdfBitmap(imageData);

// Or from base64:
final image = PdfBitmap.fromBase64(base64String);

page.graphics.drawImage(image, const Rect.fromLTWH(50, 300, 200, 150));
```

### Tables

```dart
final grid = PdfGrid();
grid.columns.add(count: 3);

final header = grid.headers.add();
header.ensureCells(3);
header.cells[0].value = 'Name';
header.cells[1].value = 'Age';
header.cells[2].value = 'City';

final row = grid.rows.add();
row.ensureCells(3);
row.cells[0].value = 'Alice';
row.cells[1].value = '30';
row.cells[2].value = 'New York';

grid.draw(page.graphics, bounds: const Rect.fromLTWH(50, 100, 500, 0));
```

### Shapes

```dart
// Filled rectangle.
page.graphics.drawRectangle(
  const Rect.fromLTWH(50, 200, 150, 80),
  brush: PdfSolidBrush(PdfColor(41, 128, 185)),
  pen: PdfPen(PdfColor(31, 97, 141), width: 2),
);

// Ellipse.
page.graphics.drawEllipse(
  const Rect.fromLTWH(250, 200, 150, 80),
  brush: PdfSolidBrush(PdfColor(231, 76, 60)),
);

// Dashed line.
page.graphics.drawLine(50, 300, 500, 300,
  PdfPen(PdfColor.gray, width: 1, dashStyle: PdfDashStyle.dash),
);
```

### Bookmarks

```dart
document.bookmarks.add('Chapter 1', pageIndex: 0);
document.bookmarks.add('Chapter 2', pageIndex: 1);
```

### Base64 Output

```dart
final base64Pdf = document.saveAsBase64();
// Use in web, API responses, etc.
```

## API Overview

| Class | Purpose |
|-------|---------|
| `PdfDocument` | Main document — create, save, dispose |
| `PdfPage` | Single page with size/orientation |
| `PdfGraphics` | Canvas API — drawString, drawImage, drawRectangle, etc. |
| `PdfStandardFont` | 14 built-in PDF fonts |
| `PdfTrueTypeFont` | Embed custom TTF fonts |
| `PdfBitmap` | JPEG/PNG image embedding |
| `PdfGrid` | Table with headers, rows, styling |
| `PdfOrderedList` / `PdfUnorderedList` | Numbered/bulleted lists |
| `PdfColor` / `PdfSolidBrush` / `PdfPen` | Colors and styling |
| `PdfBookmarkCollection` | Document navigation bookmarks |
| `PdfPath` | Bezier paths for complex shapes |

## License

MIT License. See [LICENSE](LICENSE) for details.
