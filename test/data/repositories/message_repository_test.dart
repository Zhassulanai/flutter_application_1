import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_application_1/data/database.dart';
import 'package:flutter_application_1/data/repositories/message_repository.dart';
import 'package:flutter_application_1/data/models/message.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late MessageRepository repo;

  setUp(() async {
    db = AppDatabase.forTest();
    await db.open();
    repo = MessageRepository(db);
  });

  tearDown(() async => db.close());

  test('insert and load messages for chat', () async {
    final m = Message(
      id: 'msg-1', chatId: 'chat-1', senderId: 'me',
      content: 'Привет', contentType: ContentType.text,
      timestamp: 1000, status: MessageStatus.pending, isOutgoing: true,
    );
    await repo.insert(m);
    final list = await repo.loadForChat('chat-1', limit: 50, offset: 0);
    expect(list.length, equals(1));
    expect(list.first.content, equals('Привет'));
  });

  test('getPendingFor returns pending outgoing messages for recipient', () async {
    final m = Message(
      id: 'msg-2', chatId: 'chat-direct-abc', senderId: 'me',
      content: 'Оффлайн', contentType: ContentType.text,
      timestamp: 1001, status: MessageStatus.pending, isOutgoing: true,
    );
    await repo.insert(m);
    final pending = await repo.getPendingFor('abc');
    expect(pending.any((x) => x.id == 'msg-2'), isTrue);
  });
}
