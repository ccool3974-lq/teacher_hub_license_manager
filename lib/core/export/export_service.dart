import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:teacher_hub_license_manager/core/export/export_directory_service.dart';

class ExportService {
  ExportService({
    ExportDirectoryService? exportDirectoryService,
  }) : _exportDirectoryService =
            exportDirectoryService ?? ExportDirectoryService();

  final ExportDirectoryService _exportDirectoryService;

  Future<File> writeTextFile({
    required String fileName,
    required String content,
  }) async {
    final File file = await _prepareFile(fileName);
    await file.writeAsString(content, flush: true);
    return file;
  }

  Future<File> writeBytesFile({
    required String fileName,
    required List<int> bytes,
  }) async {
    final File file = await _prepareFile(fileName);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<File> _prepareFile(String fileName) async {
    final Directory exportDirectory =
        await _exportDirectoryService.getExportDirectory();
    if (!await exportDirectory.exists()) {
      await exportDirectory.create(recursive: true);
    }
    return File(path.join(exportDirectory.path, fileName));
  }
}
