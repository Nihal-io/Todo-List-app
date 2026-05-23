import 'package:flutter/material.dart';

class MatrixScreen extends StatelessWidget {
  const MatrixScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Matrix'),
      ),
      body: const Center(
        child: Text(
          'Matrix',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF9090A8),
          ),
        ),
      ),
    );
  }
}
