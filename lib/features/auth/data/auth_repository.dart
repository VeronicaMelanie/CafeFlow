import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../domain/user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        return await createUserInFirestoreIfNotExists(user);
      }
    } catch (e) {
      throw Exception('Failed to sign in with Google: $e');
    }
    return null;
  }

  Future<UserModel?> signInWithEmail(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = userCredential.user;
      if (user != null) {
        final docSnap = await _firestore.collection('users').doc(user.uid).get();
        if (docSnap.exists) {
          return UserModel.fromMap(docSnap.data() as Map<String, dynamic>, docSnap.id);
        }
      }
    } catch (e) {
      throw Exception('Failed to sign in with email: $e');
    }
    return null;
  }

  Future<UserModel?> signUpWithEmail(String email, String password, String name, String workType) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = userCredential.user;
      if (user != null) {
        await user.updateDisplayName(name);
        return await createUserInFirestoreIfNotExists(user, name: name, workType: workType);
      }
    } catch (e) {
      throw Exception('Failed to sign up with email: $e');
    }
    return null;
  }

  Future<UserModel> createUserInFirestoreIfNotExists(User user, {String? name, String? workType}) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final docSnap = await docRef.get();

    if (!docSnap.exists) {
      final newUser = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        name: name ?? user.displayName ?? '',
        role: 'employee', // Default role
        workType: workType ?? 'Full-time',
        monthlyTargetHours: (workType == 'Part-time') ? 80 : 160,
        primaryLocation: 'Gara',
        secondaryLocation: 'Avantgarden',
      );
      await docRef.set(newUser.toMap());
      return newUser;
    }

    return UserModel.fromMap(docSnap.data() as Map<String, dynamic>, docSnap.id);
  }

  Future<UserModel?> getCurrentUserModel() async {
    final user = _auth.currentUser;
    if (user != null) {
      final docSnap = await _firestore.collection('users').doc(user.uid).get();
      if (docSnap.exists) {
        return UserModel.fromMap(docSnap.data() as Map<String, dynamic>, docSnap.id);
      }
    }
    return null;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
