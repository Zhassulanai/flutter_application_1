import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/message.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object?> get props => [];
}

class MessagesLoaded extends ChatEvent {
  final List<Message> messages;
  const MessagesLoaded(this.messages);
  @override
  List<Object?> get props => [messages];
}

class MessageAdded extends ChatEvent {
  final Message message;
  const MessageAdded(this.message);
  @override
  List<Object?> get props => [message];
}

class MessageStatusUpdated extends ChatEvent {
  final String messageId;
  final MessageStatus status;
  const MessageStatusUpdated(this.messageId, this.status);
  @override
  List<Object?> get props => [messageId, status];
}

class MessageDeleted extends ChatEvent {
  final String messageId;
  const MessageDeleted(this.messageId);
  @override
  List<Object?> get props => [messageId];
}

abstract class ChatState extends Equatable {
  const ChatState();
  @override
  List<Object?> get props => [];
}

class ChatLoaded extends ChatState {
  final List<Message> messages;
  const ChatLoaded(this.messages);
  @override
  List<Object?> get props => [messages];
}

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final String chatId;

  ChatBloc({required this.chatId}) : super(const ChatLoaded([])) {
    on<MessagesLoaded>(_onLoaded);
    on<MessageAdded>(_onAdded);
    on<MessageStatusUpdated>(_onStatusUpdated);
    on<MessageDeleted>(_onDeleted);
  }

  void _onLoaded(MessagesLoaded event, Emitter<ChatState> emit) {
    emit(ChatLoaded(event.messages));
  }

  void _onAdded(MessageAdded event, Emitter<ChatState> emit) {
    final current = (state as ChatLoaded).messages;
    emit(ChatLoaded([...current, event.message]));
  }

  void _onStatusUpdated(MessageStatusUpdated event, Emitter<ChatState> emit) {
    final current = (state as ChatLoaded).messages;
    final updated = current.map((m) {
      return m.id == event.messageId ? m.copyWith(status: event.status) : m;
    }).toList();
    emit(ChatLoaded(updated));
  }

  void _onDeleted(MessageDeleted event, Emitter<ChatState> emit) {
    final current = (state as ChatLoaded).messages;
    emit(ChatLoaded(current.where((m) => m.id != event.messageId).toList()));
  }
}
