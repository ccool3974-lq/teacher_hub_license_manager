import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

typedef DirectoryOpener = Future<void> Function(String path);
typedef DirectoryPicker = Future<String?> Function();

class ExportDirectoryService {
  ExportDirectoryService({
    Future<Directory> Function()? documentsDirectoryResolver,
    DirectoryOpener? directoryOpener,
    DirectoryPicker? directoryPicker,
  })  : _documentsDirectoryResolver = documentsDirectoryResolver,
        _directoryOpener = directoryOpener,
        _directoryPicker = directoryPicker;

  final Future<Directory> Function()? _documentsDirectoryResolver;
  final DirectoryOpener? _directoryOpener;
  final DirectoryPicker? _directoryPicker;

  Future<Directory> getExportDirectory() async {
    final File settingsFile = await _getSettingsFile();
    if (await settingsFile.exists()) {
      final String storedPath = (await settingsFile.readAsString()).trim();
      if (storedPath.isNotEmpty) {
        final Directory customDirectory = Directory(storedPath);
        if (!await customDirectory.exists()) {
          await customDirectory.create(recursive: true);
        }
        return customDirectory;
      }
    }

    final Directory defaultDirectory = await getDefaultExportDirectory();
    if (!await defaultDirectory.exists()) {
      await defaultDirectory.create(recursive: true);
    }
    return defaultDirectory;
  }

  Future<Directory> getDefaultExportDirectory() async {
    final Directory documentsDirectory =
        await (_documentsDirectoryResolver?.call() ??
            getApplicationDocumentsDirectory());
    return Directory(path.join(documentsDirectory.path, 'exports', 'licenses'));
  }

  Future<String?> pickDirectoryPath() async {
    if (_directoryPicker != null) {
      return _directoryPicker();
    }

    return FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择导出目录',
      lockParentWindow: true,
    );
  }

  Future<void> saveExportDirectory(String directoryPath) async {
    final String trimmedPath = directoryPath.trim();
    if (trimmedPath.isEmpty) {
      throw ArgumentError('导出目录不能为空');
    }

    final Directory directory = Directory(trimmedPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final File settingsFile = await _getSettingsFile();
    await settingsFile.parent.create(recursive: true);
    await settingsFile.writeAsString(trimmedPath, flush: true);
  }

  Future<void> resetToDefaultDirectory() async {
    final File settingsFile = await _getSettingsFile();
    if (await settingsFile.exists()) {
      await settingsFile.delete();
    }
  }

  Future<void> openExportDirectory() async {
    final Directory directory = await getExportDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    if (_directoryOpener != null) {
      await _directoryOpener(directory.path);
      return;
    }

    if (Platform.isWindows) {
      await Process.start('explorer', <String>[directory.path]);
      return;
    }
    if (Platform.isMacOS) {
      await Process.start('open', <String>[directory.path]);
      return;
    }
    if (Platform.isLinux) {
      await Process.start('xdg-open', <String>[directory.path]);
      return;
    }

    throw UnsupportedError('当前平台暂不支持直接打开导出目录');
  }

  Future<File> _getSettingsFile() async {
    final Directory documentsDirectory =
        await (_documentsDirectoryResolver?.call() ??
            getApplicationDocumentsDirectory());
    return File(
      path.join(
        documentsDirectory.path,
        'settings',
        'license_manager_export_directory.txt',
      ),
    );
  }
}
