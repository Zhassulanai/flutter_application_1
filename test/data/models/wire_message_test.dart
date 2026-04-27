import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/data/models/wire_message.dart';

void main() {
  group('WireMessage', () {
    test('encodes and decodes JSON — text message', () {
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
      expect(decoded.chatId, equals(w.chatId));
      expect(decoded.senderId, equals(w.senderId));
      expect(decoded.type, equals(w.type));
      expect(decoded.content, equals(w.content));
      expect(decoded.timestamp, equals(w.timestamp));
      expect(decoded.fileName, isNull);
    });

    test('encodes and decodes JSON — file chunk with all fields', () {
      final w = WireMessage(
        id: 'msg-2',
        chatId: 'chat-2',
        senderId: 'uuid-2',
        type: 'image',
        content: 'base64data',
        fileName: 'photo.jpg',
        fileSize: 204800,
        chunkIndex: 0,
        totalChunks: 4,
        timestamp: 1714200001,
      );
      final decoded = WireMessage.fromJson(w.toJson());
      expect(decoded.fileName, equals('photo.jpg'));
      expect(decoded.fileSize, equals(204800));
      expect(decoded.chunkIndex, equals(0));
      expect(decoded.totalChunks, equals(4));
    });

    test('encode and decode round-trips via string', () {
      final w = WireMessage(
        id: 'msg-3',
        chatId: 'chat-1',
        senderId: 'uid',
        type: 'text',
        content: 'Test',
        timestamp: 1000,
      );
      final decoded = WireMessage.decode(w.encode());
      expect(decoded.id, equals(w.id));
      expect(decoded.content, equals(w.content));
    });
  });
}
