import 'dart:io';

typedef MessageHandler = void Function(String message, WebSocket socket);

class WebSocketServer {
  static const defaultPort = 8765;

  HttpServer? _server;
  final _sockets = <WebSocket>[];
  MessageHandler? onMessage;

  int get port => _server?.port ?? defaultPort;

  Future<void> start({int port = defaultPort}) async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.transform(WebSocketTransformer()).listen(_handleSocket);
  }

  void _handleSocket(WebSocket ws) {
    _sockets.add(ws);
    ws.listen(
      (data) {
        if (data is String) onMessage?.call(data, ws);
      },
      onDone: () => _sockets.remove(ws),
      cancelOnError: true,
    );
  }

  void broadcast(String message) {
    for (final ws in List.of(_sockets)) {
      ws.add(message);
    }
  }

  Future<void> stop() async {
    final toClose = List.of(_sockets);
    _sockets.clear();
    for (final ws in toClose) {
      await ws.close();
    }
    await _server?.close(force: true);
    _server = null;
  }
}
