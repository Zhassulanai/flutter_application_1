import 'package:equatable/equatable.dart';

enum ContentType { text, image, video, file }

enum MessageStatus { pending, sent, delivered }

class Message extends Equatable {
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final ContentType contentType;
  final String? filePath;
  final int timestamp;
  final MessageStatus status;
  final bool isOutgoing;

  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.contentType,
    this.filePath,
    required this.timestamp,
    required this.status,
    required this.isOutgoing,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'chat_id': chatId,
        'sender_id': senderId,
        'content': content,
        'content_type': contentType.name,
        'file_path': filePath,
        'timestamp': timestamp,
        'status': status.name,
        'is_outgoing': isOutgoing ? 1 : 0,
      };

  factory Message.fromMap(Map<String, dynamic> m) => Message(
        id: m['id'] as String,
        chatId: m['chat_id'] as String,
        senderId: m['sender_id'] as String,
        content: m['content'] as String,
        contentType: ContentType.values.firstWhere((e) => e.name == m['content_type']),
        filePath: m['file_path'] as String?,
        timestamp: m['timestamp'] as int,
        status: MessageStatus.values.firstWhere((e) => e.name == m['status']),
        isOutgoing: (m['is_outgoing'] as int) == 1,
      );

  Message copyWith({MessageStatus? status, String? filePath}) => Message(
        id: id,
        chatId: chatId,
        senderId: senderId,
        content: content,
        contentType: contentType,
        filePath: filePath ?? this.filePath,
        timestamp: timestamp,
        status: status ?? this.status,
        isOutgoing: isOutgoing,
      );

  @override
  List<Object?> get props =>
      [id, chatId, senderId, content, contentType, filePath, timestamp, status, isOutgoing];
}
