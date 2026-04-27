import 'package:equatable/equatable.dart';

enum ChatType { direct, group }

class Chat extends Equatable {
  final String id;
  final ChatType type;
  final String name;
  final String lastMessage;
  final int lastMessageTime;
  final int unreadCount;

  const Chat({
    required this.id,
    required this.type,
    required this.name,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'name': name,
        'last_message': lastMessage,
        'last_message_time': lastMessageTime,
        'unread_count': unreadCount,
      };

  factory Chat.fromMap(Map<String, dynamic> m) => Chat(
        id: m['id'] as String,
        type: ChatType.values.firstWhere((e) => e.name == m['type']),
        name: m['name'] as String,
        lastMessage: m['last_message'] as String,
        lastMessageTime: m['last_message_time'] as int,
        unreadCount: m['unread_count'] as int,
      );

  Chat copyWith({String? name, String? lastMessage, int? lastMessageTime, int? unreadCount}) =>
      Chat(
        id: id,
        type: type,
        name: name ?? this.name,
        lastMessage: lastMessage ?? this.lastMessage,
        lastMessageTime: lastMessageTime ?? this.lastMessageTime,
        unreadCount: unreadCount ?? this.unreadCount,
      );

  @override
  List<Object?> get props => [id, type, name, lastMessage, lastMessageTime, unreadCount];
}
