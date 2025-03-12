import 'package:flutter/material.dart';

class EnhancedCharacterRelationshipScreen extends StatefulWidget {
  final Map<String, dynamic> analysisData;
  final String bookTitle;
  final Function()? onRefresh;
  final DateTime? analysisTime;

  const EnhancedCharacterRelationshipScreen({
    super.key,
    required this.analysisData,
    required this.bookTitle,
    this.onRefresh,
    this.analysisTime,
  });

  @override
  State<EnhancedCharacterRelationshipScreen> createState() => _EnhancedCharacterRelationshipScreenState();
}

class _EnhancedCharacterRelationshipScreenState extends State<EnhancedCharacterRelationshipScreen> {
  bool _showMenu = true;

  @override
  Widget build(BuildContext context) {
    final isFamousWork = widget.analysisData['is_famous_work'] as bool;
    final bookInfo = widget.analysisData['book_info'] as Map<String, dynamic>?;
    final characters = widget.analysisData['characters'] as List;
    final relationships = widget.analysisData['relationships'] as List;

    String analysisTimeText = '';
    if (widget.analysisTime != null) {
      final now = DateTime.now();
      final difference = now.difference(widget.analysisTime!);
      
      if (difference.inMinutes < 1) {
        analysisTimeText = 'Just now';
      } else if (difference.inHours < 1) {
        analysisTimeText = '${difference.inMinutes} minutes ago';
      } else if (difference.inDays < 1) {
        analysisTimeText = '${difference.inHours} hours ago';
      } else if (difference.inDays < 30) {
        analysisTimeText = '${difference.inDays} days ago';
      } else {
        analysisTimeText = 'Analyzed on ${widget.analysisTime!.year}-${widget.analysisTime!.month}-${widget.analysisTime!.day}';
      }
    }

    return Scaffold(
      body: GestureDetector(
        onTap: () {
          setState(() {
            _showMenu = !_showMenu;
          });
        },
        child: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    
                    if (widget.analysisTime != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              analysisTimeText,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    if (isFamousWork && bookInfo != null) _buildBookInfoCard(bookInfo),
                    
                    const SizedBox(height: 24),
                    const Text(
                      'Main Characters:',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...characters.map((character) => _buildCharacterCard(character)),
                    
                    const SizedBox(height: 24),
                    const Text(
                      'Character Relationships:',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...relationships.map((relation) => _buildRelationshipCard(relation)),
                    
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
                  ],
                ),
              ),
            ),
            
            if (_showMenu)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 20,
                right: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Back',
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${widget.bookTitle} - Character Relationships',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
            if (_showMenu)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 10,
                left: 20,
                right: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: widget.onRefresh,
                          tooltip: 'Refresh Analysis',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
                  bookInfo['title'] ?? 'Unknown Work',
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
                'Author: ${bookInfo['author']}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Current Plot:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              bookInfo['current_plot'] ?? 'Unknown plot',
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
                    color: character['importance'] == 'Main' || character['importance'] == '主要'
                        ? Colors.blue.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    character['importance'],
                    style: TextStyle(
                      color: character['importance'] == 'Main' || character['importance'] == '主要'
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