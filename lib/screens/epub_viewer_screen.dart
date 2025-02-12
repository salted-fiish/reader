import 'package:flutter/material.dart';
import 'package:epub_view/epub_view.dart';
import 'dart:io';

class EpubViewerScreen extends StatefulWidget {
  final String epubPath;

  const EpubViewerScreen({super.key, required this.epubPath});

  @override
  State<EpubViewerScreen> createState() => _EpubViewerScreenState();
}

class _EpubViewerScreenState extends State<EpubViewerScreen> {
  late EpubController _epubController;
  bool _showMenu = false;
  bool _isVerticalScroll = false;  // 控制滚动方向

  @override
  void initState() {
    super.initState();
    _epubController = EpubController(
      document: EpubDocument.openFile(File(widget.epubPath)),
    );
  }

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
            child: EpubView(
              controller: _epubController,
            ),
          ),
          if (_showMenu) ...[
            // 顶部菜单栏
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
                      widget.epubPath.split('/').last,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            // 底部菜单栏
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
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.list),
                          color: Colors.white,
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
                            _isVerticalScroll ? Icons.auto_stories : Icons.view_day,
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
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _epubController.dispose();
    super.dispose();
  }
}
