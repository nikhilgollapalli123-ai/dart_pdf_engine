/// dart_pdf_engine — A pure-Dart library for creating, reading,
/// and manipulating PDF documents.
///
/// Create PDFs with text, images, tables, shapes, fonts, bookmarks, and more.
/// All text is natively selectable and searchable in PDF viewers.
library dart_pdf_engine;

// Core
export 'src/pdf_document.dart';
export 'src/pdf_page.dart';
export 'src/pdf_graphics.dart';
export 'src/pdf_objects.dart';
export 'src/pdf_stream.dart';

// Fonts
export 'src/fonts/pdf_font.dart';
export 'src/fonts/pdf_standard_font.dart';
export 'src/fonts/pdf_truetype_font.dart';
export 'src/fonts/font_metrics.dart';

// Graphics
export 'src/graphics/pdf_color.dart';
export 'src/graphics/pdf_brush.dart';
export 'src/graphics/pdf_pen.dart';
export 'src/graphics/pdf_image.dart';
export 'src/graphics/pdf_path.dart';

// Elements
export 'src/elements/pdf_table.dart';
export 'src/elements/pdf_list.dart';

// Bookmarks
export 'src/bookmarks/pdf_bookmark.dart';

// Annotations
export 'src/annotations/pdf_annotation.dart';
export 'src/annotations/pdf_uri_annotation.dart';

// Parser
export 'src/parser/pdf_parser.dart';
export 'src/parser/pdf_tokenizer.dart';
