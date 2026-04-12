import 'package:sqflite/sqflite.dart';
import 'package:teacher_hub_license_manager/core/storage/db_helper.dart';
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_entity.dart';

class LicenseRecordRepository {
  const LicenseRecordRepository();

  static const String _tableName = 'license_records';

  Future<LicenseRecordEntity> insert(LicenseRecordEntity entity) async {
    final Database db = await DbHelper.database();
    final int id = await db.insert(
      _tableName,
      entity.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return entity.copyWith(id: id);
  }

  Future<LicenseRecordEntity> upsertByLicenseId(LicenseRecordEntity entity) async {
    final Database db = await DbHelper.database();
    final LicenseRecordEntity? existing = await findByLicenseId(entity.licenseId);
    if (existing == null) {
      return insert(entity);
    }

    await db.update(
      _tableName,
      entity.copyWith(id: existing.id).toMap()..remove('id'),
      where: 'licenseId = ?',
      whereArgs: <Object?>[entity.licenseId],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return entity.copyWith(id: existing.id);
  }

  Future<LicenseRecordEntity?> findByLicenseId(String licenseId) async {
    final Database db = await DbHelper.database();
    final List<Map<String, Object?>> rows = await db.query(
      _tableName,
      where: 'licenseId = ?',
      whereArgs: <Object?>[licenseId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return LicenseRecordEntity.fromMap(rows.first);
  }

  Future<List<LicenseRecordEntity>> listAll() async {
    final Database db = await DbHelper.database();
    final List<Map<String, Object?>> rows = await db.query(
      _tableName,
      orderBy: 'createdAt DESC, id DESC',
    );

    return rows
        .map((Map<String, Object?> row) => LicenseRecordEntity.fromMap(row))
        .toList(growable: false);
  }

  Future<int> updateStatus({
    required String licenseId,
    required LicenseRecordStatus status,
    DateTime? exportedAt,
    required DateTime updatedAt,
  }) async {
    final Database db = await DbHelper.database();
    return db.update(
      _tableName,
      <String, Object?>{
        'status': status.storageValue,
        'exportedAt': exportedAt?.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      },
      where: 'licenseId = ?',
      whereArgs: <Object?>[licenseId],
    );
  }

  Future<int> deleteByLicenseId(String licenseId) async {
    final Database db = await DbHelper.database();
    return db.delete(
      _tableName,
      where: 'licenseId = ?',
      whereArgs: <Object?>[licenseId],
    );
  }
}
