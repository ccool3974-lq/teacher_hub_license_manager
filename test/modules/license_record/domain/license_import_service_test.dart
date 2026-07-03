import 'dart:io';
import 'dart:math';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:teacher_hub_license_manager/core/storage/db_helper.dart';
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_entity.dart';
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_repository.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_generation_service.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_import_service.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_record_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late LicenseRecordRepository repository;

  setUp(() async {
    sqfliteFfiInit();
    tempDirectory = await Directory.systemTemp.createTemp(
      'teacher_hub_license_manager_import_test_',
    );
    await DbHelper.configureForTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: '${tempDirectory.path}\\license_manager_import.db',
    );
    repository = const LicenseRecordRepository();
  });

  tearDown(() async {
    await DbHelper.resetTestingOverrides();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('importExistingRecords upserts records by licenseId', () async {
    final DateTime now = DateTime.utc(2026, 4, 2, 12, 0);
    await repository.insert(
      LicenseRecordEntity(
        licenseId: 'LIC-2026-0003',
        appVersion: '1.2.3',
        bindName: '旧名称',
        bindUserCode: 'T001',
        durationDays: 30,
        permanent: false,
        issuedAt: now,
        activationDeadline: now.add(const Duration(days: 30)),
        operatorName: 'AdminA',
        remark: '旧备注',
        rawLicense: 'TTK3.old.signature',
        status: LicenseRecordStatus.active,
        exportedAt: null,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final File file = File(
      '${tempDirectory.path}\\license_record_import_template_existing_records.xlsx',
    );
    final Excel workbook = Excel.createExcel();
    workbook.rename('Sheet1', '授权记录');
    final Sheet sheet = workbook['授权记录'];
    sheet.appendRow(
      LicenseImportService.existingRecordHeaders
          .map(TextCellValue.new)
          .toList(growable: false),
    );
    sheet.appendRow(<CellValue>[
      TextCellValue('LIC-2026-0003'),
      TextCellValue('2.0.0'),
      TextCellValue('新名称'),
      TextCellValue('T009'),
      TextCellValue('永久'),
      TextCellValue(now.add(const Duration(days: 20)).toIso8601String()),
      TextCellValue('已替代'),
      TextCellValue(now.toIso8601String()),
      TextCellValue(now.toIso8601String()),
      TextCellValue(now.add(const Duration(hours: 1)).toIso8601String()),
      TextCellValue('AdminB'),
      TextCellValue('新备注'),
      TextCellValue('TTK3.new.signature'),
      TextCellValue('U'),
    ]);
    await file.writeAsBytes(workbook.encode()!);

    final LicenseImportService importService = LicenseImportService(
      repository: repository,
      now: () => now,
    );

    final LicenseImportResult result = await importService
        .importExistingRecords(file);
    expect(result.totalRows, 1);
    expect(result.successCount, 1);
    expect(result.failureCount, 0);

    final List<LicenseRecordEntity> records = await repository.listAll();
    expect(records, hasLength(1));
    expect(records.first.bindName, '新名称');
    expect(records.first.appVersion, '2.0.0');
    expect(records.first.durationDays, 0);
    expect(records.first.status, LicenseRecordStatus.replaced);
    expect(records.first.rawLicense, 'TTK3.new.signature');
    expect(records.first.activationDeadline, now.add(const Duration(days: 20)));
  });

  test('batchGenerateFromFile creates new signed records', () async {
    const List<int> seed = <int>[
      0x9d,
      0x61,
      0xb1,
      0x9d,
      0xef,
      0xfd,
      0x5a,
      0x60,
      0xba,
      0x84,
      0xaf,
      0x49,
      0x2e,
      0xcc,
      0x4c,
      0x44,
      0xc5,
      0x69,
      0x7b,
      0x32,
      0x69,
      0x19,
      0x70,
      0x3b,
      0xac,
      0x03,
      0x1c,
      0xae,
      0x7f,
      0x60,
      0xd5,
      0x7f,
    ];
    final DateTime now = DateTime.utc(2026, 4, 2, 12, 0);
    final LicenseRecordService recordService = LicenseRecordService(
      repository: repository,
      generationService: LicenseGenerationService(
        loadPrivateKeySeed: () async => seed,
        now: () => now,
        random: Random(3),
      ),
      now: () => now,
    );

    final File file = File(
      '${tempDirectory.path}\\license_batch_generate_template_batch_generate.xlsx',
    );
    final Excel workbook = Excel.createExcel();
    workbook.rename('Sheet1', '批量生码模板');
    final Sheet sheet = workbook['批量生码模板'];
    sheet.appendRow(
      LicenseImportService.batchGenerateHeaders
          .map(TextCellValue.new)
          .toList(growable: false),
    );
    sheet.appendRow(<CellValue>[
      TextCellValue('1.2.3'),
      TextCellValue('张老师'),
      TextCellValue('T100'),
      TextCellValue('45'),
      TextCellValue('否'),
      TextCellValue(now.add(const Duration(days: 25)).toIso8601String()),
      TextCellValue('AdminA'),
      TextCellValue('批量导入'),
      TextCellValue('I'),
    ]);
    await file.writeAsBytes(workbook.encode()!);

    final LicenseImportService importService = LicenseImportService(
      repository: repository,
      recordService: recordService,
      now: () => now,
    );

    final LicenseImportResult result = await importService
        .batchGenerateFromFile(file);
    expect(result.totalRows, 1);
    expect(result.successCount, 1);
    expect(result.failureCount, 0);

    final List<LicenseRecordEntity> records = await repository.listAll();
    expect(records, hasLength(1));
    expect(records.first.bindName, '张老师');
    expect(records.first.appVersion, '1.2.3');
    expect(records.first.durationDays, 45);
    expect(records.first.activationDeadline, now.add(const Duration(days: 25)));
    expect(records.first.rawLicense.startsWith('TTK3.'), isTrue);
  });

  test(
    'importExistingRecords deletes existing record when marker is D',
    () async {
      final DateTime now = DateTime.utc(2026, 4, 2, 12, 0);
      await repository.insert(
        LicenseRecordEntity(
          licenseId: 'LIC-2026-0004',
          appVersion: '1.2.3',
          bindName: '待删除',
          bindUserCode: 'T020',
          durationDays: 30,
          permanent: false,
          issuedAt: now,
          activationDeadline: now.add(const Duration(days: 30)),
          operatorName: 'AdminA',
          remark: 'Delete me',
          rawLicense: 'TTK3.delete.signature',
          status: LicenseRecordStatus.active,
          exportedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final File file = File(
        '${tempDirectory.path}\\license_record_import_template_delete_record.xlsx',
      );
      final Excel workbook = Excel.createExcel();
      workbook.rename('Sheet1', '授权记录');
      final Sheet sheet = workbook['授权记录'];
      sheet.appendRow(
        LicenseImportService.existingRecordHeaders
            .map(TextCellValue.new)
            .toList(growable: false),
      );
      sheet.appendRow(<CellValue>[
        TextCellValue('LIC-2026-0004'),
        TextCellValue('1.2.3'),
        TextCellValue('待删除'),
        TextCellValue('T020'),
        TextCellValue('30 天'),
        TextCellValue(now.add(const Duration(days: 15)).toIso8601String()),
        TextCellValue('有效'),
        TextCellValue(now.toIso8601String()),
        TextCellValue(now.toIso8601String()),
        TextCellValue(now.toIso8601String()),
        TextCellValue('AdminA'),
        TextCellValue('Delete me'),
        TextCellValue('TTK3.delete.signature'),
        TextCellValue('D'),
      ]);
      await file.writeAsBytes(workbook.encode()!);

      final LicenseImportService importService = LicenseImportService(
        repository: repository,
        now: () => now,
      );

      final LicenseImportResult result = await importService
          .importExistingRecords(file);
      expect(result.totalRows, 1);
      expect(result.successCount, 1);
      expect(result.failureCount, 0);
      expect(await repository.findByLicenseId('LIC-2026-0004'), isNull);
    },
  );

  test('importExistingRecords rejects files with extra columns', () async {
    final DateTime now = DateTime.utc(2026, 4, 2, 12, 0);
    final File file = File(
      '${tempDirectory.path}\\license_record_import_template_extra.xlsx',
    );
    final Excel workbook = Excel.createExcel();
    workbook.rename('Sheet1', '授权记录');
    final Sheet sheet = workbook['授权记录'];
    final List<String> headers = <String>[
      ...LicenseImportService.existingRecordHeaders,
      '多余列',
    ];
    sheet.appendRow(headers.map(TextCellValue.new).toList(growable: false));
    sheet.appendRow(<CellValue>[
      TextCellValue('LIC-2026-0005'),
      TextCellValue('1.2.3'),
      TextCellValue('张老师'),
      TextCellValue('T001'),
      TextCellValue('30 天'),
      TextCellValue(now.add(const Duration(days: 15)).toIso8601String()),
      TextCellValue('有效'),
      TextCellValue(now.toIso8601String()),
      TextCellValue(now.toIso8601String()),
      TextCellValue(now.toIso8601String()),
      TextCellValue('AdminA'),
      TextCellValue('备注'),
      TextCellValue('TTK3.payload.signature'),
      TextCellValue('I'),
      TextCellValue('extra'),
    ]);
    await file.writeAsBytes(workbook.encode()!);

    final LicenseImportService importService = LicenseImportService(
      repository: repository,
      now: () => now,
    );

    expect(
      () => importService.importExistingRecords(file),
      throwsA(isA<StateError>()),
    );
  });

  test('batchGenerateFromFile rejects files over 1000 rows', () async {
    final DateTime now = DateTime.utc(2026, 4, 2, 12, 0);
    final LicenseRecordService recordService = LicenseRecordService(
      repository: repository,
      generationService: LicenseGenerationService(
        loadPrivateKeySeed: () async => List<int>.filled(32, 1),
        now: () => now,
        random: Random(5),
      ),
      now: () => now,
    );
    final File file = File(
      '${tempDirectory.path}\\license_batch_generate_template_1001.xlsx',
    );
    final Excel workbook = Excel.createExcel();
    workbook.rename('Sheet1', '批量生码模板');
    final Sheet sheet = workbook['批量生码模板'];
    sheet.appendRow(
      LicenseImportService.batchGenerateHeaders
          .map(TextCellValue.new)
          .toList(growable: false),
    );
    for (int i = 0; i < 1001; i++) {
      sheet.appendRow(<CellValue>[
        TextCellValue('1.2.3'),
        TextCellValue('张老师$i'),
        TextCellValue('T$i'),
        TextCellValue('30'),
        TextCellValue('否'),
        TextCellValue(now.add(const Duration(days: 25)).toIso8601String()),
        TextCellValue('AdminA'),
        TextCellValue('批量导入'),
        TextCellValue('I'),
      ]);
    }
    await file.writeAsBytes(workbook.encode()!);

    final LicenseImportService importService = LicenseImportService(
      repository: repository,
      recordService: recordService,
      now: () => now,
    );

    expect(
      () => importService.batchGenerateFromFile(file),
      throwsA(isA<StateError>()),
    );
  });
}
