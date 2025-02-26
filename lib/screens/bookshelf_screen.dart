import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../providers/theme_provider.dart';
import 'pdf_viewer_screen.dart';
import 'txt_viewer_screen.dart';
import 'epub_viewer_screen.dart';
import '../widgets/book_card.dart';
import 'all_books_screen.dart';
import '../services/ai_service.dart';
import 'character_relationship_screen.dart';
import 'package:flutter_pdf_text/flutter_pdf_text.dart';
import '../services/mobi_processing_service.dart';
import '../painters/progress_painter.dart';
import '../widgets/reading_history_chart.dart';


enum BookType {
  pdf,
  txt,
  epub,
  mobi,  // 添加 mobi 类型
  unknown
}

class BookshelfScreen extends StatefulWidget {
  const BookshelfScreen({super.key});

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen> {
  List<String> _bookPaths = [];
  List<String> _recentBooks = [];
  bool _showList = true;
  bool _showCompactView = false;
  
  final PageController _mainPageController = PageController(
    viewportFraction: 0.8,
  );
  
  final PageController _compactPageController = PageController(
    viewportFraction: 0.8,
  );
  Map<String, double> _bookProgress = {};
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _bookPaths = [];      // 确保初始为空
    _recentBooks = [];    // 确保初始为空
    _bookProgress = {};   // 确保初始为空
    _loadSavedPDFs();
    _loadBookProgress();
    _loadRecentBooks();
  }

