import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

class WebSocketClient {
  final String peerId;
  final String ip;
  final int port;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _connected = false;

  void Function(String message)? onMessage;
  void Function()? onDisconnected;

  WebSocketClient({required this.peerId, required this.ip, required this.port});

  bool get isConnected => _connected;

  Future<void> connect() async {
    try {
      _channel = IOWebSocketChannel.connect('ws://$ip:$port');
      _connected = true;
      _sub = _channel!.stream.listen(
        (data) {
          if (data is String) onMessage?.call(data);
        },
        onDone: _handleDisconnect,
        onError: (_) => _handleDisconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _connected = false;
    }
  }

  void send(String message) {
    if (_connected) _channel?.sink.add(message);
  }

  void _handleDisconnect() {
    _connected = false;
    onDisconnected?.call();
  }

  Future<void> close() async {
    _connected = false;
    await _sub?.cancel();
    await _channel?.sink.close();
  }
}
