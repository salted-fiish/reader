import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Reader',
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2C2C2C),      // 主要颜色：深灰色
          secondary: Color(0xFF4A4A4A),    // 次要颜色：中灰色
          surface: Colors.white,            // 表面颜色：白色
          background: Color(0xFFF5F5F5),    // 背景色：浅灰色
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2C2C2C),
          foregroundColor: Colors.white,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF2C2C2C),
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const BookshelfScreen(),
    );
  }
}

class BookshelfScreen extends StatefulWidget {
  const BookshelfScreen({super.key});

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen> {
  List<String> _pdfPaths = [];

  @override
  void initState() {
    super.initState();
    _loadSavedPDFs();
  }

  Future<void> _loadSavedPDFs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pdfPaths = prefs.getStringList('pdf_paths') ?? [];
    });
  }

  Future<void> _savePDFPaths() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pdf_paths', _pdfPaths);
  }

  Future<void> _pickPDF() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _pdfPaths.add(result.files.single.path!);
        });
        await _savePDFPaths();
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  Future<void> _onRefresh() async {
    await Future.delayed(Duration(seconds: 2)); // 模拟网络请求
  }

  @override
  Widget build(BuildContext context) {
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
                color: Theme.of(context).primaryColor,
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
              leading: const Icon(Icons.sort),
              title: const Text('排序方式'),
              onTap: () {
                // 添加排序功能
                Navigator.pop(context); // 关闭抽屉
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('设置'),
              onTap: () {
                // 添加设置功能
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('关于'),
              onTap: () {
                // 添加关于功能
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: _pdfPaths.isEmpty
          ? const Center(child: Text('书架是空的\n点击右下角添加PDF文件'))
          : ListView.builder(
              itemCount: _pdfPaths.length,
              itemBuilder: (context, index) {
                final file = File(_pdfPaths[index]);
                final fileName = file.path.split('/').last;
                return ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: Text(fileName),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PDFViewerScreen(pdfPath: _pdfPaths[index]),
                      ),
                    );
                  },
                  onLongPress: () async {
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
                        _pdfPaths.removeAt(index);
                      });
                      await _savePDFPaths();
                    }
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickPDF,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class PDFViewerScreen extends StatefulWidget {
  final String pdfPath;

  const PDFViewerScreen({super.key, required this.pdfPath});

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  bool _showMenu = false;
  final PdfViewerController _pdfViewerController = PdfViewerController();
  PdfScrollDirection _scrollDirection = PdfScrollDirection.horizontal;

  void _toggleMenu() {
    setState(() {
      _showMenu = !_showMenu;
    });
  }

  void _showPageModeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('选择翻页模式'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('左右滑动'),
                selected: _scrollDirection == PdfScrollDirection.horizontal,
                onTap: () {
                  setState(() {
                    _scrollDirection = PdfScrollDirection.horizontal;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_vert),
                title: const Text('上下滑动'),
                selected: _scrollDirection == PdfScrollDirection.vertical,
                onTap: () {
                  setState(() {
                    _scrollDirection = PdfScrollDirection.vertical;
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // PDF 查看器
          SfPdfViewer.file(
            File(widget.pdfPath),
            controller: _pdfViewerController,
            onTap: (PdfGestureDetails details) {
              _toggleMenu();
            },
            scrollDirection: _scrollDirection,
          ),
          
          // 菜单层
          if (_showMenu) ...[
            // 顶部菜单栏
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: const Color(0xFF2C2C2C).withOpacity(0.9),
                child: SafeArea(
                  child: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      color: Colors.white,
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: Text(
                      widget.pdfPath.split('/').last,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            // 底部菜单栏
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: const Color(0xFF2C2C2C).withOpacity(0.9),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            _scrollDirection == PdfScrollDirection.horizontal
                                ? Icons.swap_horiz
                                : Icons.swap_vert,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _scrollDirection = _scrollDirection == PdfScrollDirection.horizontal
                                  ? PdfScrollDirection.vertical
                                  : PdfScrollDirection.horizontal;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
