import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';

final class ExampleStorageException implements Exception {
  const ExampleStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Persisted catalog choice plus the integer speaker id for that pack.
final class ExampleSelection {
  const ExampleSelection({required this.catalogId, required this.speakerId});

  final String catalogId;
  final int speakerId;
}

class ExampleModelStorage {
  ExampleModelStorage({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'local_voice_example/storage';
  static const _selectionFile = 'selection.json';

  final MethodChannel _channel;
  String? _root;

  Future<String> rootDirectory() async {
    final cached = _root;
    if (cached != null) return cached;
    try {
      final root = await _channel.invokeMethod<String>('getModelRoot');
      if (root == null || root.trim().isEmpty) {
        throw const ExampleStorageException(
          'Private model storage is unavailable. Restart the app and try again.',
        );
      }
      _root = root;
      return root;
    } on PlatformException {
      throw const ExampleStorageException(
        'Private model storage could not be opened. Check available device storage and try again.',
      );
    }
  }

  Future<int> availableBytes() async {
    try {
      final value = await _channel.invokeMethod<int>('availableBytes');
      if (value == null || value < 0) {
        throw const ExampleStorageException(
          'Available device storage could not be measured. Free some space and try again.',
        );
      }
      return value;
    } on PlatformException {
      throw const ExampleStorageException(
        'Available device storage could not be measured. Free some space and try again.',
      );
    }
  }

  Future<String> optionDirectory(VoiceModelOption option) async {
    _requireCatalogOption(option);
    return '${await rootDirectory()}${Platform.pathSeparator}${option.id}';
  }

  /// Advisory only: the preparation manager still verifies every candidate.
  Future<bool> hasInstalledCandidate(VoiceModelOption option) async {
    final root = Directory(await optionDirectory(option));
    try {
      if (!await root.exists()) return false;
      await for (final entity in root.list(followLinks: false)) {
        if (entity is Directory &&
            entity.path
                .split(Platform.pathSeparator)
                .last
                .startsWith('bundle-')) {
          return true;
        }
      }
      return false;
    } on FileSystemException {
      throw const ExampleStorageException(
        'Installed model files could not be inspected. Check device storage and try again.',
      );
    }
  }

  Future<ExampleSelection?> readSelection() async {
    final file = File(
      '${await rootDirectory()}${Platform.pathSeparator}$_selectionFile',
    );
    try {
      if (!await file.exists()) return null;
      final value = jsonDecode(await file.readAsString());
      if (value is! Map || value['catalogId'] is! String) {
        throw const FormatException('Invalid selection document.');
      }
      return ExampleSelection(
        catalogId: value['catalogId'] as String,
        speakerId: _speakerIdFromDocument(value),
      );
    } on FileSystemException {
      throw const ExampleStorageException(
        'The saved model selection could not be read. Choose a model to repair setup.',
      );
    } on FormatException {
      throw const ExampleStorageException(
        'The saved model selection is damaged. Choose a model to repair setup.',
      );
    }
  }

  Future<void> writeSelection(
    VoiceModelOption option, {
    int speakerId = 0,
  }) async {
    _requireCatalogOption(option);
    final root = await rootDirectory();
    final destination = File('$root${Platform.pathSeparator}$_selectionFile');
    final temporary = File(
      '$root${Platform.pathSeparator}.$_selectionFile.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temporary.writeAsString(
        jsonEncode(<String, Object>{
          'catalogId': option.id,
          'speakerId': speakerId,
        }),
        flush: true,
      );
      await temporary.rename(destination.path);
    } on FileSystemException {
      try {
        if (await temporary.exists()) await temporary.delete();
      } on FileSystemException {
        // Preserve the original storage error.
      }
      throw const ExampleStorageException(
        'The selected model is ready, but its offline selection could not be saved. Check device storage and try again.',
      );
    }
  }

  Future<void> deleteOption(VoiceModelOption option) async {
    _requireCatalogOption(option);
    final directory = Directory(await optionDirectory(option));
    final selection = File(
      '${await rootDirectory()}${Platform.pathSeparator}$_selectionFile',
    );
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
      if (await selection.exists()) {
        final selected = await readSelection();
        if (selected?.catalogId == option.id) await selection.delete();
      }
    } on FileSystemException {
      throw const ExampleStorageException(
        'The damaged model copy could not be removed. Restart the app and try again.',
      );
    }
  }

  /// Absent speakerId is the LJS missing-field fallback (0). Out-of-range
  /// non-negative ids are retained so Start can refuse them later.
  int _speakerIdFromDocument(Map<dynamic, dynamic> value) {
    if (!value.containsKey('speakerId')) {
      return 0;
    }
    final speakerId = value['speakerId'];
    if (speakerId is! int || speakerId < 0) {
      throw const FormatException('Invalid selection document.');
    }
    return speakerId;
  }

  void _requireCatalogOption(VoiceModelOption option) {
    if (!VoiceModelCatalog.entries.any(
      (candidate) => identical(candidate, option) || candidate.id == option.id,
    )) {
      throw const ExampleStorageException(
        'The selected model is not part of this app catalog.',
      );
    }
  }
}
