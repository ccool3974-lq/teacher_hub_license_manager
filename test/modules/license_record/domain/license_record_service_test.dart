import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:teacher_hub_license_manager/core/storage/db_helper.dart';
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_entity.dart';
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_repository.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_generation_service.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_record_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;

  setUp(() async {
    sqfliteFfiInit();
    tempDirectory = await Directory.systemTemp.createTemp(
      'teacher_hub_license_manager_service_test_',
    );
    await DbHelper.configureForTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: '${tempDirectory.path}\\license_manager_service.db',
    );
  });

  tearDown(() async {
    await DbHelper.resetTestingOverrides();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'record service generates, stores, and updates a license record',
    () async {
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
      final LicenseRecordService service = LicenseRecordService(
        repository: const LicenseRecordRepository(),
        generationService: LicenseGenerationService(
          loadPrivateKeySeed: () async => seed,
          now: () => DateTime.utc(2026, 4, 2, 12, 0),
          random: Random(7),
        ),
        now: () => DateTime.utc(2026, 4, 2, 12, 0),
      );

      final LicenseRecordEntity record = await service.createLicenseRecord(
        appVersion: '1.2.3',
        bindName: 'Zhang',
        bindUserCode: 'T001',
        durationDays: 365,
        permanent: false,
        activationDeadline: DateTime.utc(2026, 5, 2, 12, 0),
        operatorName: 'AdminA',
        remark: 'Annual license',
      );

      expect(record.id, isNotNull);
      expect(record.bindName, 'Zhang');
      expect(record.appVersion, '1.2.3');
      expect(record.bindUserCode, 'T001');
      expect(record.durationDays, 365);
      expect(record.status, LicenseRecordStatus.active);
      expect(record.activationDeadline, DateTime.utc(2026, 5, 2, 12, 0));
      expect(record.rawLicense.startsWith('TTK3.'), isTrue);

      final List<LicenseRecordEntity> records = await service.listRecords();
      expect(records, hasLength(1));
      expect(records.first.licenseId, record.licenseId);

      final LicenseRecordEntity? updated = await service.updateRecordStatus(
        licenseId: record.licenseId,
        status: LicenseRecordStatus.revoked,
      );
      expect(updated, isNotNull);
      expect(updated!.status, LicenseRecordStatus.revoked);
    },
  );

  test('dashboard summary includes operation metrics', () async {
    final DateTime now = DateTime.utc(2026, 4, 2, 12, 0);
    final LicenseRecordRepository repository = const LicenseRecordRepository();
    await repository.insert(
      LicenseRecordEntity(
        licenseId: 'LIC-2026-0001',
        appVersion: '1.2.3',
        bindName: '张老师',
        bindUserCode: 'T001',
        durationDays: 30,
        permanent: false,
        issuedAt: now,
        activationDeadline: now.add(const Duration(days: 3)),
        operatorName: 'AdminA',
        remark: null,
        rawLicense: 'TTK3.payload.signature',
        status: LicenseRecordStatus.active,
        exportedAt: null,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.insert(
      LicenseRecordEntity(
        licenseId: 'LIC-2026-0002',
        appVersion: '1.2.3',
        bindName: '李老师',
        bindUserCode: 'T002',
        durationDays: 180,
        permanent: false,
        issuedAt: now,
        activationDeadline: now.add(const Duration(days: 20)),
        operatorName: 'AdminA',
        remark: null,
        rawLicense: 'TTK3.payload.signature',
        status: LicenseRecordStatus.active,
        exportedAt: now.add(const Duration(minutes: 5)),
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
      ),
    );
    await repository.insert(
      LicenseRecordEntity(
        licenseId: 'LIC-2026-0003',
        appVersion: '1.2.3',
        bindName: '王老师',
        bindUserCode: 'T003',
        durationDays: 30,
        permanent: false,
        issuedAt: now,
        activationDeadline: now.add(const Duration(days: 2)),
        operatorName: 'AdminB',
        remark: null,
        rawLicense: 'TTK3.payload.signature',
        status: LicenseRecordStatus.revoked,
        exportedAt: null,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.insert(
      LicenseRecordEntity(
        licenseId: 'LIC-2026-0004',
        appVersion: '1.2.3',
        bindName: '赵老师',
        bindUserCode: 'T004',
        durationDays: 0,
        permanent: true,
        issuedAt: now,
        activationDeadline: now.subtract(const Duration(days: 1)),
        operatorName: 'AdminB',
        remark: null,
        rawLicense: 'TTK3.payload.signature',
        status: LicenseRecordStatus.active,
        exportedAt: null,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final LicenseRecordService service = LicenseRecordService(
      repository: repository,
      now: () => now,
    );

    final LicenseDashboardSummary summary = await service.getDashboardSummary();

    expect(summary.totalCount, 4);
    expect(summary.activeCount, 3);
    expect(summary.revokedCount, 1);
    expect(summary.replacedCount, 0);
    expect(summary.permanentCount, 1);
    expect(summary.unexportedCount, 3);
    expect(summary.activationDeadlineWarningCount, 1);
    expect(summary.todayCreatedCount, 3);
    expect(summary.recentRecords, hasLength(4));
  });
}
