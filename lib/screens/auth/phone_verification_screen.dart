import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../../services/auth_service.dart';
import '../../models/auth_models.dart';

class PhoneVerificationScreen extends StatefulWidget {
  final String userId;
  final String email;

  const PhoneVerificationScreen({
    super.key,
    required this.userId,
    required this.email,
  });

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final _phoneFormKey = GlobalKey<FormBuilderState>();
  final _otpFormKey = GlobalKey<FormBuilderState>();
  final PageController _pageController = PageController();
  
  bool _isLoading = false;
  bool _isVerifyingOTP = false;
  bool _isResendingOTP = false;
  String? _phoneNumber;
  String _countryCode = 'MY'; // Default to Malaysia
  String? _verificationId;
  int _currentPage = 0;
  
  // OTP Timer
  Timer? _timer;
  int _resendCountdown = 0;
  bool get _canResend => _resendCountdown == 0;

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => _resendCountdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Phone Verification'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        elevation: 0,
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildProgressStep(0, 'Phone', Icons.phone),
                  Expanded(
                    child: Container(
                      height: 2,
                      color: _currentPage >= 1 ? Colors.green[600] : Colors.grey[300],
                    ),
                  ),
                  _buildProgressStep(1, 'Verify', Icons.verified_user),
                ],
              ),
            ),
            
            // Page Content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildPhoneInputPage(),
                  _buildOTPVerificationPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStep(int step, String label, IconData icon) {
    final isActive = _currentPage >= step;
    final isCompleted = _currentPage > step;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.green[600] : Colors.grey[300],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompleted ? Icons.check : icon,
            color: isActive ? Colors.white : Colors.grey[600],
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneInputPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          
          // Header
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.phone_android,
                    size: 40,
                    color: Colors.green[600],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Verify Your Phone Number',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We\'ll send you a verification code to confirm your phone number',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          // Phone Input Form
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: FormBuilder(
              key: _phoneFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Phone Number',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  IntlPhoneField(
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    initialCountryCode: 'MY', // Malaysia
                    onChanged: (phone) {
                      _phoneNumber = phone.completeNumber;
                      _countryCode = phone.countryCode;
                    },
                    validator: (phone) {
                      if (phone == null || phone.number.isEmpty) {
                        return 'Please enter your phone number';
                      }
                      if (phone.number.length < 8) {
                        return 'Please enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSendOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SpinKitThreeBounce(
                              color: Colors.white,
                              size: 20,
                            )
                          : const Text(
                              'Send Verification Code',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Info Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your phone number will be used for security purposes and important notifications.',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOTPVerificationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          
          // Header
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.sms,
                    size: 40,
                    color: Colors.green[600],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Enter Verification Code',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a 6-digit code to',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _phoneNumber ?? '',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.green[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          // OTP Input Form
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: FormBuilder(
              key: _otpFormKey,
              child: Column(
                children: [
                  FormBuilderTextField(
                    name: 'otp',
                    decoration: InputDecoration(
                      labelText: 'Verification Code',
                      hintText: 'Enter 6-digit code',
                      prefixIcon: const Icon(Icons.security),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      counterText: '',
                    ),
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(),
                      FormBuilderValidators.numeric(),
                      FormBuilderValidators.minLength(6),
                      FormBuilderValidators.maxLength(6),
                    ]),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleVerifyOTP(),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isVerifyingOTP ? null : _handleVerifyOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isVerifyingOTP
                          ? const SpinKitThreeBounce(
                              color: Colors.white,
                              size: 20,
                            )
                          : const Text(
                              'Verify Code',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Resend Code
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Didn\'t receive the code? ',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      if (_canResend)
                        TextButton(
                          onPressed: _isResendingOTP ? null : _handleResendOTP,
                          child: _isResendingOTP
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Resend'),
                        )
                      else
                        Text(
                          'Resend in ${_resendCountdown}s',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Help Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.help_outline, color: Colors.orange[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Trouble receiving the code?',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Check your phone for SMS messages\n'
                  '• Make sure you have good signal reception\n'
                  '• Wait a few minutes and try resending',
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSendOTP() async {
    if (_phoneNumber == null || _phoneNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final request = PhoneVerificationRequest(
        phoneNumber: _phoneNumber!,
        countryCode: _countryCode,
      );

      final response = await AuthService.sendPhoneVerificationCode(request);

      if (response.success) {
        _verificationId = response.data?['verificationId'];
        _startResendTimer();
        
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Verification code sent'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(response.message ?? 'Failed to send verification code');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleVerifyOTP() async {
    if (!_otpFormKey.currentState!.saveAndValidate()) {
      return;
    }

    setState(() => _isVerifyingOTP = true);

    try {
      final formData = _otpFormKey.currentState!.value;
      
      final request = OTPVerificationRequest(
        phoneNumber: _phoneNumber!,
        otpCode: formData['otp'],
        verificationId: _verificationId!,
      );

      final response = await AuthService.verifyPhoneNumber(request);

      if (response.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Phone verified successfully'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate to password update screen
          context.go('/password-update');
        }
      } else {
        throw Exception(response.message ?? 'Invalid verification code');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifyingOTP = false);
      }
    }
  }

  Future<void> _handleResendOTP() async {
    setState(() => _isResendingOTP = true);

    try {
      final request = PhoneVerificationRequest(
        phoneNumber: _phoneNumber!,
        countryCode: _countryCode,
      );

      final response = await AuthService.sendPhoneVerificationCode(request);

      if (response.success) {
        _verificationId = response.data?['verificationId'];
        _startResendTimer();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Verification code resent'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(response.message ?? 'Failed to resend verification code');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResendingOTP = false);
      }
    }
  }
}