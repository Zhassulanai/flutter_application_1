import 'package:equatable/equatable.dart';

class Recording extends Equatable {
  final String id;
  final String filePath;
  final DateTime createdAt;
  final int durationMs;
  final int sizeBytes;

  const Recording({
    required this.id,
    required this.filePath,
    required this.createdAt,
    required this.durationMs,
    required this.sizeBytes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'file_path': filePath,
        'created_at': createdAt.millisecondsSinceEpoch,
        'duration_ms': durationMs,
        'size_bytes': sizeBytes,
      };

  factory Recording.fromMap(Map<String, dynamic> map) => Recording(
        id: map['id'] as String,
        filePath: map['file_path'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        durationMs: map['duration_ms'] as int,
        sizeBytes: map['size_bytes'] as int,
      );

  @override
  List<Object?> get props => [id, filePath, createdAt, durationMs, sizeBytes];
}
