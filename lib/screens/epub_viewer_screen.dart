import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_html/flutter_html.dart';
import 'dart:convert';
import 'package:html/parser.dart' as htmlparser;
import 'package:gbk_codec/gbk_codec.dart';
import 'dart:async';

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
  late EpubParser _parser;
  bool _isLoading = true;
  int _currentChapter = 0;
  final ScrollController _scrollController = ScrollController();
  Map<int, double> _chapterScrollPositions = {};
  bool _showMenu = false;  // 添加菜单显示状态控制
  double _fontSize = 18.0; // 默认字体大小
  
  // 阅读时间统计
  DateTime? _startReadingTime;
  Timer? _readingTimer;
  int _readingSeconds = 0;
  int _wordCount = 0;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    print("🚀 初始化EpubViewerScreen");
    _scrollController.addListener(_handleScroll);
    _loadEpub();
    _loadSettings();
    _startReadingSession();
  }

  void _handleScroll() {
    if (_scrollController.hasClients) {
      _chapterScrollPositions[_currentChapter] = _scrollController.offset;
      // print("📜 滚动位置更新: 章节$_currentChapter, 位置: ${_scrollController.offset}");
      _savePosition();
    }
  }

  Future<void> _loadEpub() async {
    // print("📚 开始加载EPUB: ${widget.epubPath}");
    _parser = EpubParser(widget.epubPath);
    await _parser.parse();

    if (mounted) {
      // print("📖 EPUB解析完成，章节数量: ${_parser.chapters.length}");
      setState(() {
        _isLoading = false;
      });
      
      // 更新总字数统计
      _updateTotalWordCount();
      
      await _loadLastPosition();
    }
  }

  /// **📌 加载上次阅读位置**
  Future<void> _loadLastPosition() async {
    // print("🔍 开始加载上次阅读位置");
    final prefs = await SharedPreferences.getInstance();
    final lastChapter = prefs.getInt('${widget.epubPath}_chapter') ?? 0;
    final scrollPositionsStr = prefs.getString('${widget.epubPath}_scroll_positions');
    
    // print("💾 存储的章节位置: $lastChapter");
    // print("💾 存储的滚动位置数据: $scrollPositionsStr");
    
    if (scrollPositionsStr != null) {
      try {
        final Map<String, dynamic> positions = json.decode(scrollPositionsStr);
        _chapterScrollPositions.clear();  // 清除旧数据
        positions.forEach((key, value) {
          _chapterScrollPositions[int.parse(key)] = (value as num).toDouble();
        });
        // print("📍 解析的滚动位置Map: $_chapterScrollPositions");
      } catch (e, stackTrace) {
        print("⚠️ 解析滚动位置数据失败: $e");
        print("调用栈: $stackTrace");
      }
    }

    // 尝试从CFI恢复位置
    await _restoreFromCfi();
    
    // 如果CFI恢复失败，则使用传统方式恢复
    if (mounted) {
      setState(() {
        _currentChapter = lastChapter;
      });

      // 延长等待时间，确保HTML内容完全加载
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_scrollController.hasClients) {
          final savedPosition = _chapterScrollPositions[_currentChapter] ?? 0.0;
          // print("📱 准备恢复滚动位置: $savedPosition");
          try {
            _scrollController.jumpTo(savedPosition);
            // print("✅ 滚动位置恢复成功");
          } catch (e) {
            // print("❌ 滚动位置恢复失败: $e");
          }
        } else {
          print("⚠️ ScrollController未就绪");
        }
      });
    }
  }

  /// **📌 保存阅读进度**
  Future<void> _savePosition() async {
    if (!mounted) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('${widget.epubPath}_chapter', _currentChapter);
      
      if (_scrollController.hasClients) {
        // 将Map转换为可序列化的格式
        final Map<String, dynamic> serializableMap = {};
        _chapterScrollPositions.forEach((key, value) {
          serializableMap[key.toString()] = value;
        });
        
        final scrollPositionsStr = json.encode(serializableMap);
        await prefs.setString('${widget.epubPath}_scroll_positions', scrollPositionsStr);
        // print("💾 保存进度成功 - 章节: $_currentChapter, 位置Map: $serializableMap");
        
        // 生成并保存CFI
        final cfi = _generateEpubCfi();
        if (cfi.isNotEmpty) {
          await prefs.setString('${widget.epubPath}_cfi', cfi);
          // print("📍 保存CFI成功: $cfi");
        }
      }
    } catch (e, stackTrace) {
      print("❌ 保存进度失败: $e");
      print("调用栈: $stackTrace");
    }
  }

  /// **📌 生成EPUB CFI (Content Fragment Identifier)**
  String _generateEpubCfi() {
    try {
      if (_currentChapter >= _parser.chapters.length) {
        print("⚠️ 生成CFI失败: 当前章节索引超出范围");
        return "";
      }
      
      final chapter = _parser.chapters[_currentChapter];
      if (chapter == null) {
        print("⚠️ 生成CFI失败: 当前章节为null");
        return "";
      }
      
      // 计算当前在章节中的相对位置
      double progress = 0.0;
      if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
        progress = _scrollController.offset / _scrollController.position.maxScrollExtent;
      }
      
      // 基本CFI格式: /6/4[chapterID]!/4/2/1:0.123
      // 其中0.123是章节内的相对位置
      final chapterId = chapter.href.split('.').first;
      final cfi = "/6/4[$chapterId]!/4/2/1:${progress.toStringAsFixed(4)}";
      
      // print("📊 生成CFI - 章节: $_currentChapter, 标题: ${chapter.title}, 进度: ${(progress * 100).toStringAsFixed(2)}%, CFI: $cfi");
      return cfi;
    } catch (e, stackTrace) {
      print("❌ 生成CFI失败: $e");
      print("调用栈: $stackTrace");
      return "";
    }
  }

  /// **📌 从CFI恢复阅读位置**
  Future<void> _restoreFromCfi() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cfi = prefs.getString('${widget.epubPath}_cfi');
      
      if (cfi == null || cfi.isEmpty) {
        print("ℹ️ 没有找到保存的CFI");
        return;
      }
      
      // print("🔍 尝试从CFI恢复位置: $cfi");
      
      // 解析CFI格式: /6/4[chapterID]!/4/2/1:0.123
      final regex = RegExp(r'/6/4\[(.*?)\]!/4/2/1:([\d\.]+)');
      final match = regex.firstMatch(cfi);
      
      if (match != null && match.groupCount >= 2) {
        final chapterId = match.group(1);
        final progress = double.tryParse(match.group(2) ?? "0") ?? 0.0;
        
        // print("📖 解析CFI - 章节ID: $chapterId, 进度: ${(progress * 100).toStringAsFixed(2)}%");
        
        // 查找对应章节
        int chapterIndex = -1;
        for (int i = 0; i < _parser.chapters.length; i++) {
          if (_parser.chapters[i].href.contains(chapterId!)) {
            chapterIndex = i;
            break;
          }
        }
        
        if (chapterIndex >= 0) {
          setState(() {
            _currentChapter = chapterIndex;
          });
          
          // 计算滚动位置
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_scrollController.hasClients) {
              final targetPosition = _scrollController.position.maxScrollExtent * progress;
              // print("📱 从CFI恢复滚动位置: $targetPosition");
              _scrollController.jumpTo(targetPosition);
            }
          });
          
          return;
        }
      }
      
      print("⚠️ CFI格式无效或找不到对应章节");
    } catch (e, stackTrace) {
      print("❌ 从CFI恢复位置失败: $e");
      print("调用栈: $stackTrace");
    }
  }

  void _previousChapter() {
    if (_currentChapter > 0) {
      setState(() {
        _currentChapter--;
        widget.onProgressChanged(_currentChapter / _parser.chapters.length);
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final savedPosition = _chapterScrollPositions[_currentChapter] ?? 0.0;
          _scrollController.jumpTo(savedPosition);
        }
      });
    }
  }

  void _nextChapter() {
    if (_currentChapter < _parser.chapters.length - 1) {
      setState(() {
        _currentChapter++;
        widget.onProgressChanged(_currentChapter / _parser.chapters.length);
        _calculateChapterWords(); // 计算新章节的字数
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final savedPosition = _chapterScrollPositions[_currentChapter] ?? 0.0;
          _scrollController.jumpTo(savedPosition);
        }
      });
    }
  }

  void _toggleMenu() {
    setState(() {
      _showMenu = !_showMenu;
    });
  }

  // 加载用户设置
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontSize = prefs.getDouble('epub_font_size') ?? 18.0;
    });
    print("⚙️ 加载设置 - 字体大小: $_fontSize");
  }

  // 保存用户设置
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('epub_font_size', _fontSize);
    print("⚙️ 保存设置 - 字体大小: $_fontSize");
  }

  // 增加字体大小
  void _increaseFontSize() {
    setState(() {
      _fontSize = _fontSize + 1.0;
      if (_fontSize > 30.0) _fontSize = 30.0;
    });
    _saveSettings();
  }

  // 减小字体大小
  void _decreaseFontSize() {
    setState(() {
      _fontSize = _fontSize - 1.0;
      if (_fontSize < 12.0) _fontSize = 12.0;
    });
    _saveSettings();
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
      
      // 更新今日阅读字数（根据当前章节估算）
      if (_currentChapter >= 0 && _currentChapter < _parser.chapters.length) {
        // 检查这个章节是否已经被计入今日字数
        final chapterKey = 'counted_today_${widget.epubPath}_chapter_$_currentChapter';
        if (prefs.getBool(chapterKey) != true) {
          final content = _parser.chapters[_currentChapter].content;
          final document = htmlparser.parse(content);
          final text = document.body?.text ?? '';
          final chapterWords = text.length;
          
          final todayWords = prefs.getInt('today_reading_words') ?? 0;
          await prefs.setInt('today_reading_words', todayWords + chapterWords);
          await prefs.setBool(chapterKey, true);
          
          // 在午夜重置今日章节计数标记
          _scheduleResetChapterCountFlags();
          
          debugPrint('更新今日阅读字数: +$chapterWords, 总计: ${todayWords + chapterWords}');
        }
      }
      
      debugPrint('已更新阅读统计: 总时间=${totalMinutes + 1}分钟, 今日=${todayMinutes + 1}分钟');
    } catch (e) {
      debugPrint('更新阅读统计失败: $e');
    }
  }
  
  // 安排在午夜重置章节计数标记
  void _scheduleResetChapterCountFlags() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = tomorrow.difference(now);
    
    Future.delayed(timeUntilMidnight, () async {
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        // 清除所有今日章节计数标记
        for (int i = 0; i < _parser.chapters.length; i++) {
          final chapterKey = 'counted_today_${widget.epubPath}_chapter_$i';
          await prefs.remove(chapterKey);
        }
        debugPrint('已重置今日章节计数标记');
      }
    });
  }
  
  // 更新总字数统计
  Future<void> _updateTotalWordCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 我们只在首次加载时更新总字数，避免重复计算
      if (prefs.getBool('counted_${widget.epubPath}') != true) {
        int totalContentLength = 0;
        
        // 计算所有章节的总字数
        for (var chapter in _parser.chapters) {
          final document = htmlparser.parse(chapter.content);
          final text = document.body?.text ?? '';
          totalContentLength += text.length;
        }
        
        final totalWords = prefs.getInt('total_reading_words') ?? 0;
        await prefs.setInt('total_reading_words', totalWords + totalContentLength);
        await prefs.setBool('counted_${widget.epubPath}', true);
        
        print("📊 更新总字数: $totalContentLength, 总计: ${totalWords + totalContentLength}");
      }
    } catch (e) {
      print("❌ 更新总字数失败: $e");
    }
  }

  // 计算章节内容的字数
  void _calculateChapterWords() {
    if (_currentChapter >= 0 && _currentChapter < _parser.chapters.length) {
      // 获取当前章节的内容，去除HTML标签后计算字数
      final content = _parser.chapters[_currentChapter].content;
      final document = htmlparser.parse(content);
      final text = document.body?.text ?? '';
      
      // 检查是否已经计算过这一章节
      String chapterKey = '${widget.epubPath}_chapter_$_currentChapter';
      SharedPreferences.getInstance().then((prefs) {
        if (prefs.getBool(chapterKey) != true) {
          // 增加字数统计
          _wordCount += text.length;
          prefs.setBool(chapterKey, true);
          print("📊 阅读字数增加: ${text.length}, 总计: $_wordCount");
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // 内容区域
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showMenu = !_showMenu;
                    });
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _parser.chapters[_currentChapter].title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // 解决Expanded错误，改用 ConstrainedBox
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: MediaQuery.of(context).size.height - 150, // 确保至少填满屏幕
                            ),
                            child: Html(
                              data: _parser.chapters[_currentChapter].content,
                              style: {
                                "body": Style(
                                  fontSize: FontSize(_fontSize),
                                  lineHeight: LineHeight(1.5),
                                ),
                                "p": Style(
                                  margin: Margins.only(bottom: 16),
                                ),
                              },
                            ),
                          ),
                          // 添加额外空间，防止菜单栏遮挡内容
                          SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
                        ],
                      ),
                    ),

                  ),
                ),
                // 顶部菜单栏 - 灵动岛风格
                if (_showMenu)
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
                              onPressed: () => Navigator.of(context).pop(),
                              tooltip: '返回',
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _parser.chapters[_currentChapter].title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${_currentChapter + 1}/${_parser.chapters.length}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // 底部菜单栏 - 灵动岛风格 - 固定在屏幕底部
                if (_showMenu)
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
                              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                              onPressed: _previousChapter,
                              tooltip: '上一章',
                            ),
                            IconButton(
                              icon: const Icon(Icons.list, color: Colors.white),
                              onPressed: _showChapterList,
                              tooltip: '目录',
                            ),
                            IconButton(
                              icon: const Icon(Icons.settings, color: Colors.white),
                              onPressed: _showSettings,
                              tooltip: '设置',
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                              onPressed: _nextChapter,
                              tooltip: '下一章',
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

  void _showChapterList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '目录',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _parser.chapters.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(
                        _parser.chapters[index].title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: _currentChapter == index ? FontWeight.bold : FontWeight.normal,
                          color: _currentChapter == index ? Theme.of(context).colorScheme.primary : null,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _currentChapter = index;
                          widget.onProgressChanged(_currentChapter / _parser.chapters.length);
                        });
                        
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_scrollController.hasClients) {
                            final savedPosition = _chapterScrollPositions[_currentChapter] ?? 0.0;
                            _scrollController.jumpTo(savedPosition);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '阅读设置',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // 字体大小调整
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.text_decrease),
                  onPressed: () {
                    _decreaseFontSize();
                    Navigator.pop(context);
                  },
                  tooltip: '减小字体',
                ),
                Text(
                  '字体大小: ${_fontSize.toInt()}',
                  style: const TextStyle(fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.text_increase),
                  onPressed: () {
                    _increaseFontSize();
                    Navigator.pop(context);
                  },
                  tooltip: '增大字体',
                ),
              ],
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.bookmark),
              title: const Text('生成书签'),
              onTap: () async {
                final cfi = _generateEpubCfi();
                if (cfi.isNotEmpty) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已创建书签: ${_parser.chapters[_currentChapter].title}')),
                  );
                  
                  // 这里可以添加保存书签的逻辑
                  final prefs = await SharedPreferences.getInstance();
                  final bookmarks = prefs.getStringList('${widget.epubPath}_bookmarks') ?? [];
                  final bookmark = json.encode({
                    'cfi': cfi,
                    'title': _parser.chapters[_currentChapter].title,
                    'chapter': _currentChapter,
                    'timestamp': DateTime.now().millisecondsSinceEpoch,
                  });
                  bookmarks.add(bookmark);
                  await prefs.setStringList('${widget.epubPath}_bookmarks', bookmarks);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_border),
              title: const Text('查看书签'),
              onTap: () {
                Navigator.pop(context);
                _showBookmarks();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('图书信息'),
              onTap: () {
                Navigator.pop(context);
                _showBookInfo();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList('${widget.epubPath}_bookmarks') ?? [];
    
    if (bookmarks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('没有保存的书签')),
        );
      }
      return;
    }
    
    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bookmarks',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: bookmarks.length,
                    itemBuilder: (context, index) {
                      final bookmark = json.decode(bookmarks[index]);
                      final title = bookmark['title'] as String;
                      final timestamp = DateTime.fromMillisecondsSinceEpoch(bookmark['timestamp'] as int);
                      final formattedDate = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
                      
                      return ListTile(
                        title: Text(title),
                        subtitle: Text(formattedDate),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            bookmarks.removeAt(index);
                            await prefs.setStringList('${widget.epubPath}_bookmarks', bookmarks);
                            Navigator.pop(context);
                            _showBookmarks();
                          },
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          final cfi = bookmark['cfi'] as String;
                          _jumpToCfi(cfi);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _jumpToCfi(String cfi) async {
    try {
      // print("🔍 尝试跳转到CFI: $cfi");
      
      final regex = RegExp(r'/6/4\[(.*?)\]!/4/2/1:([\d\.]+)');
      final match = regex.firstMatch(cfi);
      
      if (match != null && match.groupCount >= 2) {
        final chapterId = match.group(1);
        final progress = double.tryParse(match.group(2) ?? "0") ?? 0.0;
        
        // print("📖 解析CFI - 章节ID: $chapterId, 进度: ${(progress * 100).toStringAsFixed(2)}%");
        
        // 查找对应章节
        int chapterIndex = -1;
        for (int i = 0; i < _parser.chapters.length; i++) {
          if (_parser.chapters[i].href.contains(chapterId!)) {
            chapterIndex = i;
            break;
          }
        }
        
        if (chapterIndex >= 0) {
          setState(() {
            _currentChapter = chapterIndex;
            widget.onProgressChanged(_currentChapter / _parser.chapters.length);
          });
          
          // 计算滚动位置
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_scrollController.hasClients) {
              final targetPosition = _scrollController.position.maxScrollExtent * progress;
              // print("📱 跳转到滚动位置: $targetPosition");
              _scrollController.jumpTo(targetPosition);
            }
          });
          
          return;
        }
      }
      
      // print("⚠️ CFI格式无效或找不到对应章节");
    } catch (e, stackTrace) {
      // print("❌ 跳转到CFI失败: $e");
      // print("调用栈: $stackTrace");
    }
  }

  void _showBookInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('图书信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('文件路径: ${widget.epubPath}'),
            const SizedBox(height: 8),
            Text('章节数量: ${_parser.chapters.length}'),
            const SizedBox(height: 8),
            Text('当前章节: ${_currentChapter + 1}/${_parser.chapters.length}'),
            const SizedBox(height: 8),
            Text('阅读进度: ${((_currentChapter + 1) / _parser.chapters.length * 100).toStringAsFixed(2)}%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
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
    
    _savePosition();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }
}

