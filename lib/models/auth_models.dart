class LoginRequest {
  final String email;
  final String password;

  LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'password': password,
    };
  }
}

class StaffRegistrationRequest {
  final String email;
  final String firstName;
  final String lastName;
  final String franchiseId;
  final String temporaryPassword;

  StaffRegistrationRequest({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.franchiseId,
    required this.temporaryPassword,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'franchiseId': franchiseId,
      'temporaryPassword': temporaryPassword,
    };
  }
}

class FranchiseOwnerRegistrationRequest {
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String franchiseName;
  final String franchiseAddress;
  final String contactPhone;

  FranchiseOwnerRegistrationRequest({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.franchiseName,
    required this.franchiseAddress,
    required this.contactPhone,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'franchiseName': franchiseName,
      'franchiseAddress': franchiseAddress,
      'contactPhone': contactPhone,
    };
  }
}

class PhoneVerificationRequest {
  final String phoneNumber;
  final String countryCode;

  PhoneVerificationRequest({
    required this.phoneNumber,
    required this.countryCode,
  });

  String get fullPhoneNumber => '$countryCode$phoneNumber';

  Map<String, dynamic> toMap() {
    return {
      'phoneNumber': phoneNumber,
      'countryCode': countryCode,
      'fullPhoneNumber': fullPhoneNumber,
    };
  }
}

class OTPVerificationRequest {
  final String phoneNumber;
  final String otpCode;
  final String verificationId;

  OTPVerificationRequest({
    required this.phoneNumber,
    required this.otpCode,
    required this.verificationId,
  });

  Map<String, dynamic> toMap() {
    return {
      'phoneNumber': phoneNumber,
      'otpCode': otpCode,
      'verificationId': verificationId,
    };
  }
}

class PasswordUpdateRequest {
  final String currentPassword;
  final String newPassword;
  final String confirmPassword;

  PasswordUpdateRequest({
    required this.currentPassword,
    required this.newPassword,
    required this.confirmPassword,
  });

  bool get passwordsMatch => newPassword == confirmPassword;

  Map<String, dynamic> toMap() {
    return {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'confirmPassword': confirmPassword,
    };
  }
}

class AuthResponse {
  final bool success;
  final String? message;
  final String? errorCode;
  final Map<String, dynamic>? data;

  AuthResponse({
    required this.success,
    this.message,
    this.errorCode,
    this.data,
  });

  factory AuthResponse.success({String? message, Map<String, dynamic>? data}) {
    return AuthResponse(
      success: true,
      message: message,
      data: data,
    );
  }

  factory AuthResponse.error({required String message, String? errorCode}) {
    return AuthResponse(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'message': message,
      'errorCode': errorCode,
      'data': data,
    };
  }
}

class EmailVerificationData {
  final String email;
  final String temporaryPassword;
  final String staffName;
  final String franchiseName;
  final DateTime sentAt;

  EmailVerificationData({
    required this.email,
    required this.temporaryPassword,
    required this.staffName,
    required this.franchiseName,
    required this.sentAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'temporaryPassword': temporaryPassword,
      'staffName': staffName,
      'franchiseName': franchiseName,
      'sentAt': sentAt.toIso8601String(),
    };
  }
}