import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/data/models/contact.dart';

void main() {
  group('Contact', () {
    test('round-trips through map', () {
      final c = Contact(
        id: 'uuid-1',
        name: 'Мама',
        avatarPath: null,
        ipAddress: '192.168.1.5',
        port: 8765,
        isOnline: false,
        lastSeen: 1714200000,
      );
      expect(Contact.fromMap(c.toMap()), equals(c));
    });
  });
}
