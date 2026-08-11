import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../domain/user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final GoogleSignIn _googleSignIn;

  AuthRepository() {
    _googleSignIn = GoogleSignIn(
      clientId: kIsWeb
          ? '925861994797-80vrot56p4iimj07ho21h51khr8p21sm.apps.googleusercontent.com'
          : null,
    );
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user != null) {
        return await createUserInFirestoreIfNotExists(user);
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(
        e.message ?? 'Eroare de autentificare Google (${e.code})',
      );
    } catch (e) {
      throw Exception('Failed to sign in with Google: $e');
    }
    return null;
  }

  Future<UserModel?> signInWithEmail(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);
      final User? user = userCredential.user;
      if (user != null) {
        return await createUserInFirestoreIfNotExists(user);
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Eroare de autentificare email (${e.code})');
    } catch (e) {
      throw Exception('Failed to sign in with email: $e');
    }
    return null;
  }

  Future<UserModel?> signUpWithEmail(
    String email,
    String password,
    String name,
  ) async {
    try {
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      final User? user = userCredential.user;
      if (user != null) {
        await user.updateDisplayName(name);
        return await createUserInFirestoreIfNotExists(user, name: name);
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Eroare de înregistrare (${e.code})');
    } catch (e) {
      throw Exception('Failed to sign up with email: $e');
    }
    return null;
  }

  Future<UserModel> createUserInFirestoreIfNotExists(
    User user, {
    String? name,
    String? workType,
  }) async {
    final displayName = (name ?? user.displayName ?? '').trim();
    final mergedName = displayName.isNotEmpty ? displayName : 'Employee';

    await _ensureUserProfileDocument(
      user: user,
      name: mergedName,
      workType: workType,
    );

    final docRef = _firestore.collection('users').doc(user.uid);
    final docSnap = await docRef.get();

    if (!docSnap.exists) {
      throw Exception(
        'Profilul nu a putut fi creat. Verifică regulile Firestore (users) '
        'și că ești logat cu același cont.',
      );
    }

    return UserModel.fromMap(
      docSnap.data() as Map<String, dynamic>,
      docSnap.id,
    );
  }

  Future<UserModel?> getCurrentUserModel() async {
    final user = _auth.currentUser;
    if (user != null) {
      final docSnap = await _firestore.collection('users').doc(user.uid).get();
      if (docSnap.exists) {
        return UserModel.fromMap(
          docSnap.data() as Map<String, dynamic>,
          docSnap.id,
        );
      }
    }
    return null;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Eroare la resetarea parolei (${e.code})');
    } catch (e) {
      throw Exception('Failed to send reset email: $e');
    }
  }

  Future<void> setContractType({
    required String uid,
    required String contractType, // 'full_time' | 'part_time'
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'contractType': contractType,
      'needsContractType': false,
    }, SetOptions(merge: true));
  }

  Stream<List<UserModel>> getAllEmployees() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  Future<void> sendNotificationToAllEmployees({
    required String title,
    required String body,
  }) async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .get();

    for (var doc in snapshot.docs) {
      final fcmToken = doc.data()['fcmToken'] as String?;
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await _firestore.collection('notifications').add({
          'userId': doc.id,
          'title': title,
          'body': body,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    }
  }

  static const _adminNameTokens = ['malina', 'florin'];

  bool _isPredefinedAdmin(String displayName) {
    final normalized = displayName.trim().toLowerCase();
    return _adminNameTokens.any(normalized.contains);
  }

  /// Spark (free) plan: profile is created from the app, no Cloud Functions.
  Future<void> _ensureUserProfileDocument({
    required User user,
    required String name,
    String? workType,
  }) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final existing = await docRef.get();
    if (existing.exists) return;

    final resolvedWorkType = workType == 'Part-time'
        ? 'Part-time'
        : 'Full-time';
    final monthlyTargetHours = resolvedWorkType == 'Part-time' ? 80 : 160;
    final shouldBeAdmin = _isPredefinedAdmin(name);
    final providerId = user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : 'unknown';

    await docRef.set({
      'email': user.email ?? '',
      'name': name,
      'role': shouldBeAdmin ? 'admin' : 'employee',
      'workType': resolvedWorkType,
      'monthlyTargetHours': monthlyTargetHours,
      'primaryLocation': 'Gara',
      'secondaryLocation': 'Avantgarden',
      'fcmToken': null,
      'availability': null,
      'contractType': null,
      'needsContractType': true,
      'authProvider': providerId == 'password' ? 'email' : 'google',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
