import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../blocs/chat/chat_bloc.dart';
import '../../data/database.dart';
import '../../data/models/chat.dart';
import '../../data/models/message.dart';
import '../../data/repositories/message_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../services/identity_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/attachment_sheet.dart';

class ChatScreen extends StatefulWidget {
  final Chat chat;
  const ChatScreen({super.key, required this.chat});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final ChatBloc _bloc;
  final _msgRepo = MessageRepository(AppDatabase.instance);
  final _chatRepo = ChatRepository(AppDatabase.instance);

  @override
  void initState() {
    super.initState();
    _bloc = ChatBloc(chatId: widget.chat.id);
    _loadMessages();
    _chatRepo.clearUnread(widget.chat.id);
  }

  Future<void> _loadMessages() async {
    final msgs = await _msgRepo.loadForChat(widget.chat.id, limit: 50, offset: 0);
    _bloc.add(MessagesLoaded(msgs));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    final msg = Message(
      id: const Uuid().v4(),
      chatId: widget.chat.id,
      senderId: IdentityService.instance.ownId,
      content: text,
      contentType: ContentType.text,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      status: MessageStatus.pending,
      isOutgoing: true,
    );
    await _msgRepo.insert(msg);
    await _chatRepo.updateLastMessage(widget.chat.id, text, msg.timestamp);
    _bloc.add(MessageAdded(msg));
    _scrollToBottom();
  }

  Future<void> _sendFile(String path, String type) async {
    final fileName = path.split(Platform.pathSeparator).last;
    final msg = Message(
      id: const Uuid().v4(),
      chatId: widget.chat.id,
      senderId: IdentityService.instance.ownId,
      content: fileName,
      contentType: ContentType.values.firstWhere((e) => e.name == type),
      filePath: path,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      status: MessageStatus.pending,
      isOutgoing: true,
    );
    await _msgRepo.insert(msg);
    await _chatRepo.updateLastMessage(widget.chat.id, fileName, msg.timestamp);
    _bloc.add(MessageAdded(msg));
    _scrollToBottom();
  }

  @override
  void dispose() {
    _bloc.close();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: const Color(0xFFECE5DD),
        appBar: AppBar(
          title: Text(widget.chat.name),
        ),
        body: Column(
          children: [
            Expanded(
              child: BlocBuilder<ChatBloc, ChatState>(
                builder: (context, state) {
                  final messages = state is ChatLoaded ? state.messages : <Message>[];
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, i) => GestureDetector(
                      onLongPress: () => _confirmDelete(messages[i]),
                      child: MessageBubble(message: messages[i]),
                    ),
                  );
                },
              ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (_) => AttachmentSheet(onFileSelected: _sendFile),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Сообщение',
                  border: InputBorder.none,
                ),
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 5,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF25D366)),
              onPressed: _sendText,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Message msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить сообщение?'),
        content: const Text('Сообщение будет удалено только у вас.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirmed == true) {
      await _msgRepo.deleteMessage(msg.id);
      _bloc.add(MessageDeleted(msg.id));
    }
  }
}
