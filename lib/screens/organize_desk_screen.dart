import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'pdf_viewer_screen.dart';
import 'txt_viewer_screen.dart';
import 'epub_viewer_screen.dart';
import 'dart:convert';

enum BookType {
  pdf,
  txt,
  epub,
  mobi,
  unknown
}

class OrganizeDeskScreen extends StatefulWidget {
  const OrganizeDeskScreen({super.key});

  @override
  State<OrganizeDeskScreen> createState() => _OrganizeDeskScreenState();
}

class _OrganizeDeskScreenState extends State<OrganizeDeskScreen> {
  List<String> _bookPaths = [];
  Map<String, double> _bookProgress = {};
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadSavedBooks();
  }
  
  Future<void> _loadSavedBooks() async {
    setState(() {
      _isLoading = true;
    });
    
    final prefs = await SharedPreferences.getInstance();
    final paths = prefs.getStringList('pdf_paths') ?? [];
    
    // 验证文件是否存在
    List<String> validPaths = [];
    Map<String, double> validProgress = {};
    
    for (var path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        validPaths.add(path);
        validProgress[path] = prefs.getDouble('progress_$path') ?? 0.0;
      }
    }
    
    setState(() {
      _bookPaths = validPaths;
      _bookProgress = validProgress;
      _isLoading = false;
    });
  }
  
  Future<void> _saveBookPaths() async {
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
      case 'mobi':
        return BookType.mobi;
      default:
        return BookType.unknown;
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
            // 保存阅读进度
            final prefs = await SharedPreferences.getInstance();
            await prefs.setDouble('progress_$path', progress);
          },
        );
        break;
      case BookType.txt:
        viewer = TxtViewerScreen(
          txtPath: path,
          onProgressChanged: (progress) async {
            // 保存阅读进度
            final prefs = await SharedPreferences.getInstance();
            await prefs.setDouble('progress_$path', progress);
          },
        );
        break;
      case BookType.epub:
        viewer = EpubViewerScreen(
          epubPath: path,
          onProgressChanged: (progress) async {
            // 保存阅读进度
            final prefs = await SharedPreferences.getInstance();
            await prefs.setDouble('progress_$path', progress);
          },
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('不支持的文件格式: ${path.split('.').last}')),
        );
        return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => viewer,
      ),
    );
    
    // 从阅读器返回后刷新数据
    if (mounted) {
      _loadSavedBooks();
    }
  }
  
  Future<void> _deleteBook(int index, String fileName) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除确认'),
        content: Text('确定要从书桌中删除 $fileName 吗？'),
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
      await _saveBookPaths();
      
      // 同时从downloaded_books中移除记录
      await _removeFromDownloadedBooks(path);
    }
  }
  
  // 从downloaded_books中移除记录
  Future<void> _removeFromDownloadedBooks(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final downloadedBooksJson = prefs.getString('downloaded_books') ?? '{}';
    final Map<String, dynamic> downloadedBooksMap = json.decode(downloadedBooksJson);
    
    // 查找并移除与此路径相关的记录
    String? keyToRemove;
    downloadedBooksMap.forEach((key, value) {
      if (value.toString() == path) {
        keyToRemove = key;
      }
    });
    
    if (keyToRemove != null) {
      downloadedBooksMap.remove(keyToRemove);
      await prefs.setString('downloaded_books', json.encode(downloadedBooksMap));
    }
  }
  
  void _showBookDetails(String path) {
    final fileName = path.split('/').last;
    final file = File(path);
    final fileSize = file.existsSync() ? file.lengthSync() : 0;
    final fileSizeStr = _formatFileSize(fileSize);
    final lastModified = file.existsSync() ? file.lastModifiedSync() : DateTime.now();
    final progress = _bookProgress[path] ?? 0.0;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('书籍详情'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('文件名', fileName),
            _buildDetailRow('文件大小', fileSizeStr),
            _buildDetailRow('修改时间', '${lastModified.year}-${lastModified.month}-${lastModified.day}'),
            _buildDetailRow('阅读进度', '${(progress * 100).toInt()}%'),
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
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('整理书桌', style: TextStyle(color: Color(0xFF2D3A3A))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D3A3A)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookPaths.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.menu_book,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '书桌上还没有书籍',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bookPaths.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final item = _bookPaths.removeAt(oldIndex);
                      _bookPaths.insert(newIndex, item);
                    });
                    _saveBookPaths();
                  },
                  itemBuilder: (context, index) {
                    final path = _bookPaths[index];
                    final fileName = path.split('/').last;
                    final progress = _bookProgress[path] ?? 0.0;
                    final bookType = _getBookType(path);
                    
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
                      key: ValueKey(path),
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            // 拖动手柄
                            const Icon(
                              Icons.drag_handle,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            // 文件类型图标
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                typeIcon,
                                size: 24,
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
                            // 操作按钮
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) {
                                switch (value) {
                                  case 'open':
                                    _openBook(path);
                                    break;
                                  case 'delete':
                                    _deleteBook(index, fileName);
                                    break;
                                  case 'details':
                                    _showBookDetails(path);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'open',
                                  child: Row(
                                    children: [
                                      Icon(Icons.book, size: 18),
                                      SizedBox(width: 8),
                                      Text('阅读'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'details',
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 18),
                                      SizedBox(width: 8),
                                      Text('详情'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('删除', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
} 