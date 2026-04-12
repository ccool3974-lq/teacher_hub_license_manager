import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:teacher_hub_license_manager/core/export/export_directory_service.dart';
import 'package:teacher_hub_license_manager/core/export/export_service.dart';
import 'package:teacher_hub_license_manager/core/storage/db_helper.dart';
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_entity.dart';
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_repository.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_export_service.dart';
import 'package:teacher_toolkit_license_protocol/teacher_toolkit_license_protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late LicenseRecordRepository repository;

  setUp(() async {
    sqfliteFfiInit();
    tempDirectory = await Directory.systemTemp.createTemp(
      'teacher_hub_license_manager_export_test_',
    );
    await DbHelper.configureForTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: '${tempDirectory.path}\\license_manager_export.db',
    );
    repository = const LicenseRecordRepository();
  });

  tearDown(() async {
    await DbHelper.resetTestingOverrides();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('export service writes record text and xlsx files', () async {
    final DateTime now = DateTime.utc(2026, 4, 2, 12, 0);
    final LicenseRecordEntity record = await repository.insert(
      LicenseRecordEntity(
        licenseId: 'LIC-2026-0001',
        bindName: 'Zhang',
        bindUserCode: 'T001',
        tier: LicenseTier.basic,
        durationDays: 180,
        permanent: false,
        issuedAt: now,
        activationDeadline: now.add(const Duration(days: 30)),
        operatorName: 'AdminA',
        remark: 'Initial issue',
        rawLicense: 'TTK2.payload.signature',
        status: LicenseRecordStatus.active,
        exportedAt: null,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final ExportDirectoryService directoryService = ExportDirectoryService(
      documentsDirectoryResolver: () async => tempDirectory,
    );
    final LicenseExportService exportService = LicenseExportService(
      exportService: ExportService(exportDirectoryService: directoryService),
      exportDirectoryService: directoryService,
      repository: repository,
      now: () => now.add(const Duration(minutes: 5)),
    );

    final File textFile = await exportService.exportRecordAsText(record);
    expect(await textFile.exists(), isTrue);
    final String textContent = await textFile.readAsString();
    expect(textContent, contains('授权编号: LIC-2026-0001'));
    expect(textContent, contains('创建时间:'));
    expect(textContent, contains('更新时间:'));

    final File xlsxFile =
        await exportService.exportRecordsAsXlsx(<LicenseRecordEntity>[record]);
    expect(await xlsxFile.exists(), isTrue);
    expect(xlsxFile.path, endsWith('.xlsx'));

    final Excel workbook = Excel.decodeBytes(await xlsxFile.readAsBytes());
    expect(workbook.tables.containsKey('授权记录'), isTrue);
    final Sheet sheet = workbook.tables['授权记录']!;
    expect(sheet.maxRows, greaterThanOrEqualTo(2));
    expect(sheet.row(0)[0]?.value.toString(), '授权编号');
    expect(sheet.row(0)[5]?.value.toString(), '首次激活截止');
    expect(sheet.row(0)[8]?.value.toString(), '创建时间');
    expect(sheet.row(0)[9]?.value.toString(), '更新时间');
    expect(sheet.row(0)[12]?.value.toString(), '授权码');
    expect(sheet.row(0)[13]?.value.toString(), '操作标记');
    expect(sheet.row(1)[13]?.value.toString(), 'I');

    final LicenseRecordEntity? updated = await repository.findByLicenseId(
      'LIC-2026-0001',
    );
    expect(updated, isNotNull);
    expect(updated!.exportedAt, now.add(const Duration(minutes: 5)));
  });
}
