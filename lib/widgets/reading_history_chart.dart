import 'package:flutter/material.dart';

class ReadingHistoryChart extends StatelessWidget {
  final List<double> weeklyProgress; // 过去七天的阅读进度

  const ReadingHistoryChart({
    super.key,
    required this.weeklyProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (index) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // 背景柱
                      Container(
                        width: 8,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      // 进度柱
                      Container(
                        width: 8,
                        height: 120 * weeklyProgress[index],
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getDayText(index),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  String _getDayText(int index) {
    final days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return days[index];
  }
} 