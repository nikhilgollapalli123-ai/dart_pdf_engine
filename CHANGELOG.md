## 1.3.0

* **Enhanced PDF Renderer** — Comprehensive content stream operator support for the PDF viewer:
  * Text operators: `TJ`, `Tm`, `T*`, `TD`, `TL`, `Tc`, `Tw`, `'`, `"`
  * Fill/stroke operators: `f*`, `B*`, `b`, `b*`, `s`
  * Color operators: `cs`/`CS`, `sc`/`SC`/`scn`/`SCN`, `k`/`K` (CMYK)
  * Path operators: `v`, `y`, `W*` (even-odd clipping)
  * Line style: `j`, `J`, `M` (join, cap, miter limit)
  * Composite operator tokenization (`f*`, `B*`, `b*`, `W*`, `T*`)
  * Hex string support in `TJ` arrays
* **Parser fix** — Resolve indirect `Resources` and `Font` dictionary references.
* **Web compatibility** — Replaced `dart:io` ZLib with `package:archive` for cross-platform support (web/WASM).

## 1.2.0

* **PDF Viewer Widget** — New `PdfViewer`, `PdfPageView`, and `PdfPageRenderer` widgets for rendering PDFs in Flutter.
* `PdfViewerController` for programmatic page navigation and zoom control.
* Removed embedded raw data and test files from the package.

## 1.1.0

* **PDF Parsing** — `PdfDocument.fromBase64()` and `PdfDocument.fromBytes()` now fully parse existing PDFs.
* New `PdfTokenizer` for low-level PDF lexing.
* New `PdfParser` for high-level PDF structure parsing (xref, trailer, pages, bookmarks).
* Parse pages with dimensions and content streams.
* Extract document metadata (title, author, subject, creator).
* Extract bookmarks/outlines.
* Support for both traditional xref tables and cross-reference streams.
* FlateDecode stream decompression for content streams.
* `PdfPage.fromParsed()` constructor for loading parsed page data.
* `PdfGraphics.fromParsed()` constructor for pre-populated content streams.
* `PdfDocument.isLoaded` and `PdfDocument.rawBytes` properties.
* `PdfDocument.saveAsNew()` to re-serialize loaded documents.

## 1.0.0

* Initial release.
* PDF document creation from scratch.
* Text drawing with standard PDF fonts (Helvetica, Times, Courier, etc.).
* TrueType font embedding with subsetting.
* JPEG and PNG image embedding.
* Shapes: lines, rectangles, ellipses, paths.
* Colors, brushes, and pens.
* Multi-page documents with standard page sizes.
* Tables with cell styling, borders, and padding.
* Ordered and unordered lists.
* Document bookmarks/outlines.
* URI annotations (hyperlinks).
* Basic PDF reading and text extraction.
