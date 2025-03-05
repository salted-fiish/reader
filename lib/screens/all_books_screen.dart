import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'pdf_viewer_screen.dart';
import 'txt_viewer_screen.dart';
import 'epub_viewer_screen.dart';
import '../utils/file_storage_helper.dart';

enum BookType {
  pdf,
  txt,
  epub,
  mobi,
  unknown
}

class AllBooksScreen extends StatefulWidget {
  final List<String>? bookPaths;
  final Map<String, double>? bookProgress;
  final Function(String)? onOpenBook;
  final Function(int, String)? onDeleteBook;

  const AllBooksScreen({
    super.key,
    this.bookPaths,
    this.bookProgress,
    this.onOpenBook,
    this.onDeleteBook,
  });

  @override
  State<AllBooksScreen> createState() => _AllBooksScreenState();
}

class _AllBooksScreenState extends State<AllBooksScreen> {
  List<String> _bookPaths = [];
  Map<String, double> _bookProgress = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.bookPaths != null && widget.bookProgress != null) {
      // 如果传入了书籍路径和进度，直接使用
      _bookPaths = List.from(widget.bookPaths!);
      _bookProgress = Map.from(widget.bookProgress!);
      _isLoading = false;
      
      // 添加延迟检查，确保文件存在
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _verifyFilesExist();
        }
      });
    } else {
      // 否则从SharedPreferences加载
      _loadSavedBooks();
    }
  }

  // 验证文件是否存在
  void _verifyFilesExist() {
    bool needsUpdate = false;
    List<String> validPaths = [];
    
    for (var path in _bookPaths) {
      final file = File(path);
      if (file.existsSync()) {
        validPaths.add(path);
      } else {
        needsUpdate = true;
        debugPrint('文件不存在: $path');
      }
    }
    
    if (needsUpdate && mounted) {
      setState(() {
        _bookPaths = validPaths;
      });
    }
  }

  Future<void> _loadSavedBooks() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> paths = prefs.getStringList('pdf_paths') ?? [];
    List<String> validPaths = [];
    
    // 验证文件是否存在
    for (var path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        validPaths.add(path);
      } else {
        debugPrint('文件不存在: $path');
      }
    }
    
    setState(() {
      _bookPaths = validPaths;
      _isLoading = false;
      
      // 加载每本书的进度
      for (var path in _bookPaths) {
        _bookProgress[path] = prefs.getDouble('progress_$path') ?? 0.0;
      }
    });
  }

  Future<void> _saveBookPaths() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pdf_paths', _bookPaths);
  }

  Future<void> _saveBookProgress(String path, double progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('progress_$path', progress);
    setState(() {
      _bookProgress[path] = progress;
    });
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
          }
        });
        
        await _saveBookPaths();
        await _saveBookProgress(finalPath, 0.0);
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  void _openBook(String path) async {
    // 检查文件是否存在
    final file = File(path);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('文件不存在: ${path.split('/').last}')),
      );
      return;
    }
    
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

    if (widget.onOpenBook != null) {
      widget.onOpenBook!(path);
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => viewer,
        ),
      );
      
      // 从阅读器返回后刷新数据
      if (mounted) {
        await _loadSavedBooks();
      }
    }
  }

  void _handleDeleteBook(int index, String fileName) async {
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
      if (widget.onDeleteBook != null) {
        widget.onDeleteBook!(index, fileName);
      } else {
        final path = _bookPaths[index];
        setState(() {
          _bookPaths.removeAt(index);
          _bookProgress.remove(path);
        });
        await _saveBookPaths();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('我的书桌', style: TextStyle(color: Color(0xFF2D3A3A))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D3A3A)),
      ),
      body: _bookPaths.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '书桌是空的',
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
          : Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _bookPaths.length,
                itemBuilder: (context, index) {
                  final file = File(_bookPaths[index]);
                  final fileName = file.path.split('/').last;
                  final progress = _bookProgress[_bookPaths[index]] ?? 0.0;
                  final bookType = _getBookType(_bookPaths[index]);
                  
                  // 获取文件类型对应的图标
                  IconData typeIcon;
                  switch (bookType) {
                    case BookType.pdf:
                      typeIcon = Icons.picture_as_pdf;
                      break;
                    case BookType.txt:
                      typeIcon = Icons.text_snippet;
                      break;
                    case BookType.epub:
                      typeIcon = Icons.menu_book;
                      break;
                    case BookType.mobi:
                      typeIcon = Icons.book_online;
                      break;
                    default:
                      typeIcon = Icons.description;
                  }
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openBook(_bookPaths[index]),
                      onLongPress: () => _handleDeleteBook(index, fileName),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            // 文件类型图标
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                typeIcon,
                                size: 28,
                                color: const Color(0xFF2D3A3A),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // 书籍信息
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fileName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  // 进度条
                                  LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.grey[300],
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2D3A3A)),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '阅读进度: ${(progress * 100).toInt()}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 删除按钮
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _handleDeleteBook(index, fileName),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
} 