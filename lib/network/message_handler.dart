import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../data/database.dart';
import '../data/models/message.dart';
import '../data/models/wire_message.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/contact_repository.dart';
import '../data/repositories/message_repository.dart';
import '../services/notification_service.dart';
import 'file_transfer.dart';

class IncomingMessageHandler {
  final _msgRepo = MessageRepository(AppDatabase.instance);
  final _chatRepo = ChatRepository(AppDatabase.instance);
  final _contactRepo = ContactRepository(AppDatabase.instance);

  // Accumulates incoming file chunks: messageId → chunk index → bytes
  final _chunkBuffers = <String, Map<int, Uint8List>>{};

  void Function(Message message)? onMessageReady;

  Future<void> handle(String raw) async {
    final wire = WireMessage.decode(raw);

    if (wire.totalChunks != null && wire.totalChunks! > 1) {
      await _handleChunk(wire);
      return;
    }

    final msg = Message(
      id: wire.id,
      chatId: wire.chatId,
      senderId: wire.senderId,
      content: wire.content,
      contentType: ContentType.values.firstWhere(
        (e) => e.name == wire.type,
        orElse: () => ContentType.text,
      ),
      timestamp: wire.timestamp,
      status: MessageStatus.delivered,
      isOutgoing: false,
    );

    await _msgRepo.insert(msg);
    await _chatRepo.updateLastMessage(wire.chatId, wire.content, wire.timestamp);
    await _chatRepo.incrementUnread(wire.chatId);

    final sender = await _contactRepo.findById(wire.senderId);
    final senderName = sender?.name ?? 'Кто-то';
    await NotificationService.instance.showMessageNotification(
      senderName: senderName,
      preview: wire.type == 'text' ? wire.content : '📎 ${wire.fileName ?? 'Файл'}',
      chatId: wire.chatId,
    );

    onMessageReady?.call(msg);
  }

  Future<void> _handleChunk(WireMessage wire) async {
    final msgId = wire.id;
    _chunkBuffers[msgId] ??= {};
    _chunkBuffers[msgId]![wire.chunkIndex!] = FileTransfer.decodeChunkContent(wire.content);

    if (_chunkBuffers[msgId]!.length < wire.totalChunks!) return;

    final sorted = List.generate(wire.totalChunks!, (i) => _chunkBuffers[msgId]![i]!);
    final bytes = FileTransfer.reassembleChunks(sorted);
    _chunkBuffers.remove(msgId);

    final dir = await _getMediaDir();
    final filePath = '${dir.path}/${wire.fileName ?? msgId}';
    await File(filePath).writeAsBytes(bytes);

    final msg = Message(
      id: msgId,
      chatId: wire.chatId,
      senderId: wire.senderId,
      content: wire.fileName ?? msgId,
      contentType: ContentType.values.firstWhere(
        (e) => e.name == wire.type,
        orElse: () => ContentType.file,
      ),
      filePath: filePath,
      timestamp: wire.timestamp,
      status: MessageStatus.delivered,
      isOutgoing: false,
    );

    await _msgRepo.insert(msg);
    await _chatRepo.updateLastMessage(wire.chatId, wire.fileName ?? 'Файл', wire.timestamp);
    await _chatRepo.incrementUnread(wire.chatId);
    onMessageReady?.call(msg);
  }

  Future<Directory> _getMediaDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/media');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }
}
