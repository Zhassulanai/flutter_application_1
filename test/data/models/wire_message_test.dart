import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/data/models/wire_message.dart';

void main() {
  group('WireMessage', () {
    test('encodes and decodes JSON', () {
      final w = WireMessage(
        id: 'msg-1',
        chatId: 'chat-1',
        senderId: 'uuid-sender',
        type: 'text',
        content: 'Hello',
        fileName: null,
        fileSize: null,
        chunkIndex: null,
        totalChunks: null,
        timestamp: 1714200000,
      );
      final decoded = WireMessage.fromJson(w.toJson());
      expect(decoded.id, equals(w.id));
      expect(decoded.content, equals(w.content));
    });
  });
}
