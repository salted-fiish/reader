import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../painters/progress_painter.dart';
import '../widgets/reading_history_chart.dart';

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  List<String> _recentBooks = [];
  Map<String, double> _bookProgress = {};
  bool _isLoading = true;
  String? _currentBook;
  double _progress = 0.0;
  int _totalBooks = 0;
  int _totalReadingMinutes = 0;
  int _totalReadingDays = 0;
  int _currentStreak = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentBooks = prefs.getStringList('recent_books') ?? [];
      
      // 加载每本书的进度
      for (var path in _recentBooks) {
        _bookProgress[path] = prefs.getDouble('progress_$path') ?? 0.0;
      }
      
      // 获取当前书籍
      if (_recentBooks.isNotEmpty) {
        _currentBook = _recentBooks[0];
        _progress = _bookProgress[_currentBook] ?? 0.0;
      }
      
      // 模拟一些统计数据
      _totalBooks = prefs.getStringList('pdf_paths')?.length ?? 0;
      _totalReadingMinutes = prefs.getInt('total_reading_minutes') ?? 1250;
      _totalReadingDays = prefs.getInt('total_reading_days') ?? 45;
      _currentStreak = prefs.getInt('current_streak') ?? 7;
      
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recentBooks.isEmpty) {
      return const Center(
        child: Text(
          '暂无阅读数据',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部统计卡片
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '阅读统计',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // 总体统计卡片
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // 左侧圆形进度
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CustomPaint(
                      painter: ProgressPainter(
                        progress: _progress,
                        progressColor: const Color(0xFF2D3A3A),
                        backgroundColor: Colors.grey[300]!,
                        strokeWidth: 8,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${(_progress * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3A3A),
                              ),
                            ),
                            Text(
                              '总进度',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // 右侧统计数据
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatRow('总阅读时长', '${(_totalReadingMinutes / 60).toStringAsFixed(1)}小时'),
                        const SizedBox(height: 12),
                        _buildStatRow('阅读天数', '$_totalReadingDays天'),
                        const SizedBox(height: 12),
                        _buildStatRow('当前连续', '$_currentStreak天'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 每周阅读统计标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '每周阅读',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // 每周阅读统计图表
          Container(
            height: 220,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: ReadingHistoryChart(
                weeklyProgress: [0.8, 0.5, 0.3, 0.9, 0.6, 0.4, 0.7],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 阅读习惯标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '阅读习惯',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // 阅读习惯卡片
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildHabitRow('平均阅读时长', '45分钟/天', Icons.timer, Colors.blue),
                  const SizedBox(height: 16),
                  _buildHabitRow('最常阅读时段', '晚上9点-11点', Icons.nightlight_round, Colors.indigo),
                  const SizedBox(height: 16),
                  _buildHabitRow('最长连续阅读', '3小时20分钟', Icons.emoji_events, Colors.amber),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 书籍统计标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '书籍统计',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // 书籍统计卡片
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildBookStat('$_totalBooks', '总书籍'),
                  _buildBookStat('${(_totalBooks * 0.4).toInt()}', '已完成'),
                  _buildBookStat('${(_totalBooks * 0.6).toInt()}', '进行中'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  
  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3A3A),
          ),
        ),
      ],
    );
  }
  
  Widget _buildHabitRow(String title, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3A3A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildBookStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3A3A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
} 