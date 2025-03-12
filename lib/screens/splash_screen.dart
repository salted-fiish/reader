import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isFirstLaunch = true;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    // 创建动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    // 创建淡入/淡出动画
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // 启动淡入动画
    _animationController.forward();

    // 检查是否是首次启动
    _checkFirstLaunch();

    // 2.5秒后触发淡出动画，并在动画结束后跳转
    _navigationTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _startFadeOutAnimation();
      }
    });
  }

  void _startFadeOutAnimation() {
    // 开始淡出动画
    _animationController.reverse().then((_) {
      if (mounted) {
        // 动画完成后进行导航
        Navigator.pushReplacementNamed(
          context, 
          _isFirstLaunch ? '/' : '/home',
        );
      }
    });
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isFirstLaunch = prefs.getBool('first_launch') ?? true;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 30),
            // 应用名称淡入+淡出
            FadeTransition(
              opacity: _animation,
              child: const Text(
                'The most elegant reading app',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3A3A),
                ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
