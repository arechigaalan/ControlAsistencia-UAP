import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static Database? _database;
  static const _dbName = 'asistencia_qr.db';
  static const _dbVersion = 5;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sesiones (
        session_id TEXT PRIMARY KEY,
        fecha_creacion TEXT NOT NULL,
        activa INTEGER NOT NULL,
        tipo_registro TEXT NOT NULL,
        fecha_clase TEXT NOT NULL,
        parcial INTEGER NOT NULL,
        materia_clave TEXT NOT NULL,
        materia_nombre TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE registros (
        id_registro TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        plantel TEXT NOT NULL,
        nombre TEXT NOT NULL,
        matricula TEXT NOT NULL,
        semestre TEXT NOT NULL,
        grupo TEXT NOT NULL,
        turno TEXT NOT NULL,
        modalidad TEXT NOT NULL,
        curp TEXT NOT NULL,
        materia_clave TEXT NOT NULL,
        materia_nombre TEXT NOT NULL,
        tipo_registro TEXT NOT NULL,
        fecha_clase TEXT NOT NULL,
        fecha_hora_escaneo TEXT NOT NULL,
        codigo TEXT NOT NULL,
        parcial INTEGER NOT NULL,
        FOREIGN KEY(session_id) REFERENCES sesiones(session_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE alumnos (
        curp TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        matricula TEXT NOT NULL,
        plantel TEXT NOT NULL,
        semestre TEXT NOT NULL,
        grupo TEXT NOT NULL,
        turno TEXT NOT NULL,
        modalidad TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE parciales (
        numero INTEGER PRIMARY KEY,
        fecha_inicio TEXT NOT NULL,
        fecha_fin TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE app_state (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_registros_session_id ON registros(session_id)',
    );
    await db.execute(
      'CREATE INDEX idx_registros_fecha_hora ON registros(fecha_hora_escaneo)',
    );
    await db.execute(
      'CREATE INDEX idx_registros_curp ON registros(curp)',
    );
    await db.execute(
      'CREATE INDEX idx_registros_parcial ON registros(parcial)',
    );
    await db.execute(
      'CREATE INDEX idx_registros_materia ON registros(materia_clave)',
    );
    await db.execute(
      'CREATE INDEX idx_alumnos_grupo ON alumnos(plantel, semestre, grupo, turno, modalidad)',
    );
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE registros ADD COLUMN modalidad TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE registros ADD COLUMN curp TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_registros_curp ON registros(curp)',
      );
    }

    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE registros ADD COLUMN parcial INTEGER NOT NULL DEFAULT 1",
      );
      await db.execute(
        "ALTER TABLE sesiones ADD COLUMN parcial INTEGER NOT NULL DEFAULT 1",
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_registros_parcial ON registros(parcial)',
      );
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS alumnos (
          curp TEXT PRIMARY KEY,
          nombre TEXT NOT NULL,
          matricula TEXT NOT NULL,
          plantel TEXT NOT NULL,
          semestre TEXT NOT NULL,
          grupo TEXT NOT NULL,
          turno TEXT NOT NULL,
          modalidad TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS parciales (
          numero INTEGER PRIMARY KEY,
          fecha_inicio TEXT NOT NULL,
          fecha_fin TEXT NOT NULL
        )
      ''');

      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_alumnos_grupo ON alumnos(plantel, semestre, grupo, turno, modalidad)',
      );
    }

    if (oldVersion < 5) {
      await db.execute(
        "ALTER TABLE sesiones ADD COLUMN materia_clave TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE sesiones ADD COLUMN materia_nombre TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE registros ADD COLUMN materia_clave TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE registros ADD COLUMN materia_nombre TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_registros_materia ON registros(materia_clave)',
      );
    }
  }
}
