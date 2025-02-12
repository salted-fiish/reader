import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../providers/theme_provider.dart';
import 'pdf_viewer_screen.dart';
import 'txt_viewer_screen.dart';
import 'epub_viewer_screen.dart';
import '../widgets/book_card.dart';

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
  bool _isGridView = false;
  bool _showList = true;  // 控制列表显示/隐藏
  final PageController _pageController = PageController(
    viewportFraction: 0.8,  // 让当前页面占据80%的宽度
    initialPage: 0,
  );

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

  // 添加一个方法来获取最近的3本书
  List<String> _getRecentBooks() {
    return _bookPaths.take(3).toList();  // 只取前3本书
  }

  void _handleVerticalDrag(DragUpdateDetails details) {
    if (details.delta.dy > 3) {  // 向下滑动
      setState(() {
        _showList = false;
      });
    } else if (details.delta.dy < -3) {  // 向上滑动
      setState(() {
        _showList = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeProvider.of(context);
    final recentBooks = _getRecentBooks();  // 获取最近的3本书
    
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
          : GestureDetector(
              onVerticalDragUpdate: _handleVerticalDrag,
              child: Column(
                children: [
                  // 最近阅读的书籍
                  Expanded(
                    flex: 2,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: recentBooks.length,  // 使用最近的3本书
                      itemBuilder: (context, index) {
                        final file = File(recentBooks[index]);
                        final fileName = file.path.split('/').last;
                        
                        return AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            double page = _pageController.hasClients 
                                ? _pageController.page ?? 0 
                                : 0;
                            double distance = (page - index).abs();
                            double opacity = 1.0 - (distance * 0.3).clamp(0.0, 0.3);
                            
                            // 计算颜色插值
                            final selectedColor = const Color.fromARGB(255, 73, 73, 73);
                            final unselectedColor = const Color.fromARGB(255, 114, 105, 105);
                            final color = Color.lerp(
                              unselectedColor,
                              selectedColor,
                              (1 - distance).clamp(0.0, 1.0),
                            );
                            
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Opacity(
                                  opacity: opacity,
                                  child: BookCard(
                                    title: fileName,
                                    coverPath: "",
                                    color: color,  // 传递插值后的颜色
                                    onTap: () => _openBook(context, recentBooks[index]),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  // 页面指示器
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: _showList ? 40 : 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          recentBooks.length,  // 使用最近的3本书
                          (index) => AnimatedBuilder(
                            animation: _pageController,
                            builder: (context, child) {
                              double page = _pageController.hasClients 
                                  ? _pageController.page ?? 0 
                                  : 0;
                              double distance = (page - index).abs();
                              double size = 1.0 - (distance * 0.3).clamp(0.0, 0.3);
                              
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                height: 8,
                                width: 8 + (16 * size),
                                decoration: BoxDecoration(
                                  color: distance < 0.5 
                                      ? Theme.of(context).colorScheme.primary 
                                      : Colors.grey,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 书籍列表
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: _showList ? MediaQuery.of(context).size.height * 0.3 : 0,
                    child: _isGridView ? _buildGridView() : _buildListView(),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickBook,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _bookPaths.length,
      itemBuilder: (context, index) {
        final file = File(_bookPaths[index]);
        final fileName = file.path.split('/').last;
        // final bookType = _getBookType(file.path);
        
        return BookCard(
          title: fileName,
          coverPath: "assets/covers/default_cover.jpg",
          onTap: () => _openBook(context, _bookPaths[index]),
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _bookPaths.length,
      itemBuilder: (context, index) {
        final file = File(_bookPaths[index]);
        final fileName = file.path.split('/').last;
        final bookType = _getBookType(file.path);
        return Container(
          height: 64,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 117, 117, 117),  // 使用相同的未选中颜色
            borderRadius: BorderRadius.circular(8),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _openBook(context, _bookPaths[index]),
              onLongPress: () => _showDeleteDialog(context, index, fileName),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _getFileIcon(bookType),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
} 