import 'package:sqflite/sqflite.dart';
import '../database.dart';
import '../models/contact.dart';

class ContactRepository {
  final AppDatabase _db;
  ContactRepository(this._db);

  Future<void> upsert(Contact c) => _db.db.insert(
        'contacts',
        c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<Contact?> findById(String id) async {
    final rows = await _db.db.query('contacts', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Contact.fromMap(rows.first);
  }

  Future<List<Contact>> getAll() async {
    final rows = await _db.db.query('contacts', orderBy: 'name');
    return rows.map(Contact.fromMap).toList();
  }

  Future<void> setOnline(String id, bool online) => _db.db.update(
        'contacts',
        {'is_online': online ? 1 : 0, 'last_seen': DateTime.now().millisecondsSinceEpoch ~/ 1000},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> updateAddress(String id, String ip, int port) => _db.db.update(
        'contacts',
        {'ip_address': ip, 'port': port},
        where: 'id = ?',
        whereArgs: [id],
      );
}
