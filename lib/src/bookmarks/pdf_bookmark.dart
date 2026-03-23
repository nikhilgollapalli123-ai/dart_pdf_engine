/// Represents a bookmark (outline) entry in the PDF document.
class PdfBookmark {
  final String title;
  final int pageIndex;

  PdfBookmark(this.title, this.pageIndex);
}

/// Collection of bookmarks in the document.
class PdfBookmarkCollection {
  final List<PdfBookmark> bookmarks = [];

  /// Add a bookmark pointing to a page.
  /// [title] is the display text.
  /// [pageIndex] is the zero-based page index.
  PdfBookmark add(String title, {required int pageIndex}) {
    final bookmark = PdfBookmark(title, pageIndex);
    bookmarks.add(bookmark);
    return bookmark;
  }

  /// Get the number of bookmarks.
  int get count => bookmarks.length;

  /// Get a bookmark by index.
  PdfBookmark operator [](int index) => bookmarks[index];
}
