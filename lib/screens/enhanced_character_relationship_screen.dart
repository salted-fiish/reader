import 'package:flutter/material.dart';

class EnhancedCharacterRelationshipScreen extends StatelessWidget {
  final Map<String, dynamic> analysisData;
  final String bookTitle;

  const EnhancedCharacterRelationshipScreen({
    super.key,
    required this.analysisData,
    required this.bookTitle,
  });

  @override
  Widget build(BuildContext context) {
    final isFamousWork = analysisData['is_famous_work'] as bool;
    final bookInfo = analysisData['book_info'] as Map<String, dynamic>?;
    final characters = analysisData['characters'] as List;
    final relationships = analysisData['relationships'] as List;

    return Scaffold(
      appBar: AppBar(
        title: Text('$bookTitle - 人物关系'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 书籍信息卡片
            if (isFamousWork && bookInfo != null) _buildBookInfoCard(bookInfo),
            
            const SizedBox(height: 24),
            const Text(
              '主要人物：',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...characters.map((character) => _buildCharacterCard(character)),
            
            const SizedBox(height: 24),
            const Text(
              '人物关系：',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...relationships.map((relation) => _buildRelationshipCard(relation)),
          ],
        ),
      ),
    );
  }

  Widget _buildBookInfoCard(Map<String, dynamic> bookInfo) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.book, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  bookInfo['title'] ?? '未知作品',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            if (bookInfo['author'] != null) ...[
              const SizedBox(height: 8),
              Text(
                '作者：${bookInfo['author']}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              '当前情节：',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              bookInfo['current_plot'] ?? '未知情节',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterCard(Map<String, dynamic> character) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  character['name'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: character['importance'] == '主要' 
                        ? Colors.blue.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    character['importance'],
                    style: TextStyle(
                      color: character['importance'] == '主要' 
                          ? Colors.blue
                          : Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              character['description'],
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelationshipCard(Map<String, dynamic> relation) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  relation['from'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, size: 16),
                ),
                Text(
                  relation['to'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    relation['type'],
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              relation['description'],
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
} 