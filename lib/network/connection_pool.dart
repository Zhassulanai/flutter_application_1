import 'websocket_client.dart';

class ConnectionPool {
  final _clients = <String, WebSocketClient>{};

  void Function(String peerId, String message)? onMessage;
  void Function(String peerId)? onDisconnected;

  bool isConnected(String peerId) => _clients[peerId]?.isConnected ?? false;

  Future<void> connect(String peerId, String ip, int port) async {
    if (isConnected(peerId)) return;
    final client = WebSocketClient(peerId: peerId, ip: ip, port: port);
    client.onMessage = (msg) => onMessage?.call(peerId, msg);
    client.onDisconnected = () {
      _clients.remove(peerId);
      onDisconnected?.call(peerId);
    };
    await client.connect();
    if (client.isConnected) _clients[peerId] = client;
  }

  void send(String peerId, String message) => _clients[peerId]?.send(message);

  void sendAll(String message) {
    for (final c in _clients.values) {
      c.send(message);
    }
  }

  Future<void> disconnect(String peerId) async {
    await _clients.remove(peerId)?.close();
  }

  Future<void> closeAll() async {
    for (final c in List.of(_clients.values)) {
      await c.close();
    }
    _clients.clear();
  }

  List<String> get connectedPeerIds => _clients.keys.toList();
}
