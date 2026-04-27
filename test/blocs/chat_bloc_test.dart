import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/blocs/chat/chat_bloc.dart';
import 'package:flutter_application_1/data/models/message.dart';

void main() {
  test('initial state has empty messages', () {
    final bloc = ChatBloc(chatId: 'chat-1');
    expect(bloc.state, isA<ChatLoaded>());
    expect((bloc.state as ChatLoaded).messages, isEmpty);
    bloc.close();
  });

  test('MessageAdded appends message to state', () async {
    final bloc = ChatBloc(chatId: 'chat-1');
    final msg = Message(
      id: 'msg-1', chatId: 'chat-1', senderId: 'me',
      content: 'Привет', contentType: ContentType.text,
      timestamp: 1000, status: MessageStatus.sent, isOutgoing: true,
    );
    bloc.add(MessageAdded(msg));
    await Future.delayed(Duration.zero);
    final state = bloc.state as ChatLoaded;
    expect(state.messages.length, equals(1));
    bloc.close();
  });
}
