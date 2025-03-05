import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

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
  int _lastPageNumber = 1;
  
  // 阅读时间统计
  DateTime? _startReadingTime;
  Timer? _readingTimer;
  int _readingSeconds = 0;
  int _wordCount = 0;
  bool _isActive = true;
  
  @override
  void initState() {
    super.initState();
    _startReadingSession();
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
      if (_pdfViewerController.pageNumber > 0) {
        // 检查这个页面是否已经被计入今日字数
        final pageKey = 'counted_today_${widget.pdfPath}_page_${_pdfViewerController.pageNumber}';
        if (prefs.getBool(pageKey) != true) {
          final todayWords = prefs.getInt('today_reading_words') ?? 0;
          // 每页估算500字
          final pageWords = 500;
          await prefs.setInt('today_reading_words', todayWords + pageWords);
          await prefs.setBool(pageKey, true);
          
          // 在午夜重置今日页面计数标记
          _scheduleResetPageCountFlags();
          
          debugPrint('更新今日阅读字数: +$pageWords, 总计: ${todayWords + pageWords}');
        }
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
        for (int i = 1; i <= _totalPages; i++) {
          final pageKey = 'counted_today_${widget.pdfPath}_page_$i';
          await prefs.remove(pageKey);
        }
        debugPrint('已重置今日页面计数标记');
      }
    });
  }
  
  // 估算PDF页面的字数
  void _estimatePageWords(int pageNumber) {
    if (pageNumber != _lastPageNumber) {
      // 检查是否已经计算过这一页
      String pageKey = '${widget.pdfPath}_page_$pageNumber';
      SharedPreferences.getInstance().then((prefs) {
        if (prefs.getBool(pageKey) != true) {
          // 对于PDF，我们假设每页有大约500个字
          _wordCount += 500;
          prefs.setBool(pageKey, true);
          debugPrint('估算阅读字数增加: 500, 总计: $_wordCount');
        }
      });
      
      _lastPageNumber = pageNumber;
    }
  }

  void _toggleMenu() {
    setState(() {
      _showMenu = !_showMenu;
    });
  }

  void _updateProgress(PdfPageChangedDetails details) {
    if (_totalPages > 0) {
      final progress = (details.newPageNumber - 1) / (_totalPages - 1);
      widget.onProgressChanged(progress.clamp(0.0, 1.0));
      _estimatePageWords(details.newPageNumber);
    }
  }

  // 更新总字数统计
  Future<void> _updateTotalWordCount() async {
    try {
      if (_totalPages <= 0) return;
      
      final prefs = await SharedPreferences.getInstance();
      // 我们只在首次加载时更新总字数，避免重复计算
      if (prefs.getBool('counted_${widget.pdfPath}') != true) {
        // 估算PDF总字数 (每页约500字)
        int estimatedTotalWords = _totalPages * 500;
        
        final totalWords = prefs.getInt('total_reading_words') ?? 0;
        await prefs.setInt('total_reading_words', totalWords + estimatedTotalWords);
        await prefs.setBool('counted_${widget.pdfPath}', true);
        
        debugPrint('更新PDF总字数: $estimatedTotalWords, 总计: ${totalWords + estimatedTotalWords}');
      }
    } catch (e) {
      debugPrint('更新总字数失败: $e');
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
                // 文档加载完成后更新总字数
                _updateTotalWordCount();
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
    // 保存最终阅读统计数据
    if (_readingSeconds > 0) {
      _updateReadingStats();
    }
    
    // 取消定时器
    _readingTimer?.cancel();
    
    _pdfViewerController.dispose();
    super.dispose();
  }
} 