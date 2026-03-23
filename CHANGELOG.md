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
