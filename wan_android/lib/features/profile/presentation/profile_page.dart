import 'package:flutter/material.dart';

/// 我的页。M8 接入登录鉴权后，这里展示用户信息；M9/M10 加收藏、订单入口。现在先占位。
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: const Center(
        child: Text('我的 · 建设中', style: TextStyle(fontSize: 20)),
      ),
    );
  }
}
