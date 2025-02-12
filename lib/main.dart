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
        primarySwatch: Colors.blue,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的书架'),
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

class PDFViewerScreen extends StatelessWidget {
  final String pdfPath;

  const PDFViewerScreen({super.key, required this.pdfPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(pdfPath.split('/').last),
      ),
      body: SfPdfViewer.file(File(pdfPath)),
    );
  }
}
