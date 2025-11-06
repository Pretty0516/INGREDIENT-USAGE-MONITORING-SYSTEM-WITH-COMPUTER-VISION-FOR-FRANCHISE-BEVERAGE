import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../../services/auth_service.dart';
import '../../models/auth_models.dart';

class PasswordUpdateScreen extends StatefulWidget {
  final String userId;
  final String email;

  const PasswordUpdateScreen({
    super.key,
    required this.userId,
    required this.email,
  });

  @override
  State<PasswordUpdateScreen> createState() => _PasswordUpdateScreenState();
}

class _PasswordUpdateScreenState extends State<PasswordUpdateScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  // Password strength indicators
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Update Password'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Prevent going back
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              // Header Section
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
                        Icons.lock_reset,
                        size: 40,
                        color: Colors.green[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Create Secure Password',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Replace your temporary password with a secure one',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Password Update Form
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
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Password Information',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Current Password
                      FormBuilderTextField(
                        name: 'currentPassword',
                        decoration: InputDecoration(
                          labelText: 'Current Temporary Password',
                          hintText: 'Enter your temporary password',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureCurrentPassword ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureCurrentPassword = !_obscureCurrentPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                        ]),
                        obscureText: _obscureCurrentPassword,
                        textInputAction: TextInputAction.next,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // New Password
                      FormBuilderTextField(
                        name: 'newPassword',
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          hintText: 'Create a strong password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureNewPassword = !_obscureNewPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                          FormBuilderValidators.minLength(8),
                          (value) {
                            if (value == null || value.isEmpty) return null;
                            if (!_hasUppercase || !_hasLowercase || !_hasNumber || !_hasSpecialChar) {
                              return 'Password must meet all security requirements';
                            }
                            return null;
                          },
                        ]),
                        obscureText: _obscureNewPassword,
                        textInputAction: TextInputAction.next,
                        onChanged: _checkPasswordStrength,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Confirm Password
                      FormBuilderTextField(
                        name: 'confirmPassword',
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          hintText: 'Re-enter your new password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                          (value) {
                            final newPassword = _formKey.currentState?.fields['newPassword']?.value;
                            if (value != newPassword) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ]),
                        obscureText: _obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _handleUpdatePassword(),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Password Strength Indicator
                      _buildPasswordStrengthIndicator(),
                      
                      const SizedBox(height: 24),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleUpdatePassword,
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
                                  'Update Password',
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
              
              // Security Tips
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, color: Colors.blue[600], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Password Security Tips',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• Use a unique password for this account\n'
                      '• Don\'t share your password with anyone\n'
                      '• Consider using a password manager\n'
                      '• Update your password regularly',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password Requirements',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          _buildRequirementItem('At least 8 characters', _hasMinLength),
          _buildRequirementItem('One uppercase letter (A-Z)', _hasUppercase),
          _buildRequirementItem('One lowercase letter (a-z)', _hasLowercase),
          _buildRequirementItem('One number (0-9)', _hasNumber),
          _buildRequirementItem('One special character (!@#\$%^&*)', _hasSpecialChar),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String requirement, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: isMet ? Colors.green : Colors.grey[400],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              requirement,
              style: TextStyle(
                color: isMet ? Colors.green[700] : Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _checkPasswordStrength(String? password) {
    if (password == null) return;
    
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  Future<void> _handleUpdatePassword() async {
    if (!_formKey.currentState!.saveAndValidate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final formData = _formKey.currentState!.value;
      
      final request = PasswordUpdateRequest(
        currentPassword: formData['currentPassword'],
        newPassword: formData['newPassword'],
        confirmPassword: formData['confirmPassword'],
      );

      final response = await AuthService.updatePassword(request);

      if (response.success) {
        if (mounted) {
          // Show success dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600]),
                  const SizedBox(width: 8),
                  const Text('Success!'),
                ],
              ),
              content: const Text(
                'Your password has been updated successfully. You can now access the application with your new password.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.pushReplacementNamed(context, '/dashboard');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Continue to App'),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception(response.message ?? 'Failed to update password');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}