import 'package:flutter/material.dart';

class ReadingHistoryChart extends StatefulWidget {
  final List<double> weeklyProgress; // 阅读进度数据
  final bool showAllBars; // 是否显示所有数据条（月视图）
  
  // 添加静态的ValueNotifier用于通知提示信息
  static final ValueNotifier<String?> tooltipNotifier = ValueNotifier<String?>(null);

  const ReadingHistoryChart({
    super.key,
    required this.weeklyProgress,
    this.showAllBars = false,
  });

  @override
  State<ReadingHistoryChart> createState() => _ReadingHistoryChartState();
}

class _ReadingHistoryChartState extends State<ReadingHistoryChart> {
  int? _selectedBarIndex;

  @override
  void dispose() {
    super.dispose();
  }

  // 更新提示信息
  void _updateTooltip(int index) {
    final now = DateTime.now();
    final date = now.subtract(Duration(days: widget.showAllBars ? 30 - index - 1 : 7 - index - 1));
    final formattedDate = '${date.month}.${date.day}';
    final readingHours = (widget.weeklyProgress[index] * 3).toStringAsFixed(1);
    
    ReadingHistoryChart.tooltipNotifier.value = '$formattedDate - $readingHours h';
  }

  // 清除提示信息
  void _clearTooltip() {
    ReadingHistoryChart.tooltipNotifier.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
      child: widget.showAllBars 
          ? _buildGithubStyleChart() 
          : _buildWeeklyChart(),
    );
  }

  // 构建周视图图表
  Widget _buildWeeklyChart() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (index) {
        return GestureDetector(
          onTapDown: (details) {
            setState(() {
              _selectedBarIndex = index;
            });
            _updateTooltip(index);
          },
          onTapUp: (_) {
            setState(() {
              _selectedBarIndex = null;
            });
            _clearTooltip();
          },
          onTapCancel: () {
            setState(() {
              _selectedBarIndex = null;
            });
            _clearTooltip();
          },
          child: _buildBar(index, widget.weeklyProgress[index], isSelected: _selectedBarIndex == index),
        );
      }),
    );
  }

  // 构建GitHub点阵式图表
  Widget _buildGithubStyleChart() {
    // 计算行数和列数，使其充满整个卡片
    const int rows = 4;
    final int cols = (widget.weeklyProgress.length / rows).ceil();
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据可用宽度计算色块大小，确保不会超出容器
        final cellSize = (constraints.maxWidth - 20) / cols;
        
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(rows, (rowIndex) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(cols, (colIndex) {
                final index = rowIndex * cols + colIndex;
                if (index < widget.weeklyProgress.length) {
                  return GestureDetector(
                    onTapDown: (details) {
                      setState(() {
                        _selectedBarIndex = index;
                      });
                      _updateTooltip(index);
                    },
                    onTapUp: (_) {
                      setState(() {
                        _selectedBarIndex = null;
                      });
                      _clearTooltip();
                    },
                    onTapCancel: () {
                      setState(() {
                        _selectedBarIndex = null;
                      });
                      _clearTooltip();
                    },
                    child: _buildGithubCell(index, widget.weeklyProgress[index], cellSize, isSelected: _selectedBarIndex == index),
                  );
                } else {
                  return SizedBox(width: cellSize, height: cellSize);
                }
              }),
            );
          }),
        );
      }
    );
  }

  // 构建GitHub风格的单元格
  Widget _buildGithubCell(int index, double progress, double size, {bool isSelected = false}) {
    // 根据进度值确定颜色深浅
    Color cellColor;
    if (progress <= 0.1) {
      cellColor = Colors.grey[300]!;  // 最浅的灰色
    } else if (progress <= 0.3) {
      cellColor = Colors.grey[400]!;  // 稍深一点
    } else if (progress <= 0.6) {
      cellColor = Colors.grey[600]!;  // 中等深度的灰色
    } else {
      cellColor = Colors.grey[800]!;  // 最深的灰色，接近黑色
    }
    
    return Container(
      width: size - 4,
      height: size - 4,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.teal[400] : cellColor,
        borderRadius: BorderRadius.circular(4),
        border: isSelected ? Border.all(color: Colors.blueGrey.shade700, width: 2) : null,
      ),
    );
  }

  // 构建单个柱状图
  Widget _buildBar(int index, double progress, {bool isSelected = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 背景柱
          Container(
            width: 14,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          // 进度柱
          Container(
            width: 14,
            height: 140 * progress,
            decoration: BoxDecoration(
              color: isSelected ? Colors.teal[400] : Colors.black,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
} 