import 'package:sqflite/sqflite.dart';
import '../database.dart';
import '../models/chat.dart';

class ChatRepository {
  final AppDatabase _db;
  ChatRepository(this._db);

  Future<void> upsert(Chat c) => _db.db.insert(
        'chats',
        c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<Chat?> findById(String id) async {
    final rows = await _db.db.query('chats', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Chat.fromMap(rows.first);
  }

  Future<List<Chat>> getAll() async {
    final rows = await _db.db.query('chats', orderBy: 'type DESC, last_message_time DESC');
    return rows.map(Chat.fromMap).toList();
  }

  Future<void> updateLastMessage(String chatId, String preview, int timestamp) =>
      _db.db.update(
        'chats',
        {'last_message': preview, 'last_message_time': timestamp},
        where: 'id = ?',
        whereArgs: [chatId],
      );

  Future<void> incrementUnread(String chatId) => _db.db.rawUpdate(
        'UPDATE chats SET unread_count = unread_count + 1 WHERE id = ?',
        [chatId],
      );

  Future<void> clearUnread(String chatId) => _db.db.update(
        'chats',
        {'unread_count': 0},
        where: 'id = ?',
        whereArgs: [chatId],
      );
}
