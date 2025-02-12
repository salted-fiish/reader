import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../providers/theme_provider.dart';
import 'pdf_viewer_screen.dart';
import 'txt_viewer_screen.dart';
import 'epub_viewer_screen.dart';

enum BookType {
  pdf,
  txt,
  epub,
  unknown
}

class BookshelfScreen extends StatefulWidget {
  const BookshelfScreen({super.key});

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen> {
  List<String> _bookPaths = [];
  bool _isGridView = false;  // 控制显示模式，false为列表，true为网格

  @override
  void initState() {
    super.initState();
    _loadSavedPDFs();
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

  BookType _getBookType(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return BookType.pdf;
      case 'txt':
        return BookType.txt;
      case 'epub':
        return BookType.epub;
      default:
        return BookType.unknown;
    }
  }

  Future<void> _pickBook() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'epub'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _bookPaths.add(result.files.single.path!);
        });
        await _savePDFPaths();
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  Icon _getFileIcon(BookType type) {
    switch (type) {
      case BookType.pdf:
        return const Icon(Icons.picture_as_pdf);
      case BookType.txt:
        return const Icon(Icons.text_snippet);
      case BookType.epub:
        return const Icon(Icons.book);
      default:
        return const Icon(Icons.insert_drive_file);
    }
  }

  void _openBook(BuildContext context, String path) {
    final bookType = _getBookType(path);
    Widget viewer;
    
    switch (bookType) {
      case BookType.pdf:
        viewer = PDFViewerScreen(pdfPath: path);
        break;
      case BookType.txt:
        viewer = TxtViewerScreen(txtPath: path);
        break;
      case BookType.epub:
        viewer = EpubViewerScreen(epubPath: path);
        break;
      default:
        viewer = const Center(child: Text('不支持的文件格式'));
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => viewer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeProvider.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的书架'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const Text(
                'PDF阅读器',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
              title: Text(_isGridView ? '列表显示' : '网格显示'),
              onTap: () {
                setState(() {
                  _isGridView = !_isGridView;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              ),
              title: Text(themeProvider.isDarkMode ? '浅色模式' : '深色模式'),
              onTap: () {
                themeProvider.toggleTheme(!themeProvider.isDarkMode);
                Navigator.pop(context);
              },
            ),
            const Spacer(),  // 添加弹性空间
            const Divider(),  // 添加分隔线
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('设置'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('关于'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: _bookPaths.isEmpty
          ? const Center(child: Text('书架是空的\n点击右下角添加PDF文件'))
          : _isGridView
              ? GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,  // 每行显示2个
                    childAspectRatio: 0.75,  // 控制item的宽高比
                    crossAxisSpacing: 16,  // 横向间距
                    mainAxisSpacing: 16,  // 纵向间距
                  ),
                  itemCount: _bookPaths.length,
                  itemBuilder: (context, index) {
                    final file = File(_bookPaths[index]);
                    final fileName = file.path.split('/').last;
                    final bookType = _getBookType(file.path);
                    return Card(
                      elevation: 2,
                      child: InkWell(
                        onTap: () => _openBook(context, _bookPaths[index]),
                        onLongPress: () => _showDeleteDialog(context, index, fileName),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _getFileIcon(bookType),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                fileName,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              : ListView.builder(
                  itemCount: _bookPaths.length,
                  itemBuilder: (context, index) {
                    final file = File(_bookPaths[index]);
                    final fileName = file.path.split('/').last;
                    final bookType = _getBookType(file.path);
                    return ListTile(
                      leading: _getFileIcon(bookType),
                      title: Text(fileName),
                      onTap: () => _openBook(context, _bookPaths[index]),
                      onLongPress: () => _showDeleteDialog(context, index, fileName),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickBook,
        child: const Icon(Icons.add),
      ),
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
      setState(() {
        _bookPaths.removeAt(index);
      });
      await _savePDFPaths();
    }
  }
} 