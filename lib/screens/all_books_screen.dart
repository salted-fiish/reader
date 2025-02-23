import 'package:flutter/material.dart';
import 'dart:io';

class AllBooksScreen extends StatefulWidget {
  final List<String> bookPaths;
  final Map<String, double> bookProgress;
  final Function(String) onOpenBook;
  final Function(int, String) onDeleteBook;

  const AllBooksScreen({
    super.key,
    required this.bookPaths,
    required this.bookProgress,
    required this.onOpenBook,
    required this.onDeleteBook,
  });

  @override
  State<AllBooksScreen> createState() => _AllBooksScreenState();
}

class _AllBooksScreenState extends State<AllBooksScreen> {
  late List<String> _localBookPaths;

  @override
  void initState() {
    super.initState();
    _localBookPaths = List.from(widget.bookPaths);
  }

  void _handleDeleteBook(int index, String fileName) async {
    await widget.onDeleteBook(index, fileName);
    if (mounted) {
      setState(() {
        _localBookPaths.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的书架'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _localBookPaths.length,
        itemBuilder: (context, index) {
          final file = File(_localBookPaths[index]);
          final fileName = file.path.split('/').last;
          
          return Container(
            height: 64,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 117, 117, 117),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => widget.onOpenBook(_localBookPaths[index]),
                onLongPress: () => _handleDeleteBook(index, fileName),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.book, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fileName,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontFamily: 'Times New Roman',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // 进度条
                            Container(
                              height: 2,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(1),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: widget.bookProgress[_localBookPaths[index]] ?? 0.0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(1),
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
            ),
          );
        },
      ),
    );
  }
} 