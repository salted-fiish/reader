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
import 'package:flutter/rendering.dart';
import '../utils/file_storage_helper.dart';


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

class _BookshelfScreenState extends State<BookshelfScreen> with WidgetsBindingObserver {
  List<String> _bookPaths = [];
  
  final PageController _mainPageController = PageController(
    viewportFraction: 0.8,
  );
  
  final PageController _compactPageController = PageController(
    viewportFraction: 0.8,
  );
  Map<String, double> _bookProgress = {};
  Map<String, int> _lastReadTimestamps = {}; // 添加最后阅读时间戳
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _bookPaths = [];      // 确保初始为空
    _bookProgress = {};   // 确保初始为空
    _lastReadTimestamps = {}; // 确保初始为空
    _loadSavedPDFs();
    _loadBookProgress();
    _loadLastReadTimestamps(); // 加载最后阅读时间戳
    
    // 添加定期刷新机制
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _fixFilePaths(); // 修复文件路径问题
      }
    });
    
    // 注册生命周期观察者
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 当应用恢复到前台时，检查文件
      if (mounted) {
        _fixFilePaths();
      }
    }
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
      _bookProgress.clear();  // 清除旧数据
      
      // 加载书架上所有书籍的进度
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

  Future<void> _loadLastReadTimestamps() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastReadTimestamps.clear();  // 清除旧数据
      
      // 加载书架上所有书籍的最后阅读时间
      for (var path in _bookPaths) {
        _lastReadTimestamps[path] = prefs.getInt('last_read_$path') ?? 0;
      }
    });
  }

  Future<void> _saveLastReadTimestamp(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt('last_read_$path', timestamp);
    if (mounted) {  // 添加mounted检查
      setState(() {
        _lastReadTimestamps[path] = timestamp;
      });
    }
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
        
        // 检查文件是否存在
        final file = File(path);
        if (!file.existsSync()) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('文件不存在: ${path.split('/').last}')),
          );
          return;
        }
        
        // 如果是mobi文件，先进行转换
        if (path.toLowerCase().endsWith('.mobi')) {
          await _convertMobiToEpub(path);
          return;
        }

        // 获取文件名
        final fileName = path.split('/').last;
        
        // 生成唯一文件名
        final uniqueFileName = await FileStorageHelper.generateUniqueFileName(
          fileName, 
          _bookPaths
        );
        
        // 复制文件到应用永久存储目录
        String finalPath;
        try {
          finalPath = await FileStorageHelper.copyFileToAppStorage(
            file,
            customFileName: uniqueFileName
          );
          
          if (uniqueFileName != fileName) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已添加为: $uniqueFileName')),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('复制文件失败: $e')),
          );
          return;
        }

        setState(() {
          if (!_bookPaths.contains(finalPath)) {  // 确保不重复添加
            _bookPaths.add(finalPath);
            _bookProgress[finalPath] = 0.0;       // 初始化进度
            _currentPage = 0;  // 重置当前页面索引
          }
        });
        
        await _savePDFPaths();
        await _saveBookProgress(finalPath, 0.0);
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
      
      // 获取原始文件名并替换扩展名
      final originalFileName = mobiPath.split('/').last;
      final epubFileName = originalFileName.replaceAll('.mobi', '.epub');
      
      // 创建临时文件
      final directory = File(mobiPath).parent.path;
      final tempEpubPath = '$directory/$epubFileName';
      
      // 下载处理后的文件到临时位置
      await service.downloadProcessedFile(epubUrl, tempEpubPath);
      
      // 将临时文件复制到应用永久存储目录
      final tempFile = File(tempEpubPath);
      if (tempFile.existsSync()) {
        // 生成唯一文件名
        final uniqueFileName = await FileStorageHelper.generateUniqueFileName(
          epubFileName, 
          _bookPaths
        );
        
        // 复制到永久存储
        final finalPath = await FileStorageHelper.copyFileToAppStorage(
          tempFile,
          customFileName: uniqueFileName
        );
        
        // 删除临时文件
        try {
          await tempFile.delete();
        } catch (e) {
          debugPrint('删除临时文件失败: $e');
        }
        
        Navigator.pop(context); // 关闭对话框

        setState(() {
          _bookPaths.remove(mobiPath);
          _bookPaths.add(finalPath);
          _bookProgress[finalPath] = 0.0;
          _currentPage = 0;  // 重置当前页面索引，确保界面更新
        });
        
        await _savePDFPaths();
        await _saveBookProgress(finalPath, 0.0);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('MOBI文件转换成功！')),
          );
        }
      } else {
        Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('转换后的文件不存在')),
          );
        }
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
    // 检查文件是否存在
    final file = File(path);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('文件不存在: ${path.split('/').last}')),
      );
      return;
    }

    // 更新最后阅读时间戳
    await _saveLastReadTimestamp(path);

    final bookType = _getBookType(path);
    Widget viewer;
    
    switch (bookType) {
      case BookType.pdf:
        viewer = PDFViewerScreen(
          pdfPath: path,
          onProgressChanged: (progress) async {
            await _saveBookProgress(path, progress);
            await _saveLastReadTimestamp(path); // 同时更新最后阅读时间
          },
        );
        break;
      case BookType.txt:
        viewer = TxtViewerScreen(
          txtPath: path,
          onProgressChanged: (progress) async {
            await _saveBookProgress(path, progress);
            await _saveLastReadTimestamp(path); // 同时更新最后阅读时间
          },
        );
        break;
      case BookType.epub:
        viewer = EpubViewerScreen(
          epubPath: path,
          onProgressChanged: (progress) async {
            await _saveBookProgress(path, progress);
            await _saveLastReadTimestamp(path); // 同时更新最后阅读时间
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
    
    // 从阅读器返回后刷新数据
    if (mounted) {
      await _refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    // 获取最后阅读的书籍
    String? lastReadBook;
    int latestTimestamp = 0;
    
    for (var path in _bookPaths) {
      final timestamp = _lastReadTimestamps[path] ?? 0;
      if (timestamp > latestTimestamp && File(path).existsSync()) {
        latestTimestamp = timestamp;
        lastReadBook = path;
      }
    }
    
    // 如果没有最后阅读的书籍记录，但有书籍，则使用第一本书
    if (lastReadBook == null && _bookPaths.isNotEmpty) {
      for (var path in _bookPaths) {
        if (File(path).existsSync()) {
          lastReadBook = path;
          break;
        }
      }
    }
    
    // 获取最后阅读书籍的进度
    final lastReadProgress = lastReadBook != null ? (_bookProgress[lastReadBook] ?? 0.0) : 0.0;
    
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
          : Column(
              children: [
                const SizedBox(height: 10),
                
                // 最后阅读的书籍
                if (lastReadBook != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                                  onTap: () => _openBook(context, lastReadBook!),
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
                                  '最近阅读',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${(lastReadProgress * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D3A3A),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  lastReadBook.split('/').last,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                                    widthFactor: lastReadProgress,
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
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                
                // 功能按钮区域
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  height: screenHeight * 0.20,
                  child: _buildFunctionButtons(),
                ),
                
                // 所有书籍网格视图
                Expanded(
                  child: _buildBooksGrid(),
                ),
              ],
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

  // 修改人物关系分析方法
  void _showCharacterRelationship(BuildContext context) async {
    if (_bookPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先导入一本书')),
      );
      return;
    }
    
    // 选择第一本书进行分析
    final currentBook = _bookPaths[0];
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

  // 添加一个新方法来显示所有书籍的网格视图
  Widget _buildBooksGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _bookPaths.length,
      itemBuilder: (context, index) {
        final path = _bookPaths[index];
        final fileName = path.split('/').last;
        final progress = _bookProgress[path] ?? 0.0;
        
        return GestureDetector(
          onTap: () => _openBook(context, path),
          onLongPress: () => _showDeleteDialog(context, index, fileName),
          child: Column(
            children: [
              // 书籍封面
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.book,
                          size: 40,
                          color: Colors.grey[700],
                        ),
                      ),
                      // 进度条
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF2D3A3A),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 书名
              Text(
                fileName,
                style: const TextStyle(
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
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
        _bookProgress.remove(path);
      });
      
      // 保存更新
      await _savePDFPaths();
      
      // 重新加载数据
      if (mounted) {
        setState(() {
          // 如果当前页面超出范围，重置为0
          if (_currentPage >= _bookPaths.length) {
            _currentPage = 0;
          }
        });
      }
    }
  }

  Future<void> _refreshData() async {
    print("刷新书架数据");
    await _loadSavedPDFs();
    await _loadBookProgress();
    await _loadLastReadTimestamps(); // 加载最后阅读时间戳
    
    if (mounted) {
      setState(() {
        // 确保当前页面索引在有效范围内
        if (_bookPaths.isNotEmpty) {
          if (_currentPage >= _bookPaths.length) {
            _currentPage = _bookPaths.length - 1;
          }
        } else {
          _currentPage = 0;
        }
      });
    }
  }

  Future<void> _clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pdf_paths');
    // 清除所有进度数据和最后阅读时间戳
    for (var path in _bookPaths) {
      await prefs.remove('progress_$path');
      await prefs.remove('last_read_$path');
    }
    setState(() {
      _bookPaths = [];
      _bookProgress = {};
      _lastReadTimestamps = {};
      _currentPage = 0;  // 重置当前页面索引
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mainPageController.dispose();
    _compactPageController.dispose();
    super.dispose();
  }

  // 修复文件路径问题
  Future<void> _fixFilePaths() async {
    // 检查所有书籍路径，确保它们是有效的
    List<String> validPaths = [];
    Map<String, double> validProgress = {};
    Map<String, int> validTimestamps = {};
    bool needsUpdate = false;
    
    for (var path in _bookPaths) {
      final file = File(path);
      if (file.existsSync()) {
        // 检查文件是否在应用永久存储目录中
        bool isInAppStorage = await FileStorageHelper.isFileInAppStorage(path);
        
        if (isInAppStorage) {
          // 如果已经在永久存储目录中，直接使用规范化的路径
          final normalizedPath = file.absolute.path;
          validPaths.add(normalizedPath);
          
          // 更新进度信息
          if (_bookProgress.containsKey(path)) {
            validProgress[normalizedPath] = _bookProgress[path]!;
          } else {
            validProgress[normalizedPath] = 0.0;
          }
          
          // 更新时间戳信息
          if (_lastReadTimestamps.containsKey(path)) {
            validTimestamps[normalizedPath] = _lastReadTimestamps[path]!;
          } else {
            validTimestamps[normalizedPath] = 0;
          }
          
          if (normalizedPath != path) {
            needsUpdate = true;
          }
        } else {
          // 如果不在永久存储目录中，需要迁移
          try {
            // 获取文件名
            final fileName = path.split('/').last;
            
            // 生成唯一文件名
            final uniqueFileName = await FileStorageHelper.generateUniqueFileName(
              fileName, 
              validPaths // 使用已验证的路径列表
            );
            
            // 复制到永久存储
            final newPath = await FileStorageHelper.copyFileToAppStorage(
              file,
              customFileName: uniqueFileName
            );
            
            validPaths.add(newPath);
            
            // 迁移进度信息
            if (_bookProgress.containsKey(path)) {
              validProgress[newPath] = _bookProgress[path]!;
            } else {
              validProgress[newPath] = 0.0;
            }
            
            // 迁移时间戳信息
            if (_lastReadTimestamps.containsKey(path)) {
              validTimestamps[newPath] = _lastReadTimestamps[path]!;
            } else {
              validTimestamps[newPath] = 0;
            }
            
            needsUpdate = true;
            debugPrint('文件已迁移到应用存储: $path -> $newPath');
          } catch (e) {
            debugPrint('迁移文件失败: $path, 错误: $e');
            // 如果迁移失败，仍然保留原路径
            validPaths.add(path);
            
            // 保留原进度信息
            if (_bookProgress.containsKey(path)) {
              validProgress[path] = _bookProgress[path]!;
            } else {
              validProgress[path] = 0.0;
            }
            
            // 保留原时间戳信息
            if (_lastReadTimestamps.containsKey(path)) {
              validTimestamps[path] = _lastReadTimestamps[path]!;
            } else {
              validTimestamps[path] = 0;
            }
          }
        }
      } else {
        needsUpdate = true;
        debugPrint('文件不存在，将从书架移除: $path');
      }
    }
    
    if (needsUpdate) {
      setState(() {
        _bookPaths = validPaths;
        _bookProgress = validProgress;
        _lastReadTimestamps = validTimestamps;
      });
      
      await _savePDFPaths();
      
      // 重新加载所有数据
      await _refreshData();
    }
  }
} 