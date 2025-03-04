import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

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
  double _savedProgress = 0.0;  // 保存的阅读进度
  bool _isProgressLoaded = false;  // 标记是否已加载进度
  
  // 使用late初始化PageController，以便在加载进度后设置初始页
  late PageController _pageController;
  List<String> _pages = [];

  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    // 先加载保存的进度
    _loadSavedProgress().then((_) {
      // 初始化控制器
      _pageController = PageController();
      _scrollController = ScrollController()
        ..addListener(_updateProgress);
      
      // 加载内容
      _loadContent();
    });
  }

  Future<void> _loadSavedProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _savedProgress = prefs.getDouble('progress_${widget.txtPath}') ?? 0.0;
        _isProgressLoaded = true;
        debugPrint('加载保存的进度: $_savedProgress');
      });
    } catch (e) {
      debugPrint('加载进度失败: $e');
      _savedProgress = 0.0;
      _isProgressLoaded = true;
    }
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
        
        // 内容加载完成后，设置初始位置
        _setInitialPosition();
      });
    } catch (e) {
      debugPrint('Error loading TXT file: $e');
    }
  }

  void _setInitialPosition() {
    if (_savedProgress > 0 && _isProgressLoaded) {
      if (_isPageMode && _pages.isNotEmpty) {
        // 翻页模式下，计算对应的页码
        final pageIndex = (_savedProgress * (_pages.length - 1)).round();
        // 使用jumpToPage而不是animateToPage，避免初始动画
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(pageIndex);
            debugPrint('设置初始页面: $pageIndex');
          }
        });
      } else if (!_isPageMode && _content.isNotEmpty) {
        // 滚动模式下，计算对应的滚动位置
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            final scrollPosition = _savedProgress * _scrollController.position.maxScrollExtent;
            _scrollController.jumpTo(scrollPosition);
            debugPrint('设置初始滚动位置: $scrollPosition');
          }
        });
      }
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
              // 顶部菜单栏 - 灵动岛风格
              Positioned(
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
                            widget.txtPath.split('/').last,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 底部菜单栏 - 灵动岛风格
              Positioned(
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
                          icon: const Icon(Icons.text_decrease, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _fontSize = (_fontSize - 2).clamp(12, 32);
                            });
                          },
                          tooltip: '缩小字体',
                        ),
                        IconButton(
                          icon: const Icon(Icons.text_increase, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _fontSize = (_fontSize + 2).clamp(12, 32);
                            });
                          },
                          tooltip: '放大字体',
                        ),
                        IconButton(
                          icon: Icon(
                            _isPageMode ? Icons.view_day : Icons.auto_stories,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPageMode = !_isPageMode;
                              // 切换模式时，保持阅读进度
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _setInitialPosition();
                              });
                            });
                          },
                          tooltip: _isPageMode ? '滚动模式' : '翻页模式',
                        ),
                      ],
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