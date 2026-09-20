// Explicit opt-in real catalog download and offline-cache verification.
// Run with the package's Dart SDK: dart run tool/verify_catalog.dart OUTPUT_ROOT
import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_voice_agent/src/model_catalog.dart';
import 'package:flutter_local_voice_agent/src/model_preparation.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run tool/verify_catalog.dart OUTPUT_ROOT');
    exitCode = 64;
    return;
  }
  final root = Directory(args.single);
  await root.create(recursive: true);
  final results = <Map<String, Object>>[];
  for (final option in VoiceModelCatalog.entries) {
    stdout.writeln('Prepare ${option.id}: ${option.downloadBytes} bytes');
    final path = '${root.path}/${option.id}';
    final bundle = await ModelPreparationManager(
      rootDirectory: path,
      maxRedirects: 5,
      allowedRedirectOrigins: option.allowedRedirectOrigins,
    ).prepare(option.descriptor).result;
    var networkClients = 0;
    final offline = await ModelPreparationManager(
      rootDirectory: path,
      httpClientFactory: () {
        networkClients++;
        throw StateError('Offline verification must not construct a client.');
      },
    ).prepare(option.descriptor).result;
    if (networkClients != 0 || offline.directory != bundle.directory) {
      throw StateError('Offline cache verification failed.');
    }
    results.add({
      'id': option.id,
      'directory': bundle.directory,
      'manifestPath': bundle.manifestPath,
      'paths': {
        for (final file in option.descriptor.files)
          if (file.entry.role != 'license')
            file.entry.role: '${bundle.directory}/${file.entry.path}',
      },
    });
    stdout.writeln(
      'PASS ${option.id}: verified payload, manifest and zero-client offline reuse',
    );
  }
  await File('${root.path}/verification.json')
      .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
}
