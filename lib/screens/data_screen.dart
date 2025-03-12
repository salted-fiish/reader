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
  
  // AI使用量统计数据
  int _characterAnalysisCount = 12; // 人物关系分析次数
  int _textSummaryCount = 8; // 文本摘要次数
  int _totalAIRequests = 20; // 总AI请求次数
  int _remainingTokens = 75000; // 剩余token数量
  int _totalTokens = 100000; // 总token数量
  
  // 阅读历史数据
  List<double> _weeklyData = List.filled(7, 0.0);
  List<double> _monthlyData = List.filled(30, 0.0);

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadAIUsageStats(); // 加载AI使用量统计数据
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

  // 加载AI使用量统计数据
  Future<void> _loadAIUsageStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 从SharedPreferences加载AI使用量统计数据
      // 如果没有保存的数据，则使用默认值
      setState(() {
        _characterAnalysisCount = prefs.getInt('ai_character_analysis_count') ?? 12;
        _textSummaryCount = prefs.getInt('ai_text_summary_count') ?? 8;
        _totalAIRequests = prefs.getInt('ai_total_requests') ?? 20;
        _remainingTokens = prefs.getInt('ai_remaining_tokens') ?? 75000;
        _totalTokens = prefs.getInt('ai_total_tokens') ?? 100000;
      });
    } catch (e) {
      debugPrint('加载AI使用量统计数据失败: $e');
      // 使用默认值
      setState(() {
        _characterAnalysisCount = 12;
        _textSummaryCount = 8;
        _totalAIRequests = 20;
        _remainingTokens = 75000;
        _totalTokens = 100000;
      });
    }
  }
  
  // 保存AI使用量统计数据
  Future<void> _saveAIUsageStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 保存AI使用量统计数据到SharedPreferences
      await prefs.setInt('ai_character_analysis_count', _characterAnalysisCount);
      await prefs.setInt('ai_text_summary_count', _textSummaryCount);
      await prefs.setInt('ai_total_requests', _totalAIRequests);
      await prefs.setInt('ai_remaining_tokens', _remainingTokens);
      await prefs.setInt('ai_total_tokens', _totalTokens);
    } catch (e) {
      debugPrint('保存AI使用量统计数据失败: $e');
    }
  }
  
  // 更新AI使用量统计数据
  void updateAIUsageStats({int characterAnalysis = 0, int textSummary = 0, int tokenUsed = 0}) {
    setState(() {
      _characterAnalysisCount += characterAnalysis;
      _textSummaryCount += textSummary;
      _totalAIRequests += (characterAnalysis + textSummary);
      _remainingTokens = (_remainingTokens - tokenUsed).clamp(0, _totalTokens);
    });
    
    // 保存更新后的数据
    _saveAIUsageStats();
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
          'No reading data',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    // 实时获取最新的总字数
    _refreshTotalWords();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 阅读统计卡片
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              elevation: 4,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatColumn('Total Time', '${(_totalReadingMinutes / 60).toStringAsFixed(1)}h'),
                        _buildStatColumn('Total Words', '${(_totalWords / 1000).toStringAsFixed(1)}k'),
                        _buildStatColumn('Reading Days', '$_totalReadingDays'),
                        _buildStatColumn('Current Streak', '$_currentStreak'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // AI使用量统计卡片
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              elevation: 4,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Usage Statistics',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildAIStatItem('$_characterAnalysisCount', 'Character Analysis'),
                        _buildAIStatItem('$_textSummaryCount', 'Text Summary'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 剩余Token进度条
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Remaining Tokens',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '$_remainingTokens / $_totalTokens',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3A3A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _remainingTokens / _totalTokens,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2D3A3A)),
                            minHeight: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 每周阅读统计图表
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              elevation: 4,
              color: Colors.white,
              shape: RoundedRectangleBorder(
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
                          _isWeeklyView ? 'Weekly Reading' : 'Monthly Reading',
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
                                          'week',
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
                                          'month',
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

                    const SizedBox(height: 10),

                    // 图表区域
                    Align(
                      alignment: _isWeeklyView ? Alignment.topCenter : Alignment.bottomCenter,
                      child: SizedBox(
                        height: 170,
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
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              elevation: 4,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Book Statistics',
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
                        _buildBookStat('$_totalBooks', 'Total'),
                        _buildBookStat('${_getCompletedBooksCount()}', 'Completed'),
                        _buildBookStat('${_getInProgressBooksCount()}', 'In Progress'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
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

  // AI使用量统计项
  Widget _buildAIStatItem(String value, String label) {
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
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
} 