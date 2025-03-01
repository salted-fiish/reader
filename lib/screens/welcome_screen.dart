import 'package:flutter/material.dart';
import 'dart:math';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final List<Map<String, String>> _quotes = [
    {
      'quote': '读书是在别人思想的帮助下，建立自己的思想。',
      'author': '尼古拉·鲁巴金'
    },
    {
      'quote': '书籍是人类知识的总结，是人类进步的阶梯。',
      'author': '高尔基'
    },
    {
      'quote': '读一本好书，就是和许多高尚的人谈话。',
      'author': '笛卡尔'
    },
    {
      'quote': '书籍是朋友，虽然没有热情，但是非常忠实。',
      'author': '雨果'
    },
    {
      'quote': '读书破万卷，下笔如有神。',
      'author': '杜甫'
    },
    {
      'quote': '读书有三到：心到、眼到、口到。',
      'author': '朱熹'
    },
    {
      'quote': '黑发不知勤学早，白首方悔读书迟。',
      'author': '颜真卿'
    },
    {
      'quote': '书到用时方恨少，事非经过不知难。',
      'author': '陆游'
    },
  ];

  late Map<String, String> _currentQuote;
  double _slideValue = 0.08;
  bool _canNavigate = false;

  @override
  void initState() {
    super.initState();
    _currentQuote = _quotes[Random().nextInt(_quotes.length)];
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              
              // 名人名言
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Color(0xFF2C2C2C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _currentQuote['quote']!,
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.5,
                          color: Color(0xFF2C2C2C),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '— ${_currentQuote['author']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF2C2C2C).withOpacity(0.7),
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
              ),
              
              const Spacer(flex: 3),
              
              // 滑动交互
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    // 自定义滑动条容器
                    Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: Color(0xFF2C2C2C).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Stack(
                        children: [
                          // 1. 底层：文字
                          Center(
                            child: IgnorePointer(
                              ignoring: true,
                              child: Text(
                                '开始阅读',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF2C2C2C).withOpacity(0.7),
                                ),
                              ),
                            ),
                          ),

                          // 2. 中间层：进度条
                          Builder(builder: (context) {
                            final containerWidth = MediaQuery.of(context).size.width - 80;
                            const double progressBarHeight = 50;
                            const double horizontalMargin = 5.0; // 左右内边距
                            final availableWidth = containerWidth - 2 * horizontalMargin;
                            final progressWidth = availableWidth * _slideValue;
                            return Positioned(
                              left: horizontalMargin,
                              top: (60 - progressBarHeight) / 2, // 60 为外层容器高度
                              child: Container(
                                height: progressBarHeight,
                                width: progressWidth,
                                // 如果要彻底遮住文字，可以把 withOpacity(0.3) 改成 1.0
                                decoration: BoxDecoration(
                                  color: Color(0xFF2C2C2C).withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            );
                          }),

                          // 3. 顶层：滑块
                          SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 60,
                              activeTrackColor: Colors.transparent,
                              inactiveTrackColor: Colors.transparent,
                              thumbColor: Color(0xFF2C2C2C),
                              thumbShape: CustomSliderThumbRect(
                                thumbHeight: 50,
                                thumbWidth: 50,
                                iconData: Icons.arrow_forward,
                              ),
                              overlayShape: SliderComponentShape.noOverlay,
                              trackShape: CustomTrackShape(),
                            ),
                            child: Slider(
                              min: 0.08, // 设定最小值
                              max: 1.0,
                              value: _slideValue,
                              onChanged: (value) {
                                setState(() {
                                  _slideValue = value;
                                  _canNavigate = value >= 0.88;
                                });
                              },
                              onChangeEnd: (value) {
                                if (_canNavigate) {
                                  Navigator.pushReplacementNamed(context, '/home');
                                } else {
                                  // 如果未触发导航，重置进度条为初始值
                                  setState(() {
                                    _slideValue = 0.08;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

// 自定义滑块形状
class CustomSliderThumbRect extends SliderComponentShape {
  final double thumbHeight;
  final double thumbWidth;
  final IconData iconData;

  const CustomSliderThumbRect({
    required this.thumbHeight,
    required this.thumbWidth,
    required this.iconData,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(thumbWidth, thumbHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    // 绘制圆角矩形滑块
    final paint = Paint()
      ..color = const Color(0xFF2C2C2C)
      ..style = PaintingStyle.fill;

    final RRect roundedRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center, 
        width: thumbWidth, 
        height: thumbHeight
      ),
      const Radius.circular(15),
    );
    
    canvas.drawRRect(roundedRect, paint);

    // 绘制图标
    final iconSize = thumbWidth * 0.5;
    final textSpan = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: iconSize,
        fontFamily: iconData.fontFamily,
        color: Colors.white,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final iconOffset = Offset(
      center.dx - textPainter.width / 2,
      center.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, iconOffset);
  }
}

// 自定义轨道形状，使滑块紧贴左侧
class CustomTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 0;
    final double trackLeft = offset.dx;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
} 