class EpubParser {
  final String epubPath;
  late Archive archive;
  late String contentOpfPath;
  List<EpubChapter> chapters = [];
  Map<String, String> _titleMap = {};

  EpubParser(this.epubPath);

  String _detectAndDecode(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (e) {
      try {
        return gbk.decode(bytes);
      } catch (e) {
        try {
          return latin1.decode(bytes);
        } catch (e) {
          return utf8.decode(bytes, allowMalformed: true);
        }
      }
    }
  }

  Future<void> parse() async {
    try {
      final bytes = await File(epubPath).readAsBytes();
      archive = ZipDecoder().decodeBytes(bytes);
      
      await _parseTocNcx();
      
      final containerFile = archive.findFile('META-INF/container.xml');
      if (containerFile != null) {
        final containerXml = _detectAndDecode(containerFile.content);
        final document = XmlDocument.parse(containerXml);
        contentOpfPath = document.findAllElements('rootfile')
            .first.getAttribute('full-path') ?? '';
      }

      final contentOpfFile = archive.findFile(contentOpfPath);
      if (contentOpfFile != null) {
        final contentOpf = _detectAndDecode(contentOpfFile.content);
        await _parseContentOpf(contentOpf);
      }
    } catch (e) {
      print('解析EPUB失败: $e');
    }
  }

