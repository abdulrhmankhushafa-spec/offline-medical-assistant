import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final base = await getDatabasesPath();
    final path = join(base, 'offline_medical_assistant.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        last_updated TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        content TEXT NOT NULL,
        sender_type TEXT NOT NULL CHECK(sender_type IN ('user','ai','system')),
        timestamp TEXT NOT NULL,
        FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_messages_conversation ON messages(conversation_id, timestamp)');

    await db.execute('''
      CREATE TABLE medical_knowledge (
        id TEXT PRIMARY KEY,
        content_chunk TEXT NOT NULL,
        source_name TEXT NOT NULL,
        added_date TEXT NOT NULL
      )
    ''');

    // FTS5 is attempted exactly as required. If a device SQLite build does not
    // expose FTS5, the app keeps a LIKE fallback so it remains usable.
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE medical_knowledge_fts USING fts5(
          content_chunk,
          source_name,
          content='medical_knowledge',
          content_rowid='rowid',
          tokenize='unicode61'
        )
      ''');
      await db.execute('''
        CREATE TRIGGER medical_knowledge_ai AFTER INSERT ON medical_knowledge BEGIN
          INSERT INTO medical_knowledge_fts(rowid, content_chunk, source_name)
          VALUES (new.rowid, new.content_chunk, new.source_name);
        END
      ''');
      await db.execute('''
        CREATE TRIGGER medical_knowledge_ad AFTER DELETE ON medical_knowledge BEGIN
          INSERT INTO medical_knowledge_fts(medical_knowledge_fts, rowid, content_chunk, source_name)
          VALUES ('delete', old.rowid, old.content_chunk, old.source_name);
        END
      ''');
      await db.execute('''
        CREATE TRIGGER medical_knowledge_au AFTER UPDATE ON medical_knowledge BEGIN
          INSERT INTO medical_knowledge_fts(medical_knowledge_fts, rowid, content_chunk, source_name)
          VALUES ('delete', old.rowid, old.content_chunk, old.source_name);
          INSERT INTO medical_knowledge_fts(rowid, content_chunk, source_name)
          VALUES (new.rowid, new.content_chunk, new.source_name);
        END
      ''');
      await db.execute("INSERT INTO medical_knowledge_fts(medical_knowledge_fts) VALUES ('rebuild')");
    } catch (_) {
      // Fallback marker table. RetrievalService detects FTS5 availability.
      await db.execute('CREATE TABLE IF NOT EXISTS app_flags (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      await db.insert('app_flags', {'key': 'fts5_available', 'value': '0'});
    }

    await db.execute('''
      CREATE TABLE embeddings (
        id TEXT PRIMARY KEY,
        chunk_id TEXT NOT NULL,
        vector_data BLOB NOT NULL,
        dimensions INTEGER NOT NULL,
        FOREIGN KEY(chunk_id) REFERENCES medical_knowledge(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_embeddings_chunk ON embeddings(chunk_id)');

    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        password_salt TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE roles (
        id TEXT PRIMARY KEY,
        role_name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE user_roles (
        user_id TEXT NOT NULL,
        role_id TEXT NOT NULL,
        PRIMARY KEY(user_id, role_id),
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY(role_id) REFERENCES roles(id) ON DELETE CASCADE
      )
    ''');

    await db.insert('roles', {'id': 'admin', 'role_name': 'admin'});
    await db.insert('roles', {'id': 'user', 'role_name': 'user'});
  }

  Future<bool> isFts5Available() async {
    final db = await database;
    try {
      await db.rawQuery('SELECT rowid FROM medical_knowledge_fts LIMIT 1');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    await db?.close();
  }
}
