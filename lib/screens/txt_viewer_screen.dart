import 'package:flutter/material.dart';
import 'dart:io';

class TxtViewerScreen extends StatefulWidget {
  final String txtPath;
  final Function(double) onProgressChanged;

  const TxtViewerScreen({
    super.key,
    required this.txtPath,
    required this.onProgressChanged,
  });

  @override
  State<TxtViewerScreen> createState() => _TxtViewerScreenState();
}

class _TxtViewerScreenState extends State<TxtViewerScreen> {
  bool _showMenu = false;
  String _content = '';
  double _fontSize = 18.0;
  bool _isPageMode = false;  // 控制滚动/翻页模式
  final PageController _pageController = PageController();
  List<String> _pages = [];

  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _loadContent();
    _scrollController = ScrollController()
      ..addListener(_updateProgress);
  }

  void _splitIntoPages(String content) {
    const int charsPerPage = 1000;  // 每页字符数，可以根据需要调整
    _pages = [];
    for (int i = 0; i < content.length; i += charsPerPage) {
      _pages.add(content.substring(i, 
        i + charsPerPage > content.length ? content.length : i + charsPerPage));
    }
  }

  Future<void> _loadContent() async {
    try {
      final file = File(widget.txtPath);
      final content = await file.readAsString();
      setState(() {
        _content = content;
        _splitIntoPages(content);
      });
    } catch (e) {
      debugPrint('Error loading TXT file: $e');
    }
  }

  void _updateProgress() {
    if (_scrollController.position.maxScrollExtent > 0) {
      final progress = _scrollController.offset / _scrollController.position.maxScrollExtent;
      widget.onProgressChanged(progress.clamp(0.0, 1.0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () => setState(() => _showMenu = !_showMenu),
        child: Stack(
          children: [
            _isPageMode
                ? PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) {
                      final progress = index / (_pages.length - 1);
                      widget.onProgressChanged(progress);
                    },
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          _pages[index],
                          style: TextStyle(fontSize: _fontSize),
                        ),
                      );
                    },
                  )
                : SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _content,
                      style: TextStyle(fontSize: _fontSize),
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
                        widget.txtPath.split('/').last,
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.text_decrease),
                            color: Colors.white,
                            onPressed: () {
                              setState(() {
                                _fontSize = (_fontSize - 2).clamp(12, 32);
                              });
                            },
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.text_increase),
                            color: Colors.white,
                            onPressed: () {
                              setState(() {
                                _fontSize = (_fontSize + 2).clamp(12, 32);
                              });
                            },
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: Icon(
                              _isPageMode ? Icons.view_day : Icons.auto_stories,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPageMode = !_isPageMode;
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
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }
} 