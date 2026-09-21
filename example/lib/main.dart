import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';

import 'voice_screen_controller.dart';

void main() => runApp(const VoiceExample());

class VoiceExample extends StatelessWidget {
  const VoiceExample({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Local voice catalog',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorSchemeSeed: const Color(0xff4458a7),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: const VoiceScreen(),
  );
}

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key, this.controller});

  final VoiceScreenController? controller;

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> with WidgetsBindingObserver {
  late final VoiceScreenController _controller =
      widget.controller ?? VoiceScreenController.production();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_refresh);
    unawaited(_controller.initialize());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _controller.onResume();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _controller.onBackground();
      case AppLifecycleState.inactive:
        // Permission prompts and temporary focus loss must not invalidate Start.
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_refresh);
    unawaited(_controller.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final selected = controller.selected;
    final progress = controller.progress;
    return Scaffold(
      appBar: AppBar(title: const Text('Local voice')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              'Choose a voice for this device',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Three English options are available. The LJS packs differ by precision. VCTK is a speaker choice by integer id. Download once, then speech recognition and playback run offline. Listening pauses while a reply plays.',
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<VoiceModelOption>(
              key: ValueKey('model-picker-${selected?.id ?? 'none'}'),
              initialValue: selected,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'English voice model',
              ),
              items: controller.catalog
                  .map(
                    (option) => DropdownMenuItem(
                      value: option,
                      child: Text(
                        option.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: controller.operationBusy
                  ? null
                  : (option) => unawaited(controller.select(option)),
            ),
            if (controller.showsSpeakerControl) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey(
                  'speaker-picker-${selected?.id ?? 'none'}-${controller.speakerId}',
                ),
                initialValue:
                    controller.speakerIds.contains(controller.speakerId)
                    ? controller.speakerId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Speaker'),
                items: controller.speakerIds
                    .map(
                      (id) => DropdownMenuItem(value: id, child: Text('$id')),
                    )
                    .toList(),
                onChanged: controller.operationBusy
                    ? null
                    : (id) {
                        if (id != null) {
                          unawaited(controller.setSpeakerId(id));
                        }
                      },
              ),
            ],
            if (selected != null) ...[
              const SizedBox(height: 12),
              Card.filled(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${selected.language} • ${_downloadSize(selected.downloadBytes)} download',
                      ),
                      const SizedBox(height: 8),
                      Text(selected.description),
                      if (controller.phase == ExampleSetupPhase.ready) ...[
                        const SizedBox(height: 10),
                        const Chip(
                          avatar: Icon(Icons.verified, size: 18),
                          label: Text('Installed and verified'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(controller.status, key: const Key('status')),
            ),
            if (_showsTransferProgress(controller.phase) &&
                progress != null) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                key: const Key('download-progress'),
                value: progress.totalBytes > 0
                    ? (progress.receivedBytes / progress.totalBytes).clamp(0, 1)
                    : null,
              ),
              const SizedBox(height: 6),
              Text(
                '${_downloadSize(progress.receivedBytes)} of ${_downloadSize(progress.totalBytes)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else if (controller.operationBusy) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const Key('prepare-button'),
                  onPressed: controller.canPrepare
                      ? () => unawaited(controller.downloadAndPrepare())
                      : null,
                  icon: const Icon(Icons.download),
                  label: Text(
                    controller.phase == ExampleSetupPhase.failed
                        ? 'Retry download'
                        : 'Download and prepare',
                  ),
                ),
                if (controller.canCancel)
                  OutlinedButton(
                    key: const Key('cancel-button'),
                    onPressed: controller.cancelPreparation,
                    child: const Text('Cancel'),
                  ),
                if (controller.allowRepairRemoval)
                  OutlinedButton.icon(
                    key: const Key('remove-copy-button'),
                    onPressed: controller.operationBusy
                        ? null
                        : () => unawaited(controller.removeDamagedCopy()),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove damaged copy'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const _DisclosureCard(),
            const SizedBox(height: 20),
            Text('Conversation', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(
              'Replies are fixed demo rules, not an LLM. Try “hello”, “what is your name?”, or “thank you”.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  key: const Key('start-button'),
                  onPressed: controller.canStart && !controller.operationBusy
                      ? () => unawaited(controller.start())
                      : null,
                  child: const Text('Start'),
                ),
                OutlinedButton(
                  key: const Key('interrupt-button'),
                  onPressed: controller.hasSession && !controller.operationBusy
                      ? () => unawaited(controller.interrupt())
                      : null,
                  child: const Text('Interrupt'),
                ),
                OutlinedButton(
                  key: const Key('stop-button'),
                  onPressed: controller.hasSession && !controller.operationBusy
                      ? () => unawaited(controller.stop())
                      : null,
                  child: const Text('Stop'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _TranscriptCard(
              title: 'You said',
              value: controller.heard,
              placeholder: 'Your partial and final transcript appears here.',
            ),
            const SizedBox(height: 12),
            _TranscriptCard(
              title: 'Local reply',
              value: controller.reply,
              placeholder: 'The fixed local demo reply appears here.',
            ),
          ],
        ),
      ),
    );
  }
}

class _DisclosureCard extends StatelessWidget {
  const _DisclosureCard();

  @override
  Widget build(BuildContext context) => const Card.outlined(
    child: ExpansionTile(
      dense: true,
      title: Text('Files, sources, and licenses'),
      childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'The catalog pins each source, file size, and checksum. License records download with the model. Preparation needs internet; conversations do not.',
        ),
      ],
    ),
  );
}

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({
    required this.title,
    required this.value,
    required this.placeholder,
  });

  final String title;
  final String value;
  final String placeholder;

  @override
  Widget build(BuildContext context) => Card.outlined(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          SelectableText(value.isEmpty ? placeholder : value),
        ],
      ),
    ),
  );
}

String _downloadSize(int bytes) {
  final megabytes = bytes / 1000000;
  return '${megabytes.toStringAsFixed(1)} MB';
}

bool _showsTransferProgress(ExampleSetupPhase phase) =>
    phase == ExampleSetupPhase.checking ||
    phase == ExampleSetupPhase.downloading ||
    phase == ExampleSetupPhase.verifying;
