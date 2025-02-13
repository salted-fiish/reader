import 'package:flutter/material.dart';

class CharacterRelationshipScreen extends StatelessWidget {
  final Map<String, dynamic> relationshipData;
  final String bookTitle;

  const CharacterRelationshipScreen({
    super.key,
    required this.relationshipData,
    required this.bookTitle,
  });

  @override
  Widget build(BuildContext context) {
    final characters = relationshipData['characters'] as List;
    final relationships = relationshipData['relationships'] as List;

    return Scaffold(
      appBar: AppBar(
        title: Text('$bookTitle - 人物关系'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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