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
  List<String> _bookPaths = [];
  Map<String, double> _bookProgress = {};
  bool _isLoading = true;
  String? _currentBook;
  double _progress = 0.0;
  int _totalBooks = 0;
  int _totalReadingMinutes = 0;
  int _totalReadingDays = 0;
  int _currentStreak = 0;
  int _totalWords = 0;  // 添加总字数统计
  Map<String, int> _lastReadTimestamps = {};
  bool _isWeeklyView = true; // 添加视图切换状态
  
  // 阅读历史数据
  List<double> _weeklyData = List.filled(7, 0.0);
  List<double> _monthlyData = List.filled(30, 0.0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bookPaths = prefs.getStringList('pdf_paths') ?? [];
      
      // 加载每本书的进度
      for (var path in _bookPaths) {
        _bookProgress[path] = prefs.getDouble('progress_$path') ?? 0.0;
        _lastReadTimestamps[path] = prefs.getInt('last_read_$path') ?? 0;
      }
      
      // 获取最后阅读的书籍
      String? lastReadBook;
      int latestTimestamp = 0;
      
      for (var path in _bookPaths) {
        final timestamp = _lastReadTimestamps[path] ?? 0;
        if (timestamp > latestTimestamp && File(path).existsSync()) {
          latestTimestamp = timestamp;
          lastReadBook = path;
        }
      }
      
      // 如果没有最后阅读的书籍记录，但有书籍，则使用第一本书
      if (lastReadBook == null && _bookPaths.isNotEmpty) {
        for (var path in _bookPaths) {
          if (File(path).existsSync()) {
            lastReadBook = path;
            break;
          }
        }
      }
      
      _currentBook = lastReadBook;
      _progress = _currentBook != null ? (_bookProgress[_currentBook] ?? 0.0) : 0.0;
      
      // 实际统计数据
      _totalBooks = _bookPaths.length;
      _totalReadingMinutes = prefs.getInt('total_reading_minutes') ?? 0;
      _totalReadingDays = prefs.getInt('total_reading_days') ?? 0;
      _currentStreak = prefs.getInt('current_streak') ?? 0;
      _totalWords = prefs.getInt('total_reading_words') ?? 0;  // 加载总字数
      
      // 加载阅读历史数据
      _loadReadingHistoryData(prefs);
      
      _isLoading = false;
    });
  }
  
  // 加载阅读历史数据
  void _loadReadingHistoryData(SharedPreferences prefs) {
    // 获取周数据
    for (int i = 0; i < 7; i++) {
      final key = 'reading_day_${DateTime.now().subtract(Duration(days: 6 - i)).day}';
      _weeklyData[i] = prefs.getDouble(key) ?? 0.0;
    }
    
    // 获取月数据
    for (int i = 0; i < 30; i++) {
      final key = 'reading_day_${DateTime.now().subtract(Duration(days: 29 - i)).day}';
      _monthlyData[i] = prefs.getDouble(key) ?? 0.0;
    }
  }

  // 切换周/月视图
  void _toggleView() {
    setState(() {
      _isWeeklyView = !_isWeeklyView;
    });
  }

  Widget _buildStatColumn(String label, String value) {
  return Expanded(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3A3A),
          ),
        ),
        const SizedBox(height: 4), // 数字和文字之间的间距
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    ),
  );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_bookPaths.isEmpty) {
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

    // 实时获取最新的总字数
    _refreshTotalWords();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 阅读统计卡片
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // 让四列均匀分布
                    children: [
                      _buildStatColumn('总阅读时长', '${(_totalReadingMinutes / 60).toStringAsFixed(1)}h'),
                      _buildStatColumn('总字数', '${(_totalWords / 1000).toStringAsFixed(1)}k'),
                      _buildStatColumn('阅读天数', '$_totalReadingDays天'),
                      _buildStatColumn('当前连续', '$_currentStreak天'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 每周阅读统计图表
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题 + 提示信息 + 切换按钮
                  Row(
                    children: [
                      // 标题
                      Text(
                        _isWeeklyView ? '每周阅读' : '每月阅读',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      
                      // 提示信息（居中）
                      Expanded(
                        child: Center(
                          child: ValueListenableBuilder<String?>(
                            valueListenable: ReadingHistoryChart.tooltipNotifier,
                            builder: (context, tooltipText, _) {
                              return Text(
                                tooltipText ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      
                      // 切换滑块按钮
                      Container(
                        width: 120,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Stack(
                          children: [
                            // 滑动指示器
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              left: _isWeeklyView ? 0 : 60,
                              top: 0,
                              child: Container(
                                width: 60,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                            // 选项
                            Row(
                              children: [
                                // 周选项
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (!_isWeeklyView) _toggleView();
                                    },
                                    child: Center(
                                      child: Text(
                                        '周',
                                        style: TextStyle(
                                          color: _isWeeklyView ? Colors.white : Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // 月选项
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (_isWeeklyView) _toggleView();
                                    },
                                    child: Center(
                                      child: Text(
                                        '月',
                                        style: TextStyle(
                                          color: _isWeeklyView ? Colors.black : Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10), // 增加一点间距

                  // 图表区域
                  Align(
                    alignment: _isWeeklyView ? Alignment.topCenter : Alignment.bottomCenter,
                    child: SizedBox(
                      height: 170, // 让高度统一，位置靠对齐方式调整
                      child: ReadingHistoryChart(
                        weeklyProgress: _isWeeklyView ? _weeklyData : _monthlyData,
                        showAllBars: !_isWeeklyView,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          
          const SizedBox(height: 24),
          
          // 书籍统计卡片
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '书籍统计',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildBookStat('$_totalBooks', '总书籍'),
                      _buildBookStat('${_getCompletedBooksCount()}', '已完成'),
                      _buildBookStat('${_getInProgressBooksCount()}', '进行中'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  
  // 获取已完成的书籍数量
  int _getCompletedBooksCount() {
    int count = 0;
    for (var path in _bookPaths) {
      final progress = _bookProgress[path] ?? 0.0;
      if (progress >= 0.95) { // 认为进度超过95%的书籍为已完成
        count++;
      }
    }
    return count;
  }
  
  // 获取进行中的书籍数量
  int _getInProgressBooksCount() {
    int count = 0;
    for (var path in _bookPaths) {
      final progress = _bookProgress[path] ?? 0.0;
      if (progress > 0.0 && progress < 0.95) { // 进度在0-95%之间的书籍为进行中
        count++;
      }
    }
    return count;
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

  // 刷新总字数统计
  Future<void> _refreshTotalWords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final latestTotalWords = prefs.getInt('total_reading_words') ?? 0;
      
      // 只有当值发生变化时才更新UI
      if (latestTotalWords != _totalWords) {
        setState(() {
          _totalWords = latestTotalWords;
        });
      }
    } catch (e) {
      debugPrint('刷新总字数失败: $e');
    }
  }
} 