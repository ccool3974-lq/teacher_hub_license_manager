import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

typedef KeyFilePicker = Future<FilePickerResult?> Function();

class PrivateKeyStorageService {
  PrivateKeyStorageService({
    Future<Directory> Function()? documentsDirectoryResolver,
    KeyFilePicker? filePicker,
  })  : _documentsDirectoryResolver = documentsDirectoryResolver,
        _filePicker = filePicker;

  final Future<Directory> Function()? _documentsDirectoryResolver;
  final KeyFilePicker? _filePicker;

  Future<File?> getStoredKeyFile() async {
    final File file = await _getStorageFile();
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  Future<bool> hasStoredKey() async {
    return (await getStoredKeyFile()) != null;
  }

  Future<File?> importKeyFromPicker() async {
    final FilePickerResult? result = await (_filePicker?.call() ??
        FilePicker.platform.pickFiles(
          dialogTitle: '选择私钥文件',
          lockParentWindow: true,
        ));
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final String? sourcePath = result.files.single.path;
    if (sourcePath == null || sourcePath.trim().isEmpty) {
      throw StateError('未能读取所选私钥文件路径。');
    }

    return importKeyFile(File(sourcePath));
  }

  Future<File> importKeyFile(File sourceFile) async {
    if (!await sourceFile.exists()) {
      throw StateError('未找到私钥文件：${sourceFile.path}');
    }

    final String content = await sourceFile.readAsString();
    final String normalized = content.trim();
    if (normalized.isEmpty) {
      throw StateError('私钥文件内容为空。');
    }

    final File targetFile = await _getStorageFile();
    await targetFile.parent.create(recursive: true);
    await targetFile.writeAsString(normalized, flush: true);
    return targetFile;
  }

  Future<void> clearStoredKey() async {
    final File file = await _getStorageFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<File> _getStorageFile() async {
    final Directory documentsDirectory =
        await (_documentsDirectoryResolver?.call() ??
            getApplicationDocumentsDirectory());
    return File(
      path.join(
        documentsDirectory.path,
        'settings',
        'license_private_key.seed',
      ),
    );
  }
}
