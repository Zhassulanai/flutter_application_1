import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/data/models/message.dart';

void main() {
  group('Message', () {
    test('round-trips through map', () {
      final m = Message(
        id: 'msg-1',
        chatId: 'chat-1',
        senderId: 'uuid-1',
        content: 'Привет!',
        contentType: ContentType.text,
        filePath: null,
        timestamp: 1714200000,
        status: MessageStatus.pending,
        isOutgoing: true,
      );
      expect(Message.fromMap(m.toMap()), equals(m));
    });
  });
}
