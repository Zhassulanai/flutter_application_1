import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/identity_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('isOnboarded returns false when no name set', () async {
    expect(await IdentityService.instance.isOnboarded(), isFalse);
  });

  test('saveIdentity persists name and generates UUID', () async {
    await IdentityService.instance.saveIdentity(name: 'Тест');
    expect(await IdentityService.instance.isOnboarded(), isTrue);
    expect(IdentityService.instance.name, equals('Тест'));
    expect(IdentityService.instance.ownId, isNotEmpty);
  });
}
