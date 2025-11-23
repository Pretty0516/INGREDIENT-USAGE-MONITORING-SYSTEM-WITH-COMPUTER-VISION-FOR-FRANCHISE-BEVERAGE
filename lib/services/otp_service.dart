import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OtpService {
  static const String _sendUrlEnv = String.fromEnvironment('OTP_SEND_URL', defaultValue: '');
  static const String _verifyUrlEnv = String.fromEnvironment('OTP_VERIFY_URL', defaultValue: '');
  static const String _baseEnv = String.fromEnvironment('OTP_BASE_URL', defaultValue: '');
  static const String _defaultBase = 'http://localhost:8081';

  static String get _sendUrl {
    if (_sendUrlEnv.isNotEmpty) return _sendUrlEnv;
    final base = _baseEnv.isNotEmpty ? _baseEnv : _defaultBase;
    return '$base/sendOtp';
  }

  static String get _verifyUrl {
    if (_verifyUrlEnv.isNotEmpty) return _verifyUrlEnv;
    final base = _baseEnv.isNotEmpty ? _baseEnv : _defaultBase;
    return '$base/verifyOtp';
  }

  static Future<Map<String, dynamic>> sendOtpEmail({required String email, String context = 'login'}) async {
    try {
      final res = await http.post(
        Uri.parse(_sendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'channel': 'email', 'email': email, 'context': context}),
      );
      final data = _decode(res);
      final ok = res.statusCode >= 200 && res.statusCode < 300;
      if (!ok) {
        return {'success': false, 'message': 'HTTP ${res.statusCode}: ${res.body}'};
      }
      return {'success': true, 'message': data['message'], 'requestId': data['requestId']};
    } catch (e) {
      return {'success': false, 'message': '$e'};
    }
  }

  static Future<Map<String, dynamic>> sendOtpSms({required String phone, String context = 'login'}) async {
    try {
      final res = await http.post(
        Uri.parse(_sendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'channel': 'sms', 'phone': phone, 'context': context}),
      );
      final data = _decode(res);
      final ok = res.statusCode >= 200 && res.statusCode < 300;
      if (!ok) {
        return {'success': false, 'message': 'HTTP ${res.statusCode}: ${res.body}'};
      }
      return {'success': true, 'message': data['message'], 'requestId': data['requestId']};
    } catch (e) {
      return {'success': false, 'message': '$e'};
    }
  }

  static Future<Map<String, dynamic>> verifyOtp({required String requestId, required String code}) async {
    try {
      final res = await http.post(
        Uri.parse(_verifyUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'requestId': requestId, 'code': code}),
      );
      final data = _decode(res);
      final ok = res.statusCode >= 200 && res.statusCode < 300;
      if (!ok) {
        return {'success': false, 'message': 'HTTP ${res.statusCode}: ${res.body}'};
      }
      return {'success': true, 'message': data['message'], 'valid': data['valid'] == true};
    } catch (e) {
      return {'success': false, 'message': '$e'};
    }
  }

  static Map<String, dynamic> _decode(http.Response res) {
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
