import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:async';

import '../models/user_model.dart';
import '../models/franchise_model.dart';
import '../models/auth_models.dart';
import 'email_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const Uuid _uuid = Uuid();

  // Normalize franchise id values: accept raw id, document path string, or DocumentReference
  static String _normalizeFranchiseId(dynamic value) {
    if (value == null) return '';
    if (value is String) {
      final match = RegExp(r"/franchises/([^/]+)$").firstMatch(value);
      return match != null ? (match.group(1) ?? value) : value;
    }
    if (value is DocumentReference) {
      return value.id;
    }
    return value.toString();
  }

  // Collections
  static const String _usersCollection = 'users';
  static const String _franchisesCollection = 'franchises';
  static const String _verificationCollection = 'phone_verifications';

  /// Get current user
  static User? get currentUser => _auth.currentUser;

  /// Get current user data
  static Future<UserModel?> getCurrentUserData() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection(_usersCollection).doc(user.uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
    } catch (e) {
      print('Error getting current user data: $e');
    }
    return null;
  }

  /// Register franchise owner
  static Future<AuthResponse> registerFranchiseOwner(
    FranchiseOwnerRegistrationRequest request,
  ) async {
    try {
      // Create Firebase Auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: request.email,
        password: request.password,
      );

      final user = userCredential.user!;
      final franchiseId = _uuid.v4();

      // Create franchise document
      final franchise = FranchiseModel(
        id: franchiseId,
        name: request.franchiseName,
        address: request.franchiseAddress,
        contactEmail: request.email,
        contactPhone: request.contactPhone,
        ownerId: user.uid,
        createdAt: DateTime.now(),
      );

      // Create user document
      final userModel = UserModel(
        id: user.uid,
        email: request.email,
        firstName: request.firstName,
        lastName: request.lastName,
        role: UserRole.franchiseOwner,
        status: UserStatus.active,
        franchiseId: franchiseId,
        createdAt: DateTime.now(),
      );

      // Save to Firestore
      await _firestore.collection(_franchisesCollection).doc(franchiseId).set(franchise.toMap());
      await _firestore.collection(_usersCollection).doc(user.uid).set(userModel.toMap());

      return AuthResponse.success(
        message: 'Franchise owner registered successfully',
        data: {'userId': user.uid, 'franchiseId': franchiseId},
      );
    } on FirebaseAuthException catch (e) {
      return AuthResponse.error(
        message: _getAuthErrorMessage(e.code),
        errorCode: e.code,
      );
    } catch (e) {
      return AuthResponse.error(message: 'Registration failed: $e');
    }
  }

  /// Register staff member (called by franchise owner)
  static Future<AuthResponse> registerStaff({
    required String franchiseId,
    required String email,
    required String firstName,
    required String lastName,
    required String franchiseOwnerId,
  }) async {
    try {
      // Verify franchise owner permissions
      final ownerDocById = await _firestore.collection(_usersCollection).doc(franchiseOwnerId).get();
      Map<String, dynamic>? ownerRaw;

      if (ownerDocById.exists) {
        ownerRaw = ownerDocById.data();
      } else {
        // Fallback 1: match a document whose 'id' field equals the provided franchiseOwnerId
        final byIdField = await _firestore
            .collection(_usersCollection)
            .where('id', isEqualTo: franchiseOwnerId)
            .limit(1)
            .get();
        if (byIdField.docs.isNotEmpty) {
          ownerRaw = byIdField.docs.first.data();
        } else {
          // Fallback 2: use the currently authenticated email to locate the owner document
          final email = _auth.currentUser?.email;
          if (email != null) {
            final byEmail = await _firestore
                .collection(_usersCollection)
                .where('email', isEqualTo: email)
                .limit(1)
                .get();
            if (byEmail.docs.isNotEmpty) {
              ownerRaw = byEmail.docs.first.data();
            }
          }
        }
      }

      if (ownerRaw == null) {
        return AuthResponse.error(message: 'Unauthorized: Invalid franchise owner');
      }

      final ownerData = UserModel.fromMap(ownerRaw);
      if (ownerData.role != UserRole.franchiseOwner) {
        return AuthResponse.error(message: 'Unauthorized: Invalid permissions');
      }

      // Allow franchise owners with multiple franchises; validate membership against all known schema variants
      final Map<String, dynamic> raw = ownerRaw;
      final Set<String> allowedFranchiseIds = {
        if (ownerData.franchiseId != null && ownerData.franchiseId!.isNotEmpty)
          ownerData.franchiseId!,
      };
      final fi = raw['franchiseID'];
      if (fi is Map<String, dynamic>) {
        final idField = _normalizeFranchiseId(fi['id']);
        if (idField.isNotEmpty) {
          allowedFranchiseIds.add(idField);
        }
        final ids = fi['ids'];
        if (ids is List) {
          for (final v in ids) {
            final norm = _normalizeFranchiseId(v);
            if (norm.isNotEmpty) allowedFranchiseIds.add(norm);
          }
        }
        final single = fi['franchise'];
        final singleNorm = _normalizeFranchiseId(single);
        if (singleNorm.isNotEmpty) allowedFranchiseIds.add(singleNorm);
        final refs = fi['franchises'];
        if (refs is List) {
          for (final r in refs) {
            final norm = _normalizeFranchiseId(r);
            if (norm.isNotEmpty) allowedFranchiseIds.add(norm);
          }
        } else {
          // Some schemas store a single path string under 'franchises'
          final norm = _normalizeFranchiseId(refs);
          if (norm.isNotEmpty) allowedFranchiseIds.add(norm);
        }
      }

      final requestedId = _normalizeFranchiseId(franchiseId);
      if (!allowedFranchiseIds.contains(requestedId)) {
        return AuthResponse.error(message: 'Unauthorized: Invalid permissions');
      }

      // Check if email already exists
      final existingUsers = await _firestore
          .collection(_usersCollection)
          .where('email', isEqualTo: email)
          .get();

      if (existingUsers.docs.isNotEmpty) {
        return AuthResponse.error(message: 'Email already registered');
      }

      // Generate temporary password
      final temporaryPassword = EmailService.generateTemporaryPassword();
      final hashedPassword = _hashPassword(temporaryPassword);

      // Create staff user document (without Firebase Auth initially)
      final staffId = _uuid.v4();
      final staffUser = UserModel(
        id: staffId,
        email: email,
        firstName: firstName,
        lastName: lastName,
        role: UserRole.staff,
        status: UserStatus.pending,
        franchiseId: franchiseId,
        createdAt: DateTime.now(),
        isTemporaryPassword: true,
        metadata: {'hashedTempPassword': hashedPassword},
      );

      // Save staff user and include map-based franchiseID for schema compatibility
      final franchiseRef = _firestore.collection(_franchisesCollection).doc(franchiseId);
      final staffMap = staffUser.toMap();
      staffMap['franchiseID'] = {
        'franchise': franchiseRef,
        'id': franchiseId,
      };
      await _firestore.collection(_usersCollection).doc(staffId).set(staffMap);

      // Update franchise staff list
      await _firestore.collection(_franchisesCollection).doc(franchiseId).update({
        'staffIds': FieldValue.arrayUnion([staffId]),
      });

      // Get franchise data for email
      final franchiseDoc = await _firestore.collection(_franchisesCollection).doc(franchiseId).get();
      final franchise = FranchiseModel.fromMap(franchiseDoc.data()!);

      // Send email with temporary password
      final emailSent = await EmailService.sendTemporaryPasswordEmail(
        recipientEmail: email,
        staffName: '$firstName $lastName',
        franchiseName: franchise.name,
        temporaryPassword: temporaryPassword,
      );

      if (!emailSent) {
        // Rollback if email failed
        await _firestore.collection(_usersCollection).doc(staffId).delete();
        await _firestore.collection(_franchisesCollection).doc(franchiseId).update({
          'staffIds': FieldValue.arrayRemove([staffId]),
        });
        return AuthResponse.error(message: 'Failed to send email. Registration cancelled.');
      }

      return AuthResponse.success(
        message: 'Staff member registered successfully. Email sent with login credentials.',
        data: {'staffId': staffId},
      );
    } catch (e) {
      return AuthResponse.error(message: 'Staff registration failed: $e');
    }
  }

  /// Seed a supervisor user for testing via the login screen
  static Future<AuthResponse> seedSupervisorUser({
    String? email,
    String firstName = 'Supervisor',
    String lastName = 'User',
  }) async {
    try {
      // Determine target franchise: use the first franchise document found
      final franchisesSnap = await _firestore.collection(_franchisesCollection).limit(1).get();
      if (franchisesSnap.docs.isEmpty) {
        return AuthResponse.error(message: 'No franchises found. Please create a franchise first.');
      }
      final franchiseDoc = franchisesSnap.docs.first;
      final franchiseId = franchiseDoc.id;
      final franchiseRef = _firestore.collection(_franchisesCollection).doc(franchiseId);

      // Choose email: passed-in or default unique email
      final targetEmail = (email == null || email.isEmpty)
          ? 'supervisor_${DateTime.now().millisecondsSinceEpoch}@example.com'
          : email.trim();

      // Check if email already exists
      final existing = await _firestore
          .collection(_usersCollection)
          .where('email', isEqualTo: targetEmail)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        return AuthResponse.error(message: 'Email already exists: $targetEmail');
      }

      // Generate temporary password and hash (SHA-256)
      final temporaryPassword = EmailService.generateTemporaryPassword();
      final hashedTemp = _hashPassword(temporaryPassword);

      // Create Firebase Auth user immediately so status can be active
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: targetEmail,
        password: temporaryPassword,
      );
      final supervisorUid = userCredential.user!.uid;

      // Create supervisor user document with active status and temp password metadata
      final now = Timestamp.fromDate(DateTime.now());
      final userData = {
        'id': supervisorUid,
        'email': targetEmail,
        'firstName': firstName,
        'lastName': lastName,
        'role': 'supervisor',
        'status': 'active',
        'phoneNumber': null,
        // Legacy string for compatibility
        'franchiseId': franchiseId,
        'createdAt': now,
        'lastLoginAt': null,
        'isTemporaryPassword': true,
        'metadata': {
          'hashedTempPassword': hashedTemp,
        },
        // Map-based schema for compatibility
        'franchiseID': {
          'franchise': franchiseRef,
          'id': franchiseId,
        },
      };

      await _firestore.collection(_usersCollection).doc(supervisorUid).set(userData);

      return AuthResponse.success(
        message: 'Supervisor user created',
        data: {
          'userId': supervisorUid,
          'email': targetEmail,
          'temporaryPassword': temporaryPassword,
          'franchiseId': franchiseId,
        },
      );
    } catch (e) {
      return AuthResponse.error(message: 'Failed to seed supervisor: $e');
    }
  }

  /// Staff login with email and temporary password
  static Future<AuthResponse> staffLogin(LoginRequest request) async {
    try {
      // Find user by email
      final userQuery = await _firestore
          .collection(_usersCollection)
          .where('email', isEqualTo: request.email)
          .get();

      if (userQuery.docs.isEmpty) {
        return AuthResponse.error(message: 'Invalid email or password', errorCode: 'user-not-found');
      }

      final userDoc = userQuery.docs.first;
      final userData = UserModel.fromMap(userDoc.data());

      // Allow staff and supervisors to use this login
      if (userData.role != UserRole.staff && userData.role != UserRole.supervisor) {
        return AuthResponse.error(message: 'Invalid login method for this account type', errorCode: 'role-mismatch');
      }

      // Block suspended accounts immediately
      if (userData.status == UserStatus.suspended) {
        return AuthResponse.error(
          message: 'Your account has been suspended. Please contact your franchise owner.',
          errorCode: 'account-suspended',
        );
      }

      // Verify password
      if (userData.isTemporaryPassword) {
        // Verify temporary password
        final hashedInput = _hashPassword(request.password);
        final storedHash = userData.metadata?['hashedTempPassword'];
        
        if (hashedInput != storedHash) {
          // Increment failed login count for temporary password attempts
          try {
            await _firestore.collection(_usersCollection).doc(userData.id).update({
              'metadata.failedLoginCount': FieldValue.increment(1),
              'metadata.lastFailedLoginAt': Timestamp.fromDate(DateTime.now()),
            });
            final updated = await _firestore.collection(_usersCollection).doc(userData.id).get();
            final md = (updated.data()?['metadata'] as Map<String, dynamic>?) ?? {};
            final count = (md['failedLoginCount'] ?? 0) as int;
            final requires = md['requiresIdentityConfirmation'] == true;
            if (count >= 3 && !requires) {
              await _firestore.collection(_usersCollection).doc(userData.id).update({
                'metadata.requiresIdentityConfirmation': true,
              });
              // Send suspicious login email and official password reset email
              try {
                if (userData.franchiseId != null) {
                  final franchiseDoc = await _firestore.collection(_franchisesCollection).doc(userData.franchiseId!).get();
                  final franchise = FranchiseModel.fromMap(franchiseDoc.data()!);
                  await EmailService.sendSuspiciousLoginEmail(
                    recipientEmail: userData.email,
                    staffName: userData.fullName,
                    franchiseName: franchise.name,
                    franchiseContactEmail: franchise.contactEmail,
                  );
                } else {
                  await EmailService.sendSuspiciousLoginEmail(
                    recipientEmail: userData.email,
                    staffName: userData.fullName,
                    franchiseName: 'Your Franchise',
                    franchiseContactEmail: null,
                  );
                }
                await _auth.sendPasswordResetEmail(email: userData.email);
              } catch (_) {}
            }
          } catch (_) {}
          return AuthResponse.error(message: 'Invalid email or password');
        }

        // Create Firebase Auth account for first-time login (staff or supervisor)
        if (userData.status == UserStatus.pending) {
          try {
            final userCredential = await _auth.createUserWithEmailAndPassword(
              email: request.email,
              password: request.password,
            );

            // Update user document with Firebase UID and status
            await _firestore.collection(_usersCollection).doc(userData.id).update({
              'id': userCredential.user!.uid,
              'status': UserStatus.emailVerified.toString().split('.').last,
              'lastLoginAt': Timestamp.fromDate(DateTime.now()),
            });

            // Update document ID to match Firebase UID
            await _firestore.collection(_usersCollection).doc(userCredential.user!.uid).set(
              userData.copyWith(
                id: userCredential.user!.uid,
                status: UserStatus.emailVerified,
                lastLoginAt: DateTime.now(),
              ).toMap(),
            );
            await _firestore.collection(_usersCollection).doc(userData.id).delete();

            return AuthResponse.success(
              message: 'Login successful. Please verify your phone number.',
              data: {'requiresPhoneVerification': true, 'userId': userCredential.user!.uid},
            );
          } on FirebaseAuthException catch (e) {
            return AuthResponse.error(
              message: _getAuthErrorMessage(e.code),
              errorCode: e.code,
            );
          }
        }
      }

      // For existing users, use Firebase Auth
      try {
        await _auth.signInWithEmailAndPassword(
          email: request.email,
          password: request.password,
        );

        // Update last login
        await _firestore.collection(_usersCollection).doc(userData.id).update({
          'lastLoginAt': Timestamp.fromDate(DateTime.now()),
          // Reset failed attempt metadata after successful login
          'metadata.failedLoginCount': 0,
          'metadata.lastFailedLoginAt': FieldValue.delete(),
          'metadata.requiresIdentityConfirmation': FieldValue.delete(),
        });

        // Check what the user needs to complete
        final response = _getLoginResponse(userData);
        return response;
      } on FirebaseAuthException catch (e) {
        // Track wrong-password attempts (SDK may return 'invalid-credential') and trigger verification email when threshold reached
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          try {
            await _firestore.collection(_usersCollection).doc(userData.id).update({
              'metadata.failedLoginCount': FieldValue.increment(1),
              'metadata.lastFailedLoginAt': Timestamp.fromDate(DateTime.now()),
            });
            final updated = await _firestore.collection(_usersCollection).doc(userData.id).get();
            final md = (updated.data()?['metadata'] as Map<String, dynamic>?) ?? {};
            final count = (md['failedLoginCount'] ?? 0) as int;
            final requires = md['requiresIdentityConfirmation'] == true;
            if (count >= 3 && !requires) {
              await _firestore.collection(_usersCollection).doc(userData.id).update({
                'metadata.requiresIdentityConfirmation': true,
              });
              try {
                if (userData.franchiseId != null) {
                  final franchiseDoc = await _firestore.collection(_franchisesCollection).doc(userData.franchiseId!).get();
                  final franchise = FranchiseModel.fromMap(franchiseDoc.data()!);
                  await EmailService.sendSuspiciousLoginEmail(
                    recipientEmail: userData.email,
                    staffName: userData.fullName,
                    franchiseName: franchise.name,
                    franchiseContactEmail: franchise.contactEmail,
                  );
                } else {
                  await EmailService.sendSuspiciousLoginEmail(
                    recipientEmail: userData.email,
                    staffName: userData.fullName,
                    franchiseName: 'Your Franchise',
                    franchiseContactEmail: null,
                  );
                }
                await _auth.sendPasswordResetEmail(email: userData.email);
              } catch (_) {}
            }
          } catch (_) {}
        }
        return AuthResponse.error(
          message: _getAuthErrorMessage(e.code),
          errorCode: e.code,
        );
      }
    } catch (e) {
      return AuthResponse.error(message: 'Login failed: $e');
    }
  }

  /// Franchise owner login
  static Future<AuthResponse> franchiseOwnerLogin(LoginRequest request) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: request.email,
        password: request.password,
      );

      final user = userCredential.user!;
      
      // Get user data: prefer doc by uid; fallback to email-based query
      DocumentSnapshot<Map<String, dynamic>>? userDoc;
      final byUid = await _firestore.collection(_usersCollection).doc(user.uid).get();
      if (byUid.exists) {
        userDoc = byUid;
      } else {
        final email = user.email;
        if (email != null) {
          final byEmail = await _firestore
              .collection(_usersCollection)
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
          if (byEmail.docs.isNotEmpty) {
            userDoc = byEmail.docs.first;
          }
        }
      }

      if (userDoc == null || !userDoc.exists) {
        await _auth.signOut();
        return AuthResponse.error(message: 'User data not found');
      }

      final userData = UserModel.fromMap(userDoc.data()!);
      
      if (userData.role != UserRole.franchiseOwner) {
        await _auth.signOut();
        return AuthResponse.error(message: 'Invalid login method for this account type');
      }

      // Update last login
      await _firestore.collection(_usersCollection).doc(userDoc.id).update({
        'lastLoginAt': Timestamp.fromDate(DateTime.now()),
      });

      return AuthResponse.success(
        message: 'Login successful',
        data: {'userId': userDoc.id, 'role': 'franchiseOwner'},
      );
    } on FirebaseAuthException catch (e) {
      return AuthResponse.error(
        message: _getAuthErrorMessage(e.code),
        errorCode: e.code,
      );
    } catch (e) {
      return AuthResponse.error(message: 'Login failed: $e');
    }
  }

  /// Send phone verification code
  static Future<AuthResponse> sendPhoneVerificationCode(
    PhoneVerificationRequest request,
  ) async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResponse.error(message: 'User not authenticated');
      }

      final completer = Completer<AuthResponse>();

      await _auth.verifyPhoneNumber(
        phoneNumber: request.fullPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification completed
          try {
            await user.linkWithCredential(credential);
            await _updateUserPhoneVerification(user.uid, request.phoneNumber);
            completer.complete(AuthResponse.success(
              message: 'Phone number verified automatically',
              data: {'autoVerified': true},
            ));
          } catch (e) {
            completer.complete(AuthResponse.error(message: 'Auto-verification failed: $e'));
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          completer.complete(AuthResponse.error(
            message: _getAuthErrorMessage(e.code),
            errorCode: e.code,
          ));
        },
        codeSent: (String verificationId, int? resendToken) {
          // Store verification ID for later use
          _storeVerificationId(user.uid, verificationId);
          completer.complete(AuthResponse.success(
            message: 'Verification code sent to ${request.fullPhoneNumber}',
            data: {'verificationId': verificationId},
          ));
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Handle timeout
        },
      );

      return await completer.future;
    } catch (e) {
      return AuthResponse.error(message: 'Failed to send verification code: $e');
    }
  }

  /// Verify phone number with OTP
  static Future<AuthResponse> verifyPhoneNumber(
    OTPVerificationRequest request,
  ) async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResponse.error(message: 'User not authenticated');
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: request.verificationId,
        smsCode: request.otpCode,
      );

      await user.linkWithCredential(credential);
      await _updateUserPhoneVerification(user.uid, request.phoneNumber);

      return AuthResponse.success(
        message: 'Phone number verified successfully',
        data: {'requiresPasswordUpdate': true},
      );
    } on FirebaseAuthException catch (e) {
      return AuthResponse.error(
        message: _getAuthErrorMessage(e.code),
        errorCode: e.code,
      );
    } catch (e) {
      return AuthResponse.error(message: 'Phone verification failed: $e');
    }
  }

  /// Update password (from temporary to permanent)
  static Future<AuthResponse> updatePassword(
    PasswordUpdateRequest request,
  ) async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResponse.error(message: 'User not authenticated');
      }

      if (!request.passwordsMatch) {
        return AuthResponse.error(message: 'Passwords do not match');
      }

      // Re-authenticate with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: request.currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(request.newPassword);

      // Update user status to active
      await _firestore.collection(_usersCollection).doc(user.uid).update({
        'status': UserStatus.active.toString().split('.').last,
        'isTemporaryPassword': false,
        'metadata': FieldValue.delete(),
      });

      // Get user data for email
      final userDoc = await _firestore.collection(_usersCollection).doc(user.uid).get();
      final userData = UserModel.fromMap(userDoc.data()!);
      
      // Get franchise data
      final franchiseDoc = await _firestore.collection(_franchisesCollection).doc(userData.franchiseId!).get();
      final franchise = FranchiseModel.fromMap(franchiseDoc.data()!);

      // Send activation email
      await EmailService.sendAccountActivationEmail(
        recipientEmail: userData.email,
        staffName: userData.fullName,
        franchiseName: franchise.name,
      );

      return AuthResponse.success(
        message: 'Password updated successfully. Account is now active.',
        data: {'accountActivated': true},
      );
    } on FirebaseAuthException catch (e) {
      return AuthResponse.error(
        message: _getAuthErrorMessage(e.code),
        errorCode: e.code,
      );
    } catch (e) {
      return AuthResponse.error(message: 'Password update failed: $e');
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Request password reset by email or phone number.
  /// If input contains '@', it is treated as an email.
  /// Otherwise, it looks up the user by `phoneNumber` and sends reset to their email.
  static Future<AuthResponse> requestPasswordReset(String emailOrPhone) async {
    try {
      final input = emailOrPhone.trim();
      if (input.isEmpty) {
        return AuthResponse.error(message: 'Please enter contact number or email');
      }

      // Basic format checks
      final isEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(input);
      final normalizedPhoneForCheck = input.replaceAll(RegExp(r'[^0-9]'), '');
      final isPhone = RegExp(r'^01\d{8,9}$').hasMatch(normalizedPhoneForCheck);

      if (!isEmail && !isPhone) {
        return AuthResponse.error(message: 'Invalid email or contact number format');
      }

      if (isEmail) {
        // Check existence by email in Firestore users collection
        final qs = await _firestore
            .collection(_usersCollection)
            .where('email', isEqualTo: input)
            .limit(1)
            .get();
        if (qs.docs.isEmpty) {
          return AuthResponse.error(message: 'This account does not exist');
        }
        // Send reset link
        await _auth.sendPasswordResetEmail(email: input);
        return AuthResponse.success(message: 'Your account exists, a reset link has been sent');
      }

      // Phone path
      final normalizedPhone = normalizedPhoneForCheck;
      final qs = await _firestore
          .collection(_usersCollection)
          .where('phoneNumber', isEqualTo: normalizedPhone)
          .limit(1)
          .get();
      if (qs.docs.isEmpty) {
        return AuthResponse.error(message: 'This account does not exist');
      }
      final data = qs.docs.first.data();
      final email = data['email'] as String?;
      if (email == null || email.isEmpty) {
        return AuthResponse.error(message: 'This account does not exist');
      }
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResponse.success(message: 'Your account exists, a reset link has been sent');
    } catch (e) {
      return AuthResponse.error(message: 'Failed to process request: $e');
    }
  }

  /// Helper methods
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static Future<void> _updateUserPhoneVerification(String userId, String phoneNumber) async {
    await _firestore.collection(_usersCollection).doc(userId).update({
      'phoneNumber': phoneNumber,
      'status': UserStatus.phoneVerified.toString().split('.').last,
    });
  }

  static Future<void> _storeVerificationId(String userId, String verificationId) async {
    await _firestore.collection(_verificationCollection).doc(userId).set({
      'verificationId': verificationId,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  static AuthResponse _getLoginResponse(UserModel userData) {
    switch (userData.status) {
      case UserStatus.emailVerified:
        return AuthResponse.success(
          message: 'Please verify your phone number',
          data: {'requiresPhoneVerification': true},
        );
      case UserStatus.phoneVerified:
        if (userData.isTemporaryPassword) {
          return AuthResponse.success(
            message: 'Please update your password',
            data: {'requiresPasswordUpdate': true},
          );
        }
        break;
      case UserStatus.active:
        return AuthResponse.success(
          message: 'Login successful',
          data: {'accountActive': true},
        );
      default:
        break;
    }
    
    return AuthResponse.success(message: 'Login successful');
  }

  static String _getAuthErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'Incorrect email or password';
      case 'wrong-password':
        return 'Incorrect email or password';
      case 'invalid-credential':
        return 'Incorrect email or password';
      case 'email-already-in-use':
        return 'Email address is already registered';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Invalid email address';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'invalid-verification-code':
        return 'Invalid verification code';
      case 'invalid-phone-number':
        return 'Invalid phone number';
      default:
        return 'Authentication error: $errorCode';
    }
  }
}