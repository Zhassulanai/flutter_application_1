import 'package:sqflite/sqflite.dart';
import '../database.dart';
import '../models/message.dart';

class MessageRepository {
  final AppDatabase _db;
  MessageRepository(this._db);

  Future<void> insert(Message m) => _db.db.insert(
        'messages',
        m.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

  Future<List<Message>> loadForChat(String chatId, {required int limit, required int offset}) async {
    final rows = await _db.db.query(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'timestamp ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map(Message.fromMap).toList();
  }

  Future<void> updateStatus(String id, MessageStatus status) => _db.db.update(
        'messages',
        {'status': status.name},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<List<Message>> getPendingFor(String peerId) async {
    final rows = await _db.db.query(
      'messages',
      where: "status = 'pending' AND is_outgoing = 1 AND chat_id LIKE ?",
      whereArgs: ['%$peerId%'],
    );
    return rows.map(Message.fromMap).toList();
  }

  Future<void> deleteMessage(String id) =>
      _db.db.delete('messages', where: 'id = ?', whereArgs: [id]);
}
