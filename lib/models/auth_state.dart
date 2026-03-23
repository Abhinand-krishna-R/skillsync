import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';

/// Owns all Firebase Authentication state and actions.
/// AppState listens to this via [onAuthChanged] callback —
/// no circular dependency, no tight coupling.
class AuthState extends ChangeNotifier {
  final FirestoreService _firestoreService;

  // Called by AppState (or any listener) when auth state changes so it can
  // subscribe/unsubscribe Firestore data streams accordingly.
  final Future<void> Function(String? uid) onAuthChanged;

  User? _firebaseUser;
  bool _authLoading = true;
  StreamSubscription? _authSub;

  AuthState({
    required FirestoreService firestoreService,
    required this.onAuthChanged,
  }) : _firestoreService = firestoreService {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      _firebaseUser = user;
      _authLoading = false;
      notifyListeners();
      // Notify AppState so it can wire up or tear down data streams
      await onAuthChanged(user?.uid);
    });
  }

  // ── Getters ────────────────────────────────────────────────────
  User? get firebaseUser => _firebaseUser;
  bool get authLoading => _authLoading;
  bool get isLoggedIn => _firebaseUser != null;
  String? get uid => _firebaseUser?.uid;

  // ── Sign In ────────────────────────────────────────────────────
  Future<void> signIn(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // authStateChanges fires automatically — onAuthChanged handles the rest
    } catch (e) {
      debugPrint('AuthState.signIn error: $e');
      rethrow;
    }
  }

  // ── Register ───────────────────────────────────────────────────
  Future<void> register(String email, String password, String name) async {
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (cred.user != null) {
        // Create Firestore user doc BEFORE auth gate switches to MainScaffold
        await _firestoreService.setupNewUser(
          uid: cred.user!.uid,
          email: email,
          displayName: name,
        );
        // Manually set user so UI reacts immediately without waiting
        // for authStateChanges to propagate
        _firebaseUser = cred.user;
        _authLoading = false;
        notifyListeners();
        onAuthChanged(cred.user!.uid);
      }
    } catch (e) {
      debugPrint('AuthState.register error: $e');
      rethrow;
    }
  }

  // ── Ensure Profile (Repair Mode) ───────────────────────────────
  /// Creates the Firestore document for an existing Auth user if it's missing.
  Future<void> ensureProfileExists() async {
    if (_firebaseUser == null) throw Exception('No user logged in');
    try {
      await _firestoreService.setupNewUser(
        uid: _firebaseUser!.uid,
        email: _firebaseUser!.email ?? '',
        displayName: _firebaseUser!.displayName ?? 'SkillSync User',
      );
      await onAuthChanged(_firebaseUser!.uid);
      notifyListeners();
    } catch (e) {
      debugPrint('AuthState.ensureProfileExists error: $e');
      rethrow;
    }
  }

  // ── Sign Out ───────────────────────────────────────────────────
  Future<void> signOut() async {
    // Eagerly clear local auth state so UI transitions immediately
    _firebaseUser = null;
    notifyListeners();
    await onAuthChanged(null); // AppState clears its data streams
    await FirebaseAuth.instance.signOut();
  }

  // ── Reset Password ─────────────────────────────────────────────
  Future<void> resetPassword(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  // ── Delete Account ─────────────────────────────────────────────
  Future<void> deleteAccount() async {
    if (_firebaseUser == null) return;
    try {
      await _firestoreService.deleteUserAccount();
      await _firebaseUser!.delete();
    } catch (e) {
      debugPrint('AuthState.deleteAccount error: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
