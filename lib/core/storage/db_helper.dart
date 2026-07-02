import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DbHelper {
  const DbHelper._();

  static const String databaseName = 'teacher_hub_license_manager.db';
  static const int databaseVersion = 3;

  static Database? _database;
  static DatabaseFactory? _databaseFactoryOverride;
  static String? _databasePathOverride;

  static Future<Database> database() async {
    if (_database != null) {
      return _database!;
    }

    final DatabaseFactory factory = _resolveDatabaseFactory();
    final String databasePath =
        _databasePathOverride ?? await _resolveDatabasePath();

    _database = await factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onCreate: (Database db, int version) async {
          await _createTables(db);
        },
        onUpgrade: (Database db, int oldVersion, int newVersion) async {
          await _upgradeTables(db, oldVersion, newVersion);
        },
      ),
    );

    return _database!;
  }

  static Future<void> configureForTesting({
    DatabaseFactory? databaseFactory,
    String? databasePath,
  }) async {
    await close();
    _databaseFactoryOverride = databaseFactory;
    _databasePathOverride = databasePath;
    if (databaseFactory != null) {
      sqfliteFfiInit();
      // Keep the global helpers aligned with the injected factory during tests.
      databaseFactoryOrNull = databaseFactory;
    }
  }

  static Future<void> resetTestingOverrides() async {
    await close();
    _databaseFactoryOverride = null;
    _databasePathOverride = null;
  }

  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  static DatabaseFactory _resolveDatabaseFactory() {
    if (_databaseFactoryOverride != null) {
      return _databaseFactoryOverride!;
    }

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      sqfliteFfiInit();
      databaseFactoryOrNull = databaseFactoryFfi;
      return databaseFactoryFfi;
    }

    return databaseFactory;
  }

  static Future<String> _resolveDatabasePath() async {
    final DatabaseFactory factory = _resolveDatabaseFactory();
    final String databasesDirectory = await factory.getDatabasesPath();
    return path.join(databasesDirectory, databaseName);
  }

  static Future<void> _createTables(Database db) async {
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
  }

  static Future<void> _upgradeTables(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2 && newVersion >= 2) {
      await db.execute(
        'ALTER TABLE license_records ADD COLUMN activationDeadline TEXT',
      );
    }
    if (oldVersion < 3 && newVersion >= 3) {
      await db.execute(
        'ALTER TABLE license_records RENAME TO license_records_old',
      );
      await _createTables(db);
      await db.execute('''
        INSERT INTO license_records (
          id,
          licenseId,
          bindName,
          bindUserCode,
          durationDays,
          permanent,
          issuedAt,
          activationDeadline,
          operatorName,
          remark,
          rawLicense,
          status,
          exportedAt,
          createdAt,
          updatedAt
        )
        SELECT
          id,
          licenseId,
          bindName,
          bindUserCode,
          CASE
            WHEN permanent = 1 THEN 0
            ELSE COALESCE(durationDays, 0)
          END,
          permanent,
          issuedAt,
          COALESCE(activationDeadline, datetime(issuedAt, '+30 days')),
          operatorName,
          remark,
          rawLicense,
          status,
          exportedAt,
          createdAt,
          updatedAt
        FROM license_records_old
      ''');
      await db.execute('DROP TABLE license_records_old');
    }
  }
}
