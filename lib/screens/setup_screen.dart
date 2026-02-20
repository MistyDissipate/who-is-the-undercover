import 'package:flutter/material.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('设置')),
      body: ElevatedButton(
        onPressed: () {
          Navigator.pushNamed(context, '/host');
        },
        child: Text('开始游戏（测试跳转）'),
      )
    );
  }
}