  Future<void> _loadSavedPDFs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bookPaths = prefs.getStringList('pdf_paths') ?? [];
    });
  }

  Future<void> _savePDFPaths() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pdf_paths', _bookPaths);
  }

  Future<void> _loadBookProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (var path in _bookPaths) {
        _bookProgress[path] = prefs.getDouble('progress_$path') ?? 0.0;
      }
    });
  }

  Future<void> _saveBookProgress(String path, double progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('progress_$path', progress);
    if (mounted) {  // 添加mounted检查
      setState(() {
        _bookProgress[path] = progress;
      });
    }
  }

  Future<void> _loadRecentBooks() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentBooks = prefs.getStringList('recent_books') ?? [];
    });
  }

  Future<void> _saveRecentBooks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_books', _recentBooks);
  }

  BookType _getBookType(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return BookType.pdf;
      case 'txt':
        return BookType.txt;
      case 'epub':
        return BookType.epub;
      case 'mobi':
        return BookType.mobi;
      default:
        return BookType.unknown;
    }
  }

  Future<void> _pickLocalBook() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'epub', 'mobi'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        
        // 如果是mobi文件，先进行转换
        if (path.toLowerCase().endsWith('.mobi')) {
          await _convertMobiToEpub(path);
          return;
        }

        setState(() {
          if (!_bookPaths.contains(path)) {  // 确保不重复添加
            _bookPaths.add(path);
            _recentBooks.insert(0, path);    // 添加到最近阅读列表开头
            _bookProgress[path] = 0.0;       // 初始化进度
            _currentPage = 0;  // 重置当前页面索引
          }
        });
        
        await _savePDFPaths();
        await _saveRecentBooks();
        await _saveBookProgress(path, 0.0);
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  Future<void> _pickMobiFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mobi'],
      );

      if (result != null && result.files.single.path != null) {
        await _convertMobiToEpub(result.files.single.path!);
      }
    } catch (e) {
      debugPrint('Error picking MOBI file: $e');
    }
  }

  Future<void> _convertMobiToEpub(String mobiPath) async {
    final service = MobiProcessingService();
    
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在转换MOBI文件...')
            ],
          ),
        ),
      );

      final epubUrl = await service.uploadMobiFile(File(mobiPath));
      
      final directory = File(mobiPath).parent.path;
      final originalFileName = mobiPath.split('/').last;
      final epubFileName = originalFileName.replaceAll('.mobi', '.epub');
      final epubPath = '$directory/$epubFileName';
      
      await service.downloadProcessedFile(epubUrl, epubPath);
      
      Navigator.pop(context);

      setState(() {
        _bookPaths.remove(mobiPath);
        _bookPaths.add(epubPath);
        _bookProgress[epubPath] = 0.0;
      });
      
      await _savePDFPaths();
      await _saveBookProgress(epubPath, 0.0);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('MOBI文件转换成功！')),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('转换失败: $e')),
        );
      }
    }
  }

  void _openBook(BuildContext context, String path) async {
    // 更新最近阅读列表
    setState(() {
      _recentBooks.remove(path);  // 如果已存在，先移除
      _recentBooks.insert(0, path);  // 添加到开头
      if (_recentBooks.length > 3) {  // 保持最多3本书
        _recentBooks.removeLast();
      }
    });
    await _saveRecentBooks();

    final bookType = _getBookType(path);
    Widget viewer;
    
    switch (bookType) {
      case BookType.pdf:
        viewer = PDFViewerScreen(
          pdfPath: path,
          onProgressChanged: (progress) async {
            await _saveBookProgress(path, progress);
          },
        );
        break;
      case BookType.txt:
        viewer = TxtViewerScreen(
          txtPath: path,
          onProgressChanged: (progress) async {
            await _saveBookProgress(path, progress);
          },
        );
        break;
      case BookType.epub:
        viewer = EpubViewerScreen(
          epubPath: path,
          onProgressChanged: (progress) async {
            await _saveBookProgress(path, progress);
          },
        );
        break;
      default:
        viewer = const Center(child: Text('不支持的文件格式'));
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => viewer,
      ),
    );
  }

  // 修改获取最近书籍的方法
  List<String> _getRecentBooks() {
    return _recentBooks;  // 直接返回最近阅读的书籍列表
  }

  void _handleVerticalDrag(DragUpdateDetails details) {
    if (details.delta.dy > 10) {  // 向下滑动
      setState(() {
        _showList = false;
        _showCompactView = true;
      });
    } else if (details.delta.dy < -10) {  // 向上滑动
      setState(() {
        _showList = true;
        _showCompactView = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentBooks = _getRecentBooks();
    final screenHeight = MediaQuery.of(context).size.height;
    final currentBook = recentBooks.isNotEmpty ? recentBooks[0] : null;
    final progress = currentBook != null ? (_bookProgress[currentBook] ?? 0.0) : 0.0;
    
    return Scaffold(
      body: _bookPaths.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '书架是空的',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.black,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _pickLocalBook,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.download,
                                color: Colors.black,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '点击导入书籍',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : GestureDetector(
              onVerticalDragUpdate: _handleVerticalDrag,
              behavior: HitTestBehavior.translucent,
              child: Stack(
                children: [
                  // 主界面书籍展示
                  Column(
                    children: [
                      const SizedBox(height: 20),
                      // 新的书籍卡片设计
                      if (currentBook != null)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                // 书籍封面
                                Container(
                                  width: 100,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 5,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _openBook(context, currentBook),
                                        child: const Center(
                                          child: Icon(
                                            Icons.book,
                                            size: 40,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // 书籍信息
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '正在阅读',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${(progress * 100).toInt()}%',
                                        style: const TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2D3A3A),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '~ 19 小时剩余',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      // 进度条
                                      Container(
                                        height: 6,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor: progress,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2D3A3A),
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      // 阅读时长信息
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '今日阅读',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildReadingStatItem('2.5', '小时'),
                                _buildReadingStatItem('12', '章节'),
                                _buildReadingStatItem('15%', '进度'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const Spacer(),
                      SizedBox(
                        height: screenHeight * 0.25,
                        child: _buildFunctionButtons(),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),

                  // 下拉菜单
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    left: 0,
                    right: 0,
                    top: _showCompactView ? 0 : -screenHeight,
                    height: screenHeight,
                    child: Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: Column(
                        children: [
                          // 百分比部分
                          Container(
                            height: screenHeight / 3.35,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Container(
                                  width: 180,
                                  height: 180,
                                  child: CustomPaint(
                                    painter: ProgressPainter(
                                      progress: progress,
                                      progressColor: Colors.black,
                                      backgroundColor: Colors.grey[300]!,
                                      strokeWidth: 8,
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            '${(progress * 100).toInt()}',
                                            style: const TextStyle(
                                              fontSize: 48,
                                              color: Colors.black,
                                              fontWeight: FontWeight.w600,
                                              height: 1,
                                            ),
                                          ),
                                          const Text(
                                            '%',
                                            style: TextStyle(
                                              fontSize: 24,
                                              color: Colors.black,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // 柱状图部分
                          Container(
                            height: screenHeight / 3.35,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ReadingHistoryChart(
                                weeklyProgress: [0.8, 0.5, 0.3, 0.9, 0.6, 0.4, 0.7],
                              ),
                            ),
                          ),
                          // 书籍封面部分
                          Container(
                            height: screenHeight / 3.35,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  // 左侧封面
                                  Container(
                                    width: 100,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.book,
                                        size: 40,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  // 右侧书名
                                  Expanded(
                                    child: Text(
                                      currentBook?.split('/').last ?? '',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFunctionButtons() {
    final buttonItems = [
      {'icon': Icons.people_outline, 'title': '人物关系', 'onTap': () => _showCharacterRelationship(context)},
      {'icon': Icons.summarize, 'title': '概括上文', 'onTap': () {}},
      {'icon': Icons.download, 'title': '本地导入', 'onTap': _pickLocalBook},
      {'icon': Icons.pending, 'title': '未竟事宜', 'onTap': () {
        // 这里可以添加未竟事宜的处理逻辑
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('此功能尚未实现')),
        );
      }},
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: buttonItems.length,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: buttonItems[index]['onTap'] as Function(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D3A3A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        buttonItems[index]['icon'] as IconData,
                        color: const Color(0xFF2D3A3A),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      buttonItems[index]['title'] as String,
                      style: const TextStyle(
                        color: Color(0xFF2D3A3A),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 修改人物关系分析方法
  void _showCharacterRelationship(BuildContext context) async {
    if (_recentBooks.isEmpty) {  // 改用 _recentBooks 检查
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先阅读一本书')),
      );
      return;
    }
    
    final currentBook = _recentBooks[0];  // 获取最近阅读的书籍
    final fileName = currentBook.split('/').last;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('分析 $fileName 的人物关系'),
        content: const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
    
    try {
      String content;
      final fileExtension = currentBook.split('.').last.toLowerCase();
      
      switch (fileExtension) {
        case 'txt':
          content = await File(currentBook).readAsString();
          break;
        case 'pdf':
          final pdfDoc = await PDFDoc.fromPath(currentBook);
          content = await pdfDoc.text;
          break;
        case 'epub':
          // 如果需要添加epub支持
          throw Exception('暂不支持epub格式的人物关系分析');
        case 'mobi':
          // 如果需要添加mobi支持
          throw Exception('暂不支持mobi格式的人物关系分析');
        default:
          throw Exception('不支持的文件格式: $fileExtension');
      }

      if (content.length > 4000) {
        content = content.substring(0, 4000);
      }

      final result = await AIService.analyzeCharacterRelationships(content);
      
      if (mounted) {
        Navigator.pop(context);  // 关闭加载对话框
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CharacterRelationshipScreen(
              relationshipData: result,
              bookTitle: fileName,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);  // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分析失败: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildReadingStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3A3A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Future<void> _showDeleteDialog(BuildContext context, int index, String fileName) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除确认'),
        content: Text('确定要从书架中删除 $fileName 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (delete == true) {
      final path = _bookPaths[index];
      setState(() {
        _bookPaths.removeAt(index);
        _recentBooks.remove(path);
        _bookProgress.remove(path);
      });
      
      // 保存更新
      await _savePDFPaths();
      await _saveRecentBooks();
      
      // 重新加载数据
      if (mounted) {
        setState(() {
          // 如果当前页面超出范围，重置为0
          if (_currentPage >= _recentBooks.length) {
            _currentPage = 0;
          }
          // 如果没有书籍了，返回主界面
          if (_recentBooks.isEmpty) {
            Navigator.pop(context);
          }
        });
      }
    }
  }

  Future<void> _refreshData() async {
    await _loadSavedPDFs();
    await _loadRecentBooks();
    await _loadBookProgress();
    if (mounted) {
      setState(() {
        if (_currentPage >= _recentBooks.length) {
          _currentPage = _recentBooks.length - 1;
        }
      });
    }
  }

  Future<void> _clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pdf_paths');
    await prefs.remove('recent_books');
    // 清除所有进度数据
    for (var path in _bookPaths) {
      await prefs.remove('progress_$path');
    }
    setState(() {
      _bookPaths = [];
      _recentBooks = [];
      _bookProgress = {};
      _currentPage = 0;  // 重置当前页面索引
    });
  }

  @override
  void dispose() {
    _mainPageController.dispose();
    _compactPageController.dispose();
    super.dispose();
  }
} 