import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class IdentityService {
  static const _keyId = 'own_id';
  static const _keyName = 'own_name';
  static const _keyAvatar = 'own_avatar';

  IdentityService._();
  static final IdentityService instance = IdentityService._();

  String _ownId = '';
  String _name = '';
  String? _avatarPath;

  String get ownId => _ownId;
  String get name => _name;
  String? get avatarPath => _avatarPath;

  Future<bool> isOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    _ownId = prefs.getString(_keyId) ?? '';
    _name = prefs.getString(_keyName) ?? '';
    _avatarPath = prefs.getString(_keyAvatar);
    return _name.isNotEmpty;
  }

  Future<void> saveIdentity({required String name, String? avatarPath}) async {
    final prefs = await SharedPreferences.getInstance();
    if (_ownId.isEmpty) {
      _ownId = const Uuid().v4();
      await prefs.setString(_keyId, _ownId);
    }
    _name = name;
    _avatarPath = avatarPath;
    await prefs.setString(_keyName, name);
    if (avatarPath != null) await prefs.setString(_keyAvatar, avatarPath);
  }

  Future<void> updateName(String name) => saveIdentity(name: name, avatarPath: _avatarPath);
  Future<void> updateAvatar(String path) => saveIdentity(name: _name, avatarPath: path);
}
