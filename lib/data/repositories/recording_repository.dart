import '../database.dart';
import '../models/recording.dart';

class RecordingRepository {
  final AppDatabase _db;
  RecordingRepository(this._db);

  Future<void> insert(Recording recording) async {
    await _db.db.insert('recordings', recording.toMap());
  }

  Future<List<Recording>> getAll() async {
    final rows = await _db.db.query('recordings', orderBy: 'created_at DESC');
    return rows.map(Recording.fromMap).toList();
  }

  Future<void> delete(String id) async {
    await _db.db.delete('recordings', where: 'id = ?', whereArgs: [id]);
  }
}
