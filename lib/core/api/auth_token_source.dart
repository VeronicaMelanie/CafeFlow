import 'package:firebase_auth/firebase_auth.dart';

/// Source of Firebase ID tokens. Firebase Auth remains the identity system;
/// this only reads the current user's token. It does not sign in or sign out.
abstract class AuthTokenSource {
  Future<String?> getIdToken({bool forceRefresh = false});
}

class FirebaseAuthTokenSource implements AuthTokenSource {
  FirebaseAuthTokenSource({FirebaseAuth? auth}) : _auth = auth;

  final FirebaseAuth? _auth;

  FirebaseAuth get _firebaseAuth => _auth ?? FirebaseAuth.instance;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }
}
