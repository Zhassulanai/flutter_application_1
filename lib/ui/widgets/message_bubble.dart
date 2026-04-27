import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isOutgoing = message.isOutgoing;
    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isOutgoing
              ? const Color(0xFFDCF8C6)
              : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isOutgoing ? 12 : 0),
            bottomRight: Radius.circular(isOutgoing ? 0 : 12),
          ),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2, offset: const Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildContent(context),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                if (isOutgoing) ...[
                  const SizedBox(width: 4),
                  _statusIcon(),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (message.contentType) {
      case ContentType.text:
        return Text(message.content);
      case ContentType.image:
        if (message.filePath != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(message.filePath!),
              width: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Text('[Фото]'),
            ),
          );
        }
        return const Text('[Фото]');
      case ContentType.video:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam, size: 16),
            const SizedBox(width: 4),
            Text(message.content.isEmpty ? 'Видео' : message.content),
          ],
        );
      case ContentType.file:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.attach_file, size: 16),
            const SizedBox(width: 4),
            Flexible(child: Text(message.content, overflow: TextOverflow.ellipsis)),
          ],
        );
    }
  }

  Widget _statusIcon() {
    switch (message.status) {
      case MessageStatus.pending:
        return const Icon(Icons.access_time, size: 12, color: Colors.grey);
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 12, color: Colors.grey);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 12, color: Color(0xFF53BDEB));
    }
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
