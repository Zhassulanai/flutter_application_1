import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

// Events
abstract class NetworkEvent extends Equatable {
  const NetworkEvent();
  @override
  List<Object?> get props => [];
}

class NetworkStarted extends NetworkEvent {
  const NetworkStarted();
}
class NetworkStopped extends NetworkEvent {
  const NetworkStopped();
}
class PeerConnected extends NetworkEvent {
  final String peerId;
  const PeerConnected(this.peerId);
  @override
  List<Object?> get props => [peerId];
}
class PeerDisconnected extends NetworkEvent {
  final String peerId;
  const PeerDisconnected(this.peerId);
  @override
  List<Object?> get props => [peerId];
}
class MessageReceived extends NetworkEvent {
  final String peerId;
  final String raw;
  const MessageReceived(this.peerId, this.raw);
  @override
  List<Object?> get props => [peerId, raw];
}

// States
abstract class NetworkState extends Equatable {
  const NetworkState();
  @override
  List<Object?> get props => [];
}

class NetworkDisconnected extends NetworkState {
  const NetworkDisconnected();
}
class NetworkRunning extends NetworkState {
  final List<String> connectedPeerIds;
  const NetworkRunning(this.connectedPeerIds);
  @override
  List<Object?> get props => [connectedPeerIds];
}

// Bloc
class NetworkBloc extends Bloc<NetworkEvent, NetworkState> {
  NetworkBloc() : super(const NetworkDisconnected()) {
    on<NetworkStarted>(_onStarted);
    on<NetworkStopped>(_onStopped);
    on<PeerConnected>(_onPeerConnected);
    on<PeerDisconnected>(_onPeerDisconnected);
  }

  final _connected = <String>[];

  void _onStarted(NetworkStarted event, Emitter<NetworkState> emit) {
    emit(NetworkRunning(List.of(_connected)));
  }

  void _onStopped(NetworkStopped event, Emitter<NetworkState> emit) {
    _connected.clear();
    emit(const NetworkDisconnected());
  }

  void _onPeerConnected(PeerConnected event, Emitter<NetworkState> emit) {
    if (!_connected.contains(event.peerId)) _connected.add(event.peerId);
    emit(NetworkRunning(List.of(_connected)));
  }

  void _onPeerDisconnected(PeerDisconnected event, Emitter<NetworkState> emit) {
    _connected.remove(event.peerId);
    emit(NetworkRunning(List.of(_connected)));
  }
}
