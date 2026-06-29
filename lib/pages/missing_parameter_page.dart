import 'package:flutter/material.dart';

class MissingParameterPage extends StatelessWidget {
  final String parameterName;

  const MissingParameterPage({super.key, required this.parameterName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('خطأ')),
      body: Center(
        child: Text('المعامل "$parameterName" مفقود'),
      ),
    );
  }
}
