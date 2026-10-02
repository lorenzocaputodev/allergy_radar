import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path_provider/path_provider.dart';

enum FileResult { saved, cancelled, unsupported }

class FileService {
  static bool get _isWindows => !kIsWeb && Platform.isWindows;
  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  static bool get isSupported => _isWindows || _isAndroid;

  static Future<FileResult> saveText(String fileName, String content, {required String mime}) =>
      saveBytes(fileName, utf8.encode(content), mime: mime);

  static Future<FileResult> saveBytes(String fileName, List<int> bytes, {required String mime}) async {
    final ext = fileName.split('.').last;
    if (_isWindows) {
      final location = await getSaveLocation(
        suggestedName: fileName,
        initialDirectory: (await getApplicationDocumentsDirectory()).path,
        acceptedTypeGroups: [
          XTypeGroup(label: ext.toUpperCase(), extensions: [ext], mimeTypes: [mime]),
        ],
      );
      if (location == null) return FileResult.cancelled;
      await File(location.path).writeAsBytes(bytes, flush: true);
      return FileResult.saved;
    }
    if (_isAndroid) {
      final temp = File('${(await getTemporaryDirectory()).path}${Platform.pathSeparator}$fileName');
      try {
        await temp.writeAsBytes(bytes, flush: true);
        final saved = await FlutterFileDialog.saveFile(
          params: SaveFileDialogParams(
            sourceFilePath: temp.path,
            fileName: fileName,
            mimeTypesFilter: [mime],
            localOnly: true,
          ),
        );
        return saved == null || saved.trim().isEmpty ? FileResult.cancelled : FileResult.saved;
      } finally {
        if (await temp.exists()) await temp.delete();
      }
    }
    return FileResult.unsupported;
  }

  static Future<String?> openText({required List<String> extensions, required List<String> mimes}) async {
    if (_isWindows) {
      final file = await openFile(
        acceptedTypeGroups: [XTypeGroup(extensions: extensions, mimeTypes: mimes)],
      );
      return file?.readAsString();
    }
    if (_isAndroid) {
      final path = await FlutterFileDialog.pickFile(
        params: const OpenFileDialogParams(localOnly: true, copyFileToCacheDir: true),
      );
      if (path == null || path.trim().isEmpty) return null;
      return File(path).readAsString(encoding: utf8);
    }
    return null;
  }
}
