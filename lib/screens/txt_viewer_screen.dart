import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

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
  int _currentPage = 0;  // 当前页码

  late ScrollController _scrollController;
  
  // 阅读时间统计
  DateTime? _startReadingTime;
  Timer? _readingTimer;
  int _readingSeconds = 0;
  int _wordCount = 0;  // 替换章节变化为字数统计
  bool _isActive = true;

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
      
      // 开始记录阅读时间
      _startReadingSession();
    });
  }
  
  void _startReadingSession() {
    _startReadingTime = DateTime.now();
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isActive) {
        _readingSeconds++;
        
        // 每分钟保存一次阅读时间
        if (_readingSeconds % 60 == 0) {
          _updateReadingStats();
        }
      }
    });
  }
  
  Future<void> _updateReadingStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 更新总阅读时间
      final totalMinutes = prefs.getInt('total_reading_minutes') ?? 0;
      await prefs.setInt('total_reading_minutes', totalMinutes + 1);
      
      // 更新今日阅读时间
      final todayMinutes = prefs.getInt('today_reading_minutes') ?? 0;
      await prefs.setInt('today_reading_minutes', todayMinutes + 1);
      
      // 更新今日阅读字数（根据当前页面估算）
      if (_isPageMode && _currentPage < _pages.length) {
        final currentPageContent = _pages[_currentPage];
        // 检查这个页面是否已经被计入今日字数
        final pageKey = 'counted_today_${widget.txtPath}_page_$_currentPage';
        if (prefs.getBool(pageKey) != true) {
          final todayWords = prefs.getInt('today_reading_words') ?? 0;
          final pageWords = currentPageContent.length;
          await prefs.setInt('today_reading_words', todayWords + pageWords);
          await prefs.setBool(pageKey, true);
          
          // 在午夜重置今日页面计数标记
          _scheduleResetPageCountFlags();
          
          debugPrint('更新今日阅读字数: +$pageWords, 总计: ${todayWords + pageWords}');
        }
      }
      
      // 更新章节变化（模拟，每翻10页算作一章）
      if (_isPageMode && _currentPage % 10 == 0 && _currentPage > 0) {
        _simulateChapterChange();
      }
      
      debugPrint('已更新阅读统计: 总时间=${totalMinutes + 1}分钟, 今日=${todayMinutes + 1}分钟');
    } catch (e) {
      debugPrint('更新阅读统计失败: $e');
    }
  }

  // 安排在午夜重置页面计数标记
  void _scheduleResetPageCountFlags() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = tomorrow.difference(now);
    
    Future.delayed(timeUntilMidnight, () async {
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        // 清除所有今日页面计数标记
        for (int i = 0; i < _pages.length; i++) {
          final pageKey = 'counted_today_${widget.txtPath}_page_$i';
          await prefs.remove(pageKey);
        }
        debugPrint('已重置今日页面计数标记');
      }
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
        
        // 更新总字数统计
        _updateTotalWordCount(content.length);
      });
    } catch (e) {
      debugPrint('Error loading TXT file: $e');
    }
  }

  Future<void> _updateTotalWordCount(int contentLength) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final totalWords = prefs.getInt('total_reading_words') ?? 0;
      // 我们只在首次加载时更新总字数，避免重复计算
      if (prefs.getBool('counted_${widget.txtPath}') != true) {
        await prefs.setInt('total_reading_words', totalWords + contentLength);
        await prefs.setBool('counted_${widget.txtPath}', true);
        debugPrint('更新总字数: $contentLength, 总计: ${totalWords + contentLength}');
      }
    } catch (e) {
      debugPrint('更新总字数失败: $e');
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
  
  // 模拟章节变化的方法改为计算阅读字数
  void _calculateReadWords(int pageIndex) {
    if (pageIndex > 0 && pageIndex < _pages.length) {
      // 计算当前页面的字数
      int currentPageWords = _pages[pageIndex].length;
      
      // 检查是否已经计算过这一页
      String pageKey = '${widget.txtPath}_page_$pageIndex';
      SharedPreferences.getInstance().then((prefs) {
        if (prefs.getBool(pageKey) != true) {
          _wordCount += currentPageWords;
          prefs.setBool(pageKey, true);
          debugPrint('阅读字数增加: $currentPageWords, 总计: $_wordCount');
        }
      });
    }
  }

  // 模拟章节变化（每翻10页算作一章）
  Future<void> _simulateChapterChange() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayChapters = prefs.getInt('today_reading_chapters') ?? 0;
      await prefs.setInt('today_reading_chapters', todayChapters + 1);
      
      // 更新总章节数
      final totalChapters = prefs.getInt('total_reading_chapters') ?? 0;
      await prefs.setInt('total_reading_chapters', totalChapters + 1);
      
      debugPrint('模拟章节变化: 今日=${todayChapters + 1}, 总计=${totalChapters + 1}');
    } catch (e) {
      debugPrint('更新章节统计失败: $e');
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
                      setState(() {
                        _currentPage = index;
                      });
                      
                      final progress = index / (_pages.length - 1);
                      widget.onProgressChanged(progress);
                      
                      // 计算阅读字数
                      _calculateReadWords(index);
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
    // 保存最终阅读统计数据
    if (_readingSeconds > 0) {
      _updateReadingStats();
    }
    
    // 取消定时器
    _readingTimer?.cancel();
    
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }
} 