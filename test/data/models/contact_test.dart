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

    test('round-trips through map with avatarPath and isOnline', () {
      final c = Contact(
        id: 'uuid-2',
        name: 'Папа',
        avatarPath: '/storage/avatar.jpg',
        ipAddress: '192.168.1.6',
        port: 8765,
        isOnline: true,
        lastSeen: 1714200001,
      );
      final restored = Contact.fromMap(c.toMap());
      expect(restored.avatarPath, equals('/storage/avatar.jpg'));
      expect(restored.isOnline, isTrue);
    });
  });
}
