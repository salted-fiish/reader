import 'package:flutter/material.dart';
import 'package:epub_view/epub_view.dart';
import 'dart:io';

class EpubViewerScreen extends StatefulWidget {
  final String epubPath;
  final Function(double) onProgressChanged;

  const EpubViewerScreen({
    super.key,
    required this.epubPath,
    required this.onProgressChanged,
  });

  @override
  State<EpubViewerScreen> createState() => _EpubViewerScreenState();
}

class _EpubViewerScreenState extends State<EpubViewerScreen> {
  late EpubController _epubController;
  bool _showMenu = false;
  bool _isVerticalScroll = false;
  bool _isLoading = true; // Track loading state

  @override
  void initState() {
    super.initState();
    _initializeEpubController();
  }

  /// Initializes the EPUB controller asynchronously
  void _initializeEpubController() {
    Future<EpubBook> document = EpubDocument.openFile(File(widget.epubPath));

    setState(() {
      _epubController = EpubController(document: document);
      _isLoading = false;
    });
  }

  /// Handles progress updates
  void _handleProgressChange() {
    if (!mounted) return;
    try {
      final location = _epubController.currentValue;
      if (location != null && location.chapter != null) {
        final currentIndex = location.chapterNumber ?? 0;
        final totalChapters = _epubController.tableOfContents().length;

        if (totalChapters > 0) {
          final progress = currentIndex / totalChapters;
          widget.onProgressChanged(progress.clamp(0.0, 1.0));
        }
      }
    } catch (e) {
      debugPrint('Error updating EPUB progress: $e');
    }
  }

  /// Toggles the visibility of the menu
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
          GestureDetector(
            onTap: _toggleMenu,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    scrollDirection: _isVerticalScroll ? Axis.vertical : Axis.horizontal,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                      child: EpubView(
                        controller: _epubController,
                        onDocumentLoaded: (_) => _handleProgressChange(),
                        onChapterChanged: (_) => _handleProgressChange(),
                      ),
                    ),
                  ),
          ),
          if (_showMenu) buildMenu(),
        ],
      ),
    );
  }

  /// Builds the menu UI
  Widget buildMenu() {
    return Column(
      children: [
        // Top Menu (Back Button & Title)
        Container(
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
                widget.epubPath.split('/').last,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        const Spacer(),
        // Bottom Menu (Table of Contents & Scroll Mode Toggle)
        Container(
          color: const Color(0xFF2C2C2C).withOpacity(0.9),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.list, color: Colors.white),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => EpubViewTableOfContents(
                        controller: _epubController,
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    _isVerticalScroll ? Icons.view_day : Icons.auto_stories,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _isVerticalScroll = !_isVerticalScroll;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _epubController.dispose();
    super.dispose();
  }
}
