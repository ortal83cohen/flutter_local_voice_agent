import 'dart:io';

import 'models.dart';

/// Resolves validated model files to filesystem paths for native create.
Future<Map<String, String>> nativeModelPathMap(
  ValidatedModelBundle checked,
  LocalModelBundle models,
) async {
  final root = await Directory(models.directory).resolveSymbolicLinks();
  return <String, String>{
    for (final entry in checked.files.where((entry) => entry.role != 'license'))
      entry.role: '$root${Platform.pathSeparator}${entry.path}',
  };
}
