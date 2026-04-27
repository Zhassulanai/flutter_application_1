import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/network/connection_pool.dart';

void main() {
  test('isConnected returns false for unknown peer', () {
    final pool = ConnectionPool();
    expect(pool.isConnected('unknown-peer'), isFalse);
  });
}
