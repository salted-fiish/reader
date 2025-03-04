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
  Map<String, int> _lastReadTimestamps = {};
  bool _isWeeklyView = true; // 添加视图切换状态

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bookPaths = prefs.getStringList('pdf_paths') ?? [];
      
    //   // 加载每本书的进度
    //   for (var path in _bookPaths) {
    //     _bookProgress[path] = prefs.getDouble('progress_$path') ?? 0.0;
    //     _lastReadTimestamps[path] = prefs.getInt('last_read_$path') ?? 0;
    //   }
      
    //   // 获取最后阅读的书籍
    //   String? lastReadBook;
    //   int latestTimestamp = 0;
      
    //   for (var path in _bookPaths) {
    //     final timestamp = _lastReadTimestamps[path] ?? 0;
    //     if (timestamp > latestTimestamp && File(path).existsSync()) {
    //       latestTimestamp = timestamp;
    //       lastReadBook = path;
    //     }
    //   }
      
    //   // 如果没有最后阅读的书籍记录，但有书籍，则使用第一本书
    //   if (lastReadBook == null && _bookPaths.isNotEmpty) {
    //     for (var path in _bookPaths) {
    //       if (File(path).existsSync()) {
    //         lastReadBook = path;
    //         break;
    //       }
    //     }
    //   }
      
    //   _currentBook = lastReadBook;
    //   _progress = _currentBook != null ? (_bookProgress[_currentBook] ?? 0.0) : 0.0;
      
    //   // 模拟一些统计数据
    //   _totalBooks = _bookPaths.length;
      _totalReadingMinutes = prefs.getInt('total_reading_minutes') ?? 1250;
      _totalReadingDays = prefs.getInt('total_reading_days') ?? 45;
      _currentStreak = prefs.getInt('current_streak') ?? 7;
      
      _isLoading = false;
    });
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
    
    // 模拟数据
    final List<double> weeklyData = [0.8, 0.5, 0.3, 0.9, 0.6, 0.4, 0.7];
    final List<double> monthlyData = List.generate(30, (index) => (index % 7 == 0) ? 0.9 : (index % 5 == 0) ? 0.7 : (index % 3 == 0) ? 0.5 : 0.3);

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
                  // Text(
                  //   '阅读统计',
                  //   style: TextStyle(
                  //     fontSize: 20,
                  //     fontWeight: FontWeight.bold,
                  //     color: Colors.grey[800],
                  //   ),
                  // ),
                  // const SizedBox(height: 16),
                  
                  // 四列数据
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // 让四列均匀分布
                    children: [
                      // _buildStatColumn('总进度', '${(_progress * 100).toInt()}%'),
                      _buildStatColumn('总阅读时长', '${(_totalReadingMinutes / 60).toStringAsFixed(1)}h'),
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
                        weeklyProgress: _isWeeklyView ? weeklyData : monthlyData,
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
                  _buildBookStat('${(_totalBooks * 0.4).toInt()}', '已完成'),
                  _buildBookStat('${(_totalBooks * 0.6).toInt()}', '进行中'),
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
} 