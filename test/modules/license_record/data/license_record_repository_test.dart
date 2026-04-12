import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:teacher_hub_license_manager/core/storage/db_helper.dart';
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_entity.dart';
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_repository.dart';
import 'package:teacher_toolkit_license_protocol/teacher_toolkit_license_protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late LicenseRecordRepository repository;

  setUp(() async {
    sqfliteFfiInit();
    tempDirectory = await Directory.systemTemp.createTemp(
      'teacher_hub_license_manager_test_',
    );
    await DbHelper.configureForTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: '${tempDirectory.path}\\license_manager_test.db',
    );
    repository = const LicenseRecordRepository();
  });

  tearDown(() async {
    await DbHelper.resetTestingOverrides();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('repository inserts, loads, updates, and deletes records', () async {
    final DateTime now = DateTime.utc(2026, 4, 2, 12, 0);
    final LicenseRecordEntity inserted = await repository.insert(
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
        remark: 'Internal test',
        rawLicense: 'TTK2.payload.signature',
        status: LicenseRecordStatus.active,
        exportedAt: null,
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(inserted.id, isNotNull);

    final LicenseRecordEntity? loaded =
        await repository.findByLicenseId('LIC-2026-0001');
    expect(loaded, isNotNull);
    expect(loaded!.bindName, 'Zhang');
    expect(loaded.tier, LicenseTier.basic);

    final List<LicenseRecordEntity> records = await repository.listAll();
    expect(records, hasLength(1));
    expect(records.first.licenseId, 'LIC-2026-0001');

    final DateTime exportedAt = now.add(const Duration(minutes: 30));
    final int updatedRows = await repository.updateStatus(
      licenseId: 'LIC-2026-0001',
      status: LicenseRecordStatus.revoked,
      exportedAt: exportedAt,
      updatedAt: exportedAt,
    );
    expect(updatedRows, 1);

    final LicenseRecordEntity? updated =
        await repository.findByLicenseId('LIC-2026-0001');
    expect(updated, isNotNull);
    expect(updated!.status, LicenseRecordStatus.revoked);
    expect(updated.exportedAt, exportedAt);

    final int deletedRows =
        await repository.deleteByLicenseId('LIC-2026-0001');
    expect(deletedRows, 1);
    expect(await repository.findByLicenseId('LIC-2026-0001'), isNull);
  });

  test('repository upserts existing record by licenseId', () async {
    final DateTime now = DateTime.utc(2026, 4, 2, 12, 0);
    await repository.insert(
      LicenseRecordEntity(
        licenseId: 'LIC-2026-0002',
        bindName: 'Original',
        bindUserCode: 'T010',
        tier: LicenseTier.basic,
        durationDays: 30,
        permanent: false,
        issuedAt: now,
        activationDeadline: now.add(const Duration(days: 30)),
        operatorName: 'AdminA',
        remark: 'First',
        rawLicense: 'TTK2.first.signature',
        status: LicenseRecordStatus.active,
        exportedAt: null,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final LicenseRecordEntity updatedRecord = await repository.upsertByLicenseId(
      LicenseRecordEntity(
        licenseId: 'LIC-2026-0002',
        bindName: 'Updated',
        bindUserCode: 'T011',
        tier: LicenseTier.premium,
        durationDays: null,
        permanent: true,
        issuedAt: now.add(const Duration(days: 1)),
        activationDeadline: now.add(const Duration(days: 45)),
        operatorName: 'AdminB',
        remark: 'Second',
        rawLicense: 'TTK2.second.signature',
        status: LicenseRecordStatus.replaced,
        exportedAt: null,
        createdAt: now,
        updatedAt: now.add(const Duration(days: 1)),
      ),
    );

    final List<LicenseRecordEntity> records = await repository.listAll();
    expect(records, hasLength(1));
    expect(updatedRecord.id, isNotNull);
    expect(records.first.bindName, 'Updated');
    expect(records.first.tier, LicenseTier.premium);
    expect(records.first.status, LicenseRecordStatus.replaced);
  });
}