  Future<void> _parseTocNcx() async {
    try {
      final tocFile = archive.findFile('OEBPS/toc.ncx') ?? 
                     archive.findFile('toc.ncx');
      
      if (tocFile != null) {
        final tocContent = _detectAndDecode(tocFile.content);
        final document = XmlDocument.parse(tocContent);
        
        for (final navPoint in document.findAllElements('navPoint')) {
          final contentSrc = navPoint.findElements('content').first.getAttribute('src') ?? '';
          final text = navPoint.findElements('text').first.text;
          if (contentSrc.isNotEmpty && text.isNotEmpty) {
            final href = contentSrc.split('#')[0];
            _titleMap[href] = text;
          }
        }
      }
    } catch (e) {
      print('解析目录失败: $e');
    }
  }

  Future<void> _parseContentOpf(String contentOpf) async {
    final document = XmlDocument.parse(contentOpf);
    final spine = document.findAllElements('spine').first;
    final manifest = document.findAllElements('manifest').first;

    for (final itemref in spine.findAllElements('itemref')) {
      final idref = itemref.getAttribute('idref');
      if (idref != null) {
        final manifestItem = manifest.findAllElements('item')
            .firstWhere((item) => item.getAttribute('id') == idref);
        
        final href = manifestItem.getAttribute('href') ?? '';
        final mediaType = manifestItem.getAttribute('media-type') ?? '';
        
        if (mediaType.contains('html')) {
          final chapterFile = archive.findFile(
            path.join(path.dirname(contentOpfPath), href)
          );
          
          if (chapterFile != null) {
            final content = _detectAndDecode(chapterFile.content);
            String title = _titleMap[href] ?? '';
            
            if (title.isEmpty) {
              try {
                final document = htmlparser.parse(content);
                final titleElement = document.querySelector('h1') ?? 
                                   document.querySelector('h2') ??
                                   document.querySelector('h3') ??
                                   document.querySelector('title');
                if (titleElement != null) {
                  title = titleElement.text.trim();
                }
              } catch (e) {
                print('解析章节标题失败: $e');
              }
            }
            
            if (title.isEmpty) {
              title = '第${chapters.length + 1}章';
            }
            
            chapters.add(EpubChapter(href, content, title));
          }
        }
      }
    }
  }
}

class EpubChapter {
  final String href;
  final String content;
  final String title;
  
  EpubChapter(this.href, this.content, this.title);
}
