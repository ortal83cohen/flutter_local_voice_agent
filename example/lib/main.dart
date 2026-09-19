import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';

void main() => runApp(const VoiceExample());

/// Foreground demonstration using a model pack already present on the device.
class VoiceExample extends StatelessWidget {
  /// Creates the example application.
  const VoiceExample({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Local voice',
    theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
    home: const VoiceScreen(),
  );
}

/// Controls one locally provisioned, half-duplex conversation.
class VoiceScreen extends StatefulWidget {
  /// Creates the conversation screen.
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> with WidgetsBindingObserver {
  final _directory = TextEditingController(
    text: const String.fromEnvironment('MODEL_DIRECTORY'),
  );
  LocalVoiceAgent? _agent;
  StreamSubscription<AgentEvent>? _subscription;
  bool _busy = false;
  String _status = 'Choose a local model folder to begin.';
  String _heard = '';
  String _reply = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      if (mounted) setState(() => _status = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    await _subscription?.cancel();
    await _agent?.dispose();
    _agent = null;
    final directory = _directory.text.trim();
    final agent = await LocalVoiceAgent.create(
      models: LocalModelBundle(
        directory: directory,
        manifestPath: '$directory/manifest.json',
      ),
      logic: (text) async {
        final command = text.toLowerCase();
        if (command.contains('hello')) return 'Hello. How are you?';
        if (command.contains('name')) return 'My name is local voice.';
        if (command.contains('thank')) return 'You are welcome.';
        return 'I heard you. Please say hello.';
      },
    );
    if (!mounted) {
      await agent.dispose();
      return;
    }
    _agent = agent;
    _subscription = agent.events.listen(
      (event) {
        if (!mounted) return;
        setState(() {
          _status = '${event.lifecycle.name} · ${event.activity.name}';
          if (event.kind == AgentEventKind.partialTranscript ||
              event.kind == AgentEventKind.finalTranscript) {
            _heard = event.text ?? '';
          }
          if (event.kind == AgentEventKind.replyText) _reply = event.text ?? '';
          if (event.failure != null) _status = event.failure.toString();
        });
      },
      onError: (Object error) {
        if (mounted) setState(() => _status = error.toString());
      },
    );
    setState(
      () => _status = 'Models loaded. Tap Start and allow the microphone.',
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(
        _agent?.stop().catchError((Object _) {}) ?? Future<void>.value(),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    unawaited(_agent?.dispose());
    _directory.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Local voice')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'A conversation on your device',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'Speech stays on this device. Supply a local model pack before starting. Listening pauses while a reply plays.',
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _directory,
            decoration: const InputDecoration(
              labelText: 'Local model folder',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : () => _run(_load),
            child: const Text('Load models'),
          ),
          const SizedBox(height: 24),
          Semantics(liveRegion: true, child: Text(_status)),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: [
              FilledButton(
                onPressed: _agent == null || _busy
                    ? null
                    : () => _run(() => _agent!.start()),
                child: const Text('Start'),
              ),
              OutlinedButton(
                onPressed: _agent == null || _busy
                    ? null
                    : () => _run(() => _agent!.interrupt()),
                child: const Text('Interrupt'),
              ),
              OutlinedButton(
                onPressed: _agent == null || _busy
                    ? null
                    : () => _run(() => _agent!.stop()),
                child: const Text('Stop'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('You said', style: Theme.of(context).textTheme.titleMedium),
          SelectableText(_heard),
          const SizedBox(height: 24),
          Text('Reply', style: Theme.of(context).textTheme.titleMedium),
          SelectableText(_reply),
        ],
      ),
    ),
  );
}
