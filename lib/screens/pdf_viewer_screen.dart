import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';

class PDFViewerScreen extends StatefulWidget {
  final String pdfPath;

  const PDFViewerScreen({super.key, required this.pdfPath});

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  bool _showMenu = false;
  final PdfViewerController _pdfViewerController = PdfViewerController();
  PdfScrollDirection _scrollDirection = PdfScrollDirection.horizontal;
  PdfPageLayoutMode _pageLayoutMode = PdfPageLayoutMode.single;

  void _toggleMenu() {
    setState(() {
      _showMenu = !_showMenu;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SfPdfViewer.file(
            File(widget.pdfPath),
            controller: _pdfViewerController,
            onTap: (PdfGestureDetails details) {
              _toggleMenu();
            },
            scrollDirection: _scrollDirection,
            pageLayoutMode: _pageLayoutMode,
            canShowScrollHead: false,
            pageSpacing: 0,
          ),
          
          if (_showMenu) ...[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: const Color(0xFF2C2C2C).withOpacity(0.9),
                child: SafeArea(
                  child: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      color: Colors.white,
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: Text(
                      widget.pdfPath.split('/').last,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: const Color(0xFF2C2C2C).withOpacity(0.9),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            _scrollDirection == PdfScrollDirection.horizontal
                                ? Icons.swap_horiz
                                : Icons.swap_vert,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _scrollDirection = _scrollDirection == PdfScrollDirection.horizontal
                                  ? PdfScrollDirection.vertical
                                  : PdfScrollDirection.horizontal;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
} 