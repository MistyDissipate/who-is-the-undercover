import 'package:flutter/material.dart';

class HostScreen extends StatelessWidget {
  const HostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('游戏')),
      body: Center(child: Text('游戏主持页')),
    );
  }
}