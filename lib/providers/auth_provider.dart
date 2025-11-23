import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../models/franchise_model.dart';

enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.initial;
  UserModel? _currentUser;
  FranchiseModel? _currentFranchise;
  String? _errorMessage;
  bool _devBypass = false;
  
  // Getters
  AuthState get state => _state;
  UserModel? get currentUser => _currentUser;
  FranchiseModel? get currentFranchise => _currentFranchise;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _state == AuthState.authenticated && _currentUser != null;
  bool get isLoading => _state == AuthState.loading;
  bool get hasError => _state == AuthState.error;
  bool get devBypass => _devBypass;

  // Firebase Auth instance
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthProvider() {
    _initializeAuthState();
  }

  void _initializeAuthState() {
    // Listen to Firebase Auth state changes
    _firebaseAuth.authStateChanges().listen((User? user) {
      if (user != null) {
        _loadUserData(user.uid);
      } else {
        _setUnauthenticated();
      }
    });
  }

  Future<void> _loadUserData(String userId) async {
    try {
      _setState(AuthState.loading);
      
      // Get user document from Firestore
      DocumentSnapshot<Map<String, dynamic>>? userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        // Fallback: find by email if document id != Firebase UID
        final email = _firebaseAuth.currentUser?.email;
        if (email != null) {
          final byEmail = await _firestore
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
          if (byEmail.docs.isNotEmpty) {
            userDoc = byEmail.docs.first;
          }
        }
      }
      
      if (userDoc.exists) {
        _currentUser = UserModel.fromMap(userDoc.data()!);
        
        // Ensure franchise linkage is present for franchise owners
        if (_currentUser!.franchiseId == null || _currentUser!.franchiseId!.isEmpty) {
          // Fallback: derive franchise by ownerId for franchise owners
          if (_currentUser!.role == UserRole.franchiseOwner) {
            try {
              final owned = await _firestore
                  .collection('franchises')
                  .where('ownerId', isEqualTo: _currentUser!.id)
                  .limit(1)
                  .get();
              if (owned.docs.isNotEmpty) {
                final fdoc = owned.docs.first;
                _currentFranchise = FranchiseModel.fromMap(fdoc.data());
                // Update local user model to include franchiseId
                _currentUser = _currentUser!.copyWith(franchiseId: fdoc.id);
                // Persist franchiseId on user document for future loads (best-effort)
                try {
                  await _firestore.collection('users').doc(_currentUser!.id).update({'franchiseId': fdoc.id});
                } catch (_) {}
              }
            } catch (e) {
              // Graceful fallback; leave franchiseId unset if lookup fails
              debugPrint('Fallback franchise lookup failed: $e');
            }
          }
        }

        // Load franchise data if user has a franchise
        if (_currentUser!.franchiseId != null && _currentUser!.franchiseId!.isNotEmpty) {
          await _loadFranchiseData(_currentUser!.franchiseId!);
        }
        
        _setState(AuthState.authenticated);
      } else {
        _setError('User data not found');
      }
    } catch (e) {
      _setError('Failed to load user data: $e');
    }
  }

  Future<void> _loadFranchiseData(String franchiseId) async {
    try {
      final franchiseDoc = await _firestore.collection('franchises').doc(franchiseId).get();
      
      if (franchiseDoc.exists) {
        _currentFranchise = FranchiseModel.fromMap(franchiseDoc.data()!);
      }
    } catch (e) {
      print('Error loading franchise data: $e');
    }
  }

  Future<void> signOut() async {
    try {
      _setState(AuthState.loading);
      await _firebaseAuth.signOut();
      _currentUser = null;
      _currentFranchise = null;
      _setState(AuthState.unauthenticated);
    } catch (e) {
      _setError('Failed to sign out: $e');
    }
  }

  Future<void> refreshUserData() async {
    if (_currentUser != null) {
      await _loadUserData(_currentUser!.id);
    }
  }

  void _setState(AuthState newState) {
    _state = newState;
    _errorMessage = null;
    notifyListeners();
  }

  void _setUnauthenticated() {
    _state = AuthState.unauthenticated;
    _currentUser = null;
    _currentFranchise = null;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _state = AuthState.error;
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    if (_state == AuthState.error) {
      _setState(_currentUser != null ? AuthState.authenticated : AuthState.unauthenticated);
    }
  }

  // Dev bypass to skip setup checks (phone verification, password update)
  void setDevBypass(bool enabled) {
    _devBypass = enabled;
    notifyListeners();
  }

  // Helper methods for checking user status and permissions
  bool get isStaff => _currentUser?.role == UserRole.staff;
  bool get isFranchiseOwner => _currentUser?.role == UserRole.franchiseOwner;
  
  bool get needsPhoneVerification => false;
  
  bool get needsPasswordUpdate => !_devBypass && (
      _currentUser?.status == UserStatus.phoneVerified);
  
  bool get isFullySetup => _currentUser?.status == UserStatus.active;
  
  bool get isSuspended => _currentUser?.status == UserStatus.suspended;

  // Get the appropriate route based on user state
  String getInitialRoute() {
    if (!isAuthenticated) {
      return '/login';
    }

    if (isSuspended) {
      return '/suspended';
    }

    if (needsPhoneVerification) {
      return '/phone-verification';
    }

    if (needsPasswordUpdate) {
      return '/password-update';
    }

    if (isFullySetup) {
      return '/dashboard';
    }

    return '/login';
  }

  // Update user status locally (useful after completing verification steps)
  void updateUserStatus(UserStatus newStatus) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(status: newStatus);
      notifyListeners();
    }
  }

  // Update user data locally
  void updateUser(UserModel updatedUser) {
    _currentUser = updatedUser;
    notifyListeners();
  }

  // Update franchise data locally
  void updateFranchise(FranchiseModel updatedFranchise) {
    _currentFranchise = updatedFranchise;
    notifyListeners();
  }
}