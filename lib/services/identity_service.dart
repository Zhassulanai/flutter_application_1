class IdentityService {
  static final IdentityService instance = IdentityService._();
  IdentityService._();

  Future<bool> isOnboarded() async => false;
}
