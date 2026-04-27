import 'package:equatable/equatable.dart';

class Contact extends Equatable {
  final String id;
  final String name;
  final String? avatarPath;
  final String ipAddress;
  final int port;
  final bool isOnline;
  final int lastSeen;

  const Contact({
    required this.id,
    required this.name,
    this.avatarPath,
    required this.ipAddress,
    required this.port,
    required this.isOnline,
    required this.lastSeen,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'avatar_path': avatarPath,
        'ip_address': ipAddress,
        'port': port,
        'is_online': isOnline ? 1 : 0,
        'last_seen': lastSeen,
      };

  factory Contact.fromMap(Map<String, dynamic> m) => Contact(
        id: m['id'] as String,
        name: m['name'] as String,
        avatarPath: m['avatar_path'] as String?,
        ipAddress: m['ip_address'] as String,
        port: m['port'] as int,
        isOnline: (m['is_online'] as int) == 1,
        lastSeen: m['last_seen'] as int,
      );

  Contact copyWith({
    String? name,
    String? avatarPath,
    String? ipAddress,
    int? port,
    bool? isOnline,
    int? lastSeen,
  }) =>
      Contact(
        id: id,
        name: name ?? this.name,
        avatarPath: avatarPath ?? this.avatarPath,
        ipAddress: ipAddress ?? this.ipAddress,
        port: port ?? this.port,
        isOnline: isOnline ?? this.isOnline,
        lastSeen: lastSeen ?? this.lastSeen,
      );

  @override
  List<Object?> get props => [id, name, avatarPath, ipAddress, port, isOnline, lastSeen];
}
