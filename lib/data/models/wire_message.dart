import 'dart:convert';

class WireMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String type;
  final String content;
  final String? fileName;
  final int? fileSize;
  final int? chunkIndex;
  final int? totalChunks;
  final int timestamp;

  const WireMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.type,
    required this.content,
    this.fileName,
    this.fileSize,
    this.chunkIndex,
    this.totalChunks,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'chat_id': chatId,
        'sender_id': senderId,
        'type': type,
        'content': content,
        if (fileName != null) 'file_name': fileName,
        if (fileSize != null) 'file_size': fileSize,
        if (chunkIndex != null) 'chunk_index': chunkIndex,
        if (totalChunks != null) 'total_chunks': totalChunks,
        'timestamp': timestamp,
      };

  factory WireMessage.fromJson(Map<String, dynamic> j) => WireMessage(
        id: j['id'] as String,
        chatId: j['chat_id'] as String,
        senderId: j['sender_id'] as String,
        type: j['type'] as String,
        content: j['content'] as String? ?? '',
        fileName: j['file_name'] as String?,
        fileSize: j['file_size'] as int?,
        chunkIndex: j['chunk_index'] as int?,
        totalChunks: j['total_chunks'] as int?,
        timestamp: j['timestamp'] as int,
      );

  String encode() => jsonEncode(toJson());

  static WireMessage decode(String raw) => WireMessage.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
