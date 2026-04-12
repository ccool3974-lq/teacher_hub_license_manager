import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:teacher_hub_license_manager/core/storage/db_helper.dart';
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_entity.dart';
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_repository.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_generation_service.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_record_service.dart';
import 'package:teacher_toolkit_license_protocol/teacher_toolkit_license_protocol.dart';

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

  test('record service generates, stores, and updates a license record', () async {
    const List<int> seed = <int>[
      0x9d, 0x61, 0xb1, 0x9d, 0xef, 0xfd, 0x5a, 0x60,
      0xba, 0x84, 0xaf, 0x49, 0x2e, 0xcc, 0x4c, 0x44,
      0xc5, 0x69, 0x7b, 0x32, 0x69, 0x19, 0x70, 0x3b,
      0xac, 0x03, 0x1c, 0xae, 0x7f, 0x60, 0xd5, 0x7f,
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
      bindName: 'Zhang',
      bindUserCode: 'T001',
      tier: LicenseTier.premium,
      durationDays: 365,
      permanent: false,
      activationDeadline: DateTime.utc(2026, 5, 2, 12, 0),
      operatorName: 'AdminA',
      remark: 'Annual license',
    );

    expect(record.id, isNotNull);
    expect(record.bindName, 'Zhang');
    expect(record.bindUserCode, 'T001');
    expect(record.tier, LicenseTier.premium);
    expect(record.status, LicenseRecordStatus.active);
    expect(record.activationDeadline, DateTime.utc(2026, 5, 2, 12, 0));
    expect(record.rawLicense.startsWith('$licenseStructuredPrefix.'), isTrue);

    final List<LicenseRecordEntity> records = await service.listRecords();
    expect(records, hasLength(1));
    expect(records.first.licenseId, record.licenseId);

    final LicenseRecordEntity? updated = await service.updateRecordStatus(
      licenseId: record.licenseId,
      status: LicenseRecordStatus.revoked,
    );
    expect(updated, isNotNull);
    expect(updated!.status, LicenseRecordStatus.revoked);
  });
}
