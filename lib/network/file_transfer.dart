import 'dart:convert';
import 'dart:typed_data';
import '../data/models/wire_message.dart';

class FileTransfer {
  static const defaultChunkSize = 64 * 1024; // 64KB

  static List<Uint8List> splitIntoChunks(Uint8List data, {int chunkSize = defaultChunkSize}) {
    final chunks = <Uint8List>[];
    for (var offset = 0; offset < data.length; offset += chunkSize) {
      final end = (offset + chunkSize).clamp(0, data.length);
      chunks.add(data.sublist(offset, end));
    }
    return chunks;
  }

  static Uint8List reassembleChunks(List<Uint8List> chunks) {
    final total = chunks.fold<int>(0, (sum, c) => sum + c.length);
    final result = Uint8List(total);
    var offset = 0;
    for (final chunk in chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return result;
  }

  static WireMessage encodeChunk({
    required String messageId,
    required String chatId,
    required String senderId,
    required String type,
    required String fileName,
    required int fileSize,
    required Uint8List chunk,
    required int chunkIndex,
    required int totalChunks,
    required int timestamp,
  }) =>
      WireMessage(
        id: messageId,
        chatId: chatId,
        senderId: senderId,
        type: type,
        content: base64Encode(chunk),
        fileName: fileName,
        fileSize: fileSize,
        chunkIndex: chunkIndex,
        totalChunks: totalChunks,
        timestamp: timestamp,
      );

  static Uint8List decodeChunkContent(String base64Content) => base64Decode(base64Content);
}
