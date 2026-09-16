import 'dart:async';

import 'package:flutter/material.dart';

void main() {
  runApp(const SplitFlapDisplayApp());
}

class SplitFlapDisplayApp extends StatelessWidget {
  const SplitFlapDisplayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Split Flap Display',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xfff5a623),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff11100e),
        useMaterial3: true,
      ),
      home: const DisplayPage(),
    );
  }
}

class DisplayPage extends StatefulWidget {
  const DisplayPage({super.key});

  @override
  State<DisplayPage> createState() => _DisplayPageState();
}

class _DisplayPageState extends State<DisplayPage> {
  static const _messages = <String>[
    'HELLO WORLD',
    'SPLIT FLAP',
    'FLUTTER LAB',
  ];

  Timer? _timer;
  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      setState(() {
        _messageIndex = (_messageIndex + 1) % _messages.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Flap Display'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'A mechanical idea, animated in Flutter',
                style: TextStyle(color: Colors.white60, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SplitFlapText(text: _messages[_messageIndex]),
              const SizedBox(height: 28),
              const Text(
                'Each tile rotates through its character sequence, inspired by the hinged flaps of a real airport display.',
                style: TextStyle(color: Colors.white54, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SplitFlapText extends StatelessWidget {
  const SplitFlapText({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 5,
      runSpacing: 8,
      children: [
        for (var index = 0; index < text.length; index++)
          SplitFlapTile(
            key: ValueKey('$index-${text[index]}'),
            character: text[index],
          ),
      ],
    );
  }
}

class SplitFlapTile extends StatefulWidget {
  const SplitFlapTile({required this.character, super.key});

  final String character;

  @override
  State<SplitFlapTile> createState() => _SplitFlapTileState();
}

class _SplitFlapTileState extends State<SplitFlapTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = (1 - _controller.value) * 1.5708;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateX(angle),
          child: child,
        );
      },
      child: SizedBox(
        width: 42,
        height: 58,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xff252321),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xff514a42)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.character,
              style: const TextStyle(
                color: Color(0xffffb84d),
                fontSize: 30,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    );
  }
}