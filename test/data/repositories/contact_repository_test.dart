import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_application_1/data/database.dart';
import 'package:flutter_application_1/data/repositories/contact_repository.dart';
import 'package:flutter_application_1/data/models/contact.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late ContactRepository repo;

  setUp(() async {
    db = AppDatabase.forTest();
    await db.open();
    repo = ContactRepository(db);
  });

  tearDown(() async => db.close());

  test('insert and find contact', () async {
    final c = Contact(
      id: 'uuid-1', name: 'Мама', ipAddress: '192.168.1.5',
      port: 8765, isOnline: false, lastSeen: 0,
    );
    await repo.upsert(c);
    final found = await repo.findById('uuid-1');
    expect(found?.name, equals('Мама'));
  });

  test('update online status', () async {
    final c = Contact(
      id: 'uuid-2', name: 'Папа', ipAddress: '192.168.1.6',
      port: 8765, isOnline: false, lastSeen: 0,
    );
    await repo.upsert(c);
    await repo.setOnline('uuid-2', true);
    final found = await repo.findById('uuid-2');
    expect(found?.isOnline, isTrue);
  });
}
