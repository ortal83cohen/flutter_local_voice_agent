import 'package:flutter/material.dart';

void main() {
  runApp(const SkeletonApp());
}

class SkeletonApp extends StatelessWidget {
  const SkeletonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'library_name example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const SkeletonHomePage(),
    );
  }
}

class SkeletonHomePage extends StatelessWidget {
  const SkeletonHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('{שם הספריה}')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '{שם הספריה}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text('Replace this page with the first screen of your app.'),
            ],
          ),
        ),
      ),
    );
  }
}