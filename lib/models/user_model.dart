import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { franchiseOwner, staff }

enum UserStatus { 
  pending,        // Staff registered but not verified
  emailVerified,  // Email verified but phone not verified
  phoneVerified,  // Phone verified but password not updated
  active,         // Fully verified and active
  suspended       // Account suspended
}

class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final UserRole role;
  final UserStatus status;
  final String? phoneNumber;
  final String? franchiseId;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool isTemporaryPassword;
  final Map<String, dynamic>? metadata;

  UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.status,
    this.phoneNumber,
    this.franchiseId,
    required this.createdAt,
    this.lastLoginAt,
    this.isTemporaryPassword = false,
    this.metadata,
  });

  String get fullName => '$firstName $lastName';

  bool get isActive => status == UserStatus.active;
  bool get needsPhoneVerification => status == UserStatus.emailVerified;
  bool get needsPasswordUpdate => status == UserStatus.phoneVerified && isTemporaryPassword;

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'role': role.toString().split('.').last,
      'status': status.toString().split('.').last,
      'phoneNumber': phoneNumber,
      'franchiseId': franchiseId,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'isTemporaryPassword': isTemporaryPassword,
      'metadata': metadata,
    };
  }

  // Create from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == map['role'],
        orElse: () => UserRole.staff,
      ),
      status: UserStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => UserStatus.pending,
      ),
      phoneNumber: map['phoneNumber'],
      franchiseId: map['franchiseId'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastLoginAt: map['lastLoginAt'] != null 
          ? (map['lastLoginAt'] as Timestamp).toDate() 
          : null,
      isTemporaryPassword: map['isTemporaryPassword'] ?? false,
      metadata: map['metadata'],
    );
  }

  // Create a copy with updated fields
  UserModel copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    UserRole? role,
    UserStatus? status,
    String? phoneNumber,
    String? franchiseId,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isTemporaryPassword,
    Map<String, dynamic>? metadata,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      status: status ?? this.status,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      franchiseId: franchiseId ?? this.franchiseId,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isTemporaryPassword: isTemporaryPassword ?? this.isTemporaryPassword,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, fullName: $fullName, role: $role, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}