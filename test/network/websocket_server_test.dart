import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/io.dart';
import 'package:flutter_application_1/network/websocket_server.dart';

void main() {
  late WebSocketServer server;

  setUp(() async {
    server = WebSocketServer();
    await server.start(port: 0);
  });

  tearDown(() async => server.stop());

  test('accepts connections and receives messages via onMessage', () async {
    final received = <String>[];
    server.onMessage = (msg, _) => received.add(msg);

    final client = IOWebSocketChannel.connect('ws://127.0.0.1:${server.port}');
    client.sink.add('hello');
    await Future.delayed(const Duration(milliseconds: 200));
    expect(received, contains('hello'));
    await client.sink.close();
  });
}
