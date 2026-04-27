import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static const _name = 'familychat.db';
  static const _version = 1;

  Database? _db;
  final bool _inMemory;

  AppDatabase._({bool inMemory = false}) : _inMemory = inMemory;

  static final AppDatabase _instance = AppDatabase._();
  static AppDatabase get instance => _instance;
  factory AppDatabase.forTest() => AppDatabase._(inMemory: true);

  Database get db {
    assert(_db != null, 'Call open() first');
    return _db!;
  }

  Future<void> open() async {
    final path = _inMemory ? inMemoryDatabasePath : join(await getDatabasesPath(), _name);
    _db = await openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE contacts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        avatar_path TEXT,
        ip_address TEXT NOT NULL,
        port INTEGER NOT NULL,
        is_online INTEGER NOT NULL DEFAULT 0,
        last_seen INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE chats (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        last_message TEXT NOT NULL DEFAULT '',
        last_message_time INTEGER NOT NULL DEFAULT 0,
        unread_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        chat_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        content TEXT NOT NULL,
        content_type TEXT NOT NULL,
        file_path TEXT,
        timestamp INTEGER NOT NULL,
        status TEXT NOT NULL,
        is_outgoing INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_messages_chat ON messages(chat_id, timestamp)');
    await db.execute('CREATE INDEX idx_messages_status ON messages(status, is_outgoing)');
  }
}
