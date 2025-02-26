import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'pdf_viewer_screen.dart';
import 'txt_viewer_screen.dart';
import 'epub_viewer_screen.dart';

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
    } else {
      // 否则从SharedPreferences加载
      _loadSavedBooks();
    }
  }

  Future<void> _loadSavedBooks() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bookPaths = prefs.getStringList('pdf_paths') ?? [];
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
        
        setState(() {
          if (!_bookPaths.contains(path)) {  // 确保不重复添加
            _bookPaths.add(path);
            _bookProgress[path] = 0.0;       // 初始化进度
          }
        });
        
        await _saveBookPaths();
        await _saveBookProgress(path, 0.0);
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  void _openBook(String path) async {
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_bookPaths.isEmpty) {
      return Center(
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
      );
    }

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.7,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _bookPaths.length,
            itemBuilder: (context, index) {
              final file = File(_bookPaths[index]);
              final fileName = file.path.split('/').last;
              
              return GestureDetector(
                onTap: () => _openBook(_bookPaths[index]),
                onLongPress: () => _handleDeleteBook(index, fileName),
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
                                  widthFactor: _bookProgress[_bookPaths[index]] ?? 0.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black,
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
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: FloatingActionButton(
            onPressed: _pickLocalBook,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
} 