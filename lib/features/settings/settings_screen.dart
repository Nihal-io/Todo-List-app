import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: const Center(
        child: Text(
          'Settings',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF9090A8),
          ),
        ),
      ),
    );
  }
}
