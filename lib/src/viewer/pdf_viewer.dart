// PDF viewer widget with navigation and zoom.

import 'package:flutter/material.dart';

import 'pdf_viewer_controller.dart';
import 'pdf_page_view.dart';

/// A complete PDF viewer widget with page navigation and zoom support.
///
/// Displays PDF pages from a [PdfViewerController] in a scrollable,
/// zoomable view with optional page navigation controls.
///
/// ## Usage Modes
///
/// ### Mode 1: Preview a programmatically created PDF
/// ```dart
/// final doc = PdfDocument();
/// doc.pages.add().graphics.drawString('Hello', font, bounds: bounds);
///
/// PdfViewer(
///   controller: PdfViewerController.fromDocument(doc),
/// )
/// ```
///
/// ### Mode 2: Preview a PDF from base64
/// ```dart
/// PdfViewer(
///   controller: PdfViewerController.fromBase64(base64String),
/// )
/// ```
///
/// ### Mode 3: Preview a PDF from bytes
/// ```dart
/// PdfViewer(
///   controller: PdfViewerController.fromBytes(pdfBytes),
/// )
/// ```
class PdfViewer extends StatefulWidget {
  /// Controller that manages the PDF document and page state.
  final PdfViewerController controller;

  /// Whether to show built-in page navigation controls.
  final bool showNavigationControls;

  /// Whether to show the page indicator (e.g., "Page 1 of 5").
  final bool showPageIndicator;

  /// Whether to enable pinch-to-zoom.
  final bool enableZoom;

  /// Minimum zoom scale.
  final double minScale;

  /// Maximum zoom scale.
  final double maxScale;

  /// Background color behind the pages.
  final Color backgroundColor;

  /// Spacing between pages in continuous scroll mode.
  final double pageSpacing;

  /// Whether to scroll continuously through all pages or show one at a time.
  final bool continuousScroll;

  /// Optional builder for custom page decoration.
  final Widget Function(BuildContext context, int pageIndex, Widget pageWidget)?
      pageBuilder;

  /// Callback when a page becomes visible.
  final void Function(int pageIndex)? onPageChanged;

  const PdfViewer({
    super.key,
    required this.controller,
    this.showNavigationControls = true,
    this.showPageIndicator = true,
    this.enableZoom = true,
    this.minScale = 0.5,
    this.maxScale = 4.0,
    this.backgroundColor = const Color(0xFFEEEEEE),
    this.pageSpacing = 16.0,
    this.continuousScroll = true,
    this.pageBuilder,
    this.onPageChanged,
  });

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> {
  late ScrollController _scrollController;
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.controller.currentPage;
    _scrollController = ScrollController();
    _pageController = PageController(initialPage: _currentPage);

    widget.controller.onPageChanged = (index) {
      setState(() {
        _currentPage = index;
      });
      if (!widget.continuousScroll) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    };
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.pageCount == 0) {
      return Container(
        color: widget.backgroundColor,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No pages to display',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: widget.backgroundColor,
      child: Column(
        children: [
          // Page indicator bar.
          if (widget.showPageIndicator) _buildPageIndicator(),

          // PDF content area.
          Expanded(
            child: widget.enableZoom
                ? InteractiveViewer(
                    minScale: widget.minScale,
                    maxScale: widget.maxScale,
                    child: _buildPageContent(),
                  )
                : _buildPageContent(),
          ),

          // Navigation controls.
          if (widget.showNavigationControls &&
              widget.controller.pageCount > 1)
            _buildNavigationControls(),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf, color: Color(0xFFE53935), size: 20),
          const SizedBox(width: 8),
          Text(
            'Page ${_currentPage + 1} of ${widget.controller.pageCount}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF424242),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent() {
    if (widget.continuousScroll) {
      return _buildContinuousScrollView();
    } else {
      return _buildPagedView();
    }
  }

  Widget _buildContinuousScrollView() {
    return ListView.separated(
      controller: _scrollController,
      padding: EdgeInsets.all(widget.pageSpacing),
      itemCount: widget.controller.pageCount,
      separatorBuilder: (_, __) => SizedBox(height: widget.pageSpacing),
      itemBuilder: (context, index) {
        return Center(
          child: _buildPageWidget(context, index),
        );
      },
    );
  }

  Widget _buildPagedView() {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.controller.pageCount,
      onPageChanged: (index) {
        setState(() {
          _currentPage = index;
          widget.controller.currentPage = index;
        });
        widget.onPageChanged?.call(index);
      },
      itemBuilder: (context, index) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(widget.pageSpacing),
            child: _buildPageWidget(context, index),
          ),
        );
      },
    );
  }

  Widget _buildPageWidget(BuildContext context, int index) {
    final page = widget.controller.document.pages[index];

    final pageWidget = LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final displayWidth = maxWidth;

        return PdfPageView(
          page: page,
          width: displayWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
    );

    if (widget.pageBuilder != null) {
      return widget.pageBuilder!(context, index, pageWidget);
    }

    return pageWidget;
  }

  Widget _buildNavigationControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // First page.
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: _currentPage > 0
                ? () {
                    widget.controller.firstPage();
                    setState(() => _currentPage = 0);
                    if (!widget.continuousScroll) {
                      _pageController.animateToPage(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  }
                : null,
            tooltip: 'First page',
          ),

          // Previous page.
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 0
                ? () {
                    widget.controller.previousPage();
                    setState(() => _currentPage--);
                    if (!widget.continuousScroll) {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  }
                : null,
            tooltip: 'Previous page',
          ),

          const SizedBox(width: 16),

          // Page number display.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_currentPage + 1} / ${widget.controller.pageCount}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF616161),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Next page.
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < widget.controller.pageCount - 1
                ? () {
                    widget.controller.nextPage();
                    setState(() => _currentPage++);
                    if (!widget.continuousScroll) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  }
                : null,
            tooltip: 'Next page',
          ),

          // Last page.
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: _currentPage < widget.controller.pageCount - 1
                ? () {
                    final last = widget.controller.pageCount - 1;
                    widget.controller.lastPage();
                    setState(() => _currentPage = last);
                    if (!widget.continuousScroll) {
                      _pageController.animateToPage(
                        last,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  }
                : null,
            tooltip: 'Last page',
          ),
        ],
      ),
    );
  }
}
