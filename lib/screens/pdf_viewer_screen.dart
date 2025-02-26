import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';

class PDFViewerScreen extends StatefulWidget {
  final String pdfPath;
  final Function(double) onProgressChanged;

  const PDFViewerScreen({
    super.key,
    required this.pdfPath,
    required this.onProgressChanged,
  });

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  bool _showMenu = false;
  final PdfViewerController _pdfViewerController = PdfViewerController();
  PdfScrollDirection _scrollDirection = PdfScrollDirection.horizontal;
  PdfPageLayoutMode _pageLayoutMode = PdfPageLayoutMode.single;
  int _totalPages = 0;

  void _toggleMenu() {
    setState(() {
      _showMenu = !_showMenu;
    });
  }

  void _updateProgress(PdfPageChangedDetails details) {
    if (_totalPages > 0) {
      final progress = (details.newPageNumber - 1) / (_totalPages - 1);
      widget.onProgressChanged(progress.clamp(0.0, 1.0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SfPdfViewer.file(
            File(widget.pdfPath),
            controller: _pdfViewerController,
            onDocumentLoaded: (PdfDocumentLoadedDetails details) {
              setState(() {
                _totalPages = details.document.pages.count;
              });
            },
            onTap: (PdfGestureDetails details) {
              _toggleMenu();
            },
            scrollDirection: _scrollDirection,
            pageLayoutMode: _pageLayoutMode,
            canShowScrollHead: false,
            pageSpacing: _scrollDirection == PdfScrollDirection.horizontal ? 0 : 8,
            onPageChanged: _updateProgress,
          ),
          
          // 顶部菜单栏 - 灵动岛风格
          if (_showMenu) Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C).withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      tooltip: '返回',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.pdfPath.split('/').last,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${_pdfViewerController.pageNumber}/$_totalPages',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // 底部菜单栏 - 灵动岛风格
          if (_showMenu) Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 10,
            left: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C).withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.zoom_out, color: Colors.white),
                      onPressed: () {
                        _pdfViewerController.zoomLevel = 
                            (_pdfViewerController.zoomLevel - 0.25).clamp(0.75, 3.0);
                      },
                      tooltip: '缩小',
                    ),
                    IconButton(
                      icon: const Icon(Icons.zoom_in, color: Colors.white),
                      onPressed: () {
                        _pdfViewerController.zoomLevel = 
                            (_pdfViewerController.zoomLevel + 0.25).clamp(0.75, 3.0);
                      },
                      tooltip: '放大',
                    ),
                    IconButton(
                      icon: Icon(
                        _scrollDirection == PdfScrollDirection.horizontal
                            ? Icons.view_day
                            : Icons.auto_stories,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _scrollDirection = _scrollDirection == PdfScrollDirection.horizontal
                              ? PdfScrollDirection.vertical
                              : PdfScrollDirection.horizontal;
                        });
                      },
                      tooltip: _scrollDirection == PdfScrollDirection.horizontal
                          ? '垂直滚动'
                          : '水平翻页',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }
} 