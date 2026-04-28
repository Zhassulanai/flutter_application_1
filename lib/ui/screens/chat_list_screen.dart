import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/contacts/contacts_bloc.dart';
import '../../data/models/chat.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/database.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/online_indicator.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'video_recorder_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Chat> _chats = [];
  final _chatRepo = ChatRepository(AppDatabase.instance);

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    final chats = await _chatRepo.getAll();
    setState(() => _chats = chats);
  }

  String _formatTime(int timestamp) {
    if (timestamp == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    if (dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}.${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ContactsBloc, ContactsState>(
      builder: (context, state) {
        final contacts = state is ContactsLoaded ? state.contacts : [];
        final onlineCount = contacts.where((c) => c.isOnline).length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('FamilyChat'),
            actions: [
              IconButton(
                icon: const Icon(Icons.videocam),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VideoRecorderScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.person),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              OnlineIndicator(onlineCount: onlineCount, totalCount: contacts.length),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadChats,
                  child: _chats.isEmpty
                      ? const Center(
                          child: Text(
                            'Нет чатов\nОткройте приложение на другом устройстве',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _chats.length,
                          itemBuilder: (context, i) {
                            final chat = _chats[i];
                            return ListTile(
                              leading: AvatarWidget(name: chat.name, radius: 24),
                              title: Text(
                                chat.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                chat.lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatTime(chat.lastMessageTime),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  if (chat.unreadCount > 0)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${chat.unreadCount}',
                                        style: const TextStyle(color: Colors.white, fontSize: 11),
                                      ),
                                    ),
                                ],
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ChatScreen(chat: chat)),
                              ).then((_) => _loadChats()),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
