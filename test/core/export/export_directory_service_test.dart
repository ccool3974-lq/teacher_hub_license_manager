import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_hub_license_manager/core/export/export_directory_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'teacher_hub_license_manager_export_dir_test_',
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('service saves, loads, and resets custom export directory', () async {
    final ExportDirectoryService service = ExportDirectoryService(
      documentsDirectoryResolver: () async => tempDirectory,
    );

    final Directory defaultDirectory = await service.getExportDirectory();
    expect(defaultDirectory.path, endsWith(r'exports\licenses'));

    final Directory customDirectory = Directory(
      '${tempDirectory.path}\\custom_exports',
    );
    await service.saveExportDirectory(customDirectory.path);

    final Directory savedDirectory = await service.getExportDirectory();
    expect(savedDirectory.path, customDirectory.path);

    await service.resetToDefaultDirectory();
    final Directory resetDirectory = await service.getExportDirectory();
    expect(resetDirectory.path, defaultDirectory.path);
  });
}
