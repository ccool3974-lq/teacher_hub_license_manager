import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:teacher_hub_license_manager/core/storage/db_helper.dart';
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_entity.dart';
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late String databasePath;
  late LicenseRecordRepository repository;

  setUp(() async {
    sqfliteFfiInit();
    tempDirectory = await Directory.systemTemp.createTemp(
      'teacher_hub_license_manager_test_',
    );
    databasePath = '${tempDirectory.path}\\license_manager_test.db';
    await DbHelper.configureForTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: databasePath,
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
        appVersion: '1.2.3',
        bindName: 'Zhang',
        bindUserCode: 'T001',
        durationDays: 180,
        permanent: false,
        issuedAt: now,
        activationDeadline: now.add(const Duration(days: 30)),
        operatorName: 'AdminA',
        remark: 'Internal test',
        rawLicense: 'TTK3.payload.signature',
        status: LicenseRecordStatus.active,
        exportedAt: null,
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(inserted.id, isNotNull);

    final LicenseRecordEntity? loaded = await repository.findByLicenseId(
      'LIC-2026-0001',
    );
    expect(loaded, isNotNull);
    expect(loaded!.bindName, 'Zhang');
    expect(loaded.durationDays, 180);

    final List<LicenseRecordEntity> records = await repository.listAll();
    expect(records, hasLength(1));
    expect(records.first.licenseId, 'LIC-2026-0001');
    expect(records.first.appVersion, '1.2.3');

    final DateTime exportedAt = now.add(const Duration(minutes: 30));
    final int updatedRows = await repository.updateStatus(
      licenseId: 'LIC-2026-0001',
      status: LicenseRecordStatus.revoked,
      exportedAt: exportedAt,
      updatedAt: exportedAt,
    );
    expect(updatedRows, 1);

    final LicenseRecordEntity? updated = await repository.findByLicenseId(
      'LIC-2026-0001',
    );
    expect(updated, isNotNull);
    expect(updated!.status, LicenseRecordStatus.revoked);
    expect(updated.exportedAt, exportedAt);

    final int deletedRows = await repository.deleteByLicenseId('LIC-2026-0001');
    expect(deletedRows, 1);
    expect(await repository.findByLicenseId('LIC-2026-0001'), isNull);
  });

  test('repository upserts existing record by licenseId', () async {
    final DateTime now = DateTime.utc(2026, 4, 2, 12, 0);
    await repository.insert(
      LicenseRecordEntity(
        licenseId: 'LIC-2026-0002',
        appVersion: '1.2.3',
        bindName: 'Original',
        bindUserCode: 'T010',
        durationDays: 30,
        permanent: false,
        issuedAt: now,
        activationDeadline: now.add(const Duration(days: 30)),
        operatorName: 'AdminA',
        remark: 'First',
        rawLicense: 'TTK3.first.signature',
        status: LicenseRecordStatus.active,
        exportedAt: null,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final LicenseRecordEntity updatedRecord = await repository
        .upsertByLicenseId(
          LicenseRecordEntity(
            licenseId: 'LIC-2026-0002',
            appVersion: '2.0.0',
            bindName: 'Updated',
            bindUserCode: 'T011',
            durationDays: 0,
            permanent: true,
            issuedAt: now.add(const Duration(days: 1)),
            activationDeadline: now.add(const Duration(days: 45)),
            operatorName: 'AdminB',
            remark: 'Second',
            rawLicense: 'TTK3.second.signature',
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
    expect(records.first.appVersion, '2.0.0');
    expect(records.first.durationDays, 0);
    expect(records.first.status, LicenseRecordStatus.replaced);
  });

  test('database migration fills appVersion for version 3 records', () async {
    final DateTime now = DateTime.utc(2026, 4, 2, 12, 0);
    final Database oldDatabase = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (Database db, int version) async {
          await db.execute('''
            CREATE TABLE license_records (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              licenseId TEXT NOT NULL,
              bindName TEXT NOT NULL,
              bindUserCode TEXT,
              durationDays INTEGER NOT NULL,
              permanent INTEGER NOT NULL,
              issuedAt TEXT NOT NULL,
              activationDeadline TEXT NOT NULL,
              operatorName TEXT,
              remark TEXT,
              rawLicense TEXT NOT NULL,
              status TEXT NOT NULL,
              exportedAt TEXT,
              createdAt TEXT NOT NULL,
              updatedAt TEXT NOT NULL,
              UNIQUE (licenseId)
            )
          ''');
        },
      ),
    );
    await oldDatabase.insert('license_records', <String, Object?>{
      'licenseId': 'LIC-2026-LEGACY',
      'bindName': 'Legacy',
      'bindUserCode': null,
      'durationDays': 30,
      'permanent': 0,
      'issuedAt': now.toIso8601String(),
      'activationDeadline': now.add(const Duration(days: 30)).toIso8601String(),
      'operatorName': null,
      'remark': null,
      'rawLicense': 'TTK3.legacy.signature',
      'status': LicenseRecordStatus.active.storageValue,
      'exportedAt': null,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });
    await oldDatabase.close();

    final List<LicenseRecordEntity> records = await repository.listAll();

    expect(records, hasLength(1));
    expect(records.first.licenseId, 'LIC-2026-LEGACY');
    expect(records.first.appVersion, 'legacy');
  });
}
