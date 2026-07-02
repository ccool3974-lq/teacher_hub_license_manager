import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_entity.dart';

void main() {
  test('LicenseRecordEntity round trips through map conversion', () {
    final DateTime now = DateTime.parse('2026-04-02T10:30:00.000Z');
    final LicenseRecordEntity entity = LicenseRecordEntity(
      id: 1,
      licenseId: 'LIC-2026-0001',
      bindName: 'Zhang',
      bindUserCode: 'T001',
      durationDays: 180,
      permanent: false,
      issuedAt: DateTime.utc(2026, 4, 2, 10, 30),
      activationDeadline: DateTime.utc(2026, 5, 2, 23, 59, 59),
      operatorName: 'AdminA',
      remark: 'Initial issue',
      rawLicense: 'TTK3.payload.signature',
      status: LicenseRecordStatus.active,
      exportedAt: DateTime.utc(2026, 4, 2, 11, 0),
      createdAt: DateTime.utc(2026, 4, 2, 10, 30),
      updatedAt: DateTime.utc(2026, 4, 2, 10, 30),
    );

    final Map<String, Object?> map = entity.toMap();
    final LicenseRecordEntity rebuilt = LicenseRecordEntity.fromMap(map);

    expect(rebuilt.id, 1);
    expect(rebuilt.licenseId, 'LIC-2026-0001');
    expect(rebuilt.bindName, 'Zhang');
    expect(rebuilt.bindUserCode, 'T001');
    expect(rebuilt.durationDays, 180);
    expect(rebuilt.permanent, isFalse);
    expect(rebuilt.issuedAt, now);
    expect(
      rebuilt.activationDeadline,
      DateTime.parse('2026-05-02T23:59:59.000Z'),
    );
    expect(rebuilt.operatorName, 'AdminA');
    expect(rebuilt.remark, 'Initial issue');
    expect(rebuilt.rawLicense, 'TTK3.payload.signature');
    expect(rebuilt.status, LicenseRecordStatus.active);
    expect(rebuilt.exportedAt, DateTime.parse('2026-04-02T11:00:00.000Z'));
    expect(rebuilt.createdAt, now);
    expect(rebuilt.updatedAt, now);
    expect(map.containsKey('tier'), isFalse);
  });
}
