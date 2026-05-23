import 'package:flutter/material.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
      ),
      body: const Center(
        child: Text(
          'Today',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF9090A8),
          ),
        ),
      ),
    );
  }
}
