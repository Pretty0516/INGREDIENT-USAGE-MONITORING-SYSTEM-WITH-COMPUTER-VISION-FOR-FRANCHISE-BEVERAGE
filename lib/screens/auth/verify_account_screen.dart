import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../routes/app_routes.dart';

class VerifyAccountScreen extends StatefulWidget {
  const VerifyAccountScreen({super.key});

  @override
  State<VerifyAccountScreen> createState() => _VerifyAccountScreenState();
}

class _VerifyAccountScreenState extends State<VerifyAccountScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isSubmitting = false;
  String? _message;
  bool _isError = false;
  bool _showPhoneChecklist = false;
  bool _checkDigits = false;
  bool _checkLength = false;
  bool _checkNoHyphen = true;
  bool _checkStartsWith01 = false;
  bool _canSubmit = true; // enabled on first load
  
  bool _isValidEmail(String input) {
    final emailReg = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailReg.hasMatch(input);
  }

  bool _isValidPhone(String input) {
    // Must start with 01 and have total 10 or 11 digits (e.g., 01xxxxxxxx)
    final normalized = input.replaceAll(RegExp(r'[^0-9]'), '');
    final phoneReg = RegExp(r'^01\d{8,9}$');
    return phoneReg.hasMatch(normalized);
  }

  // Correct helper to compute checklist states from input
  void _updatePhoneChecklistFromInputFixed(String input) {
    final original = input;
    final digitsOnly = RegExp(r'^\d+$').hasMatch(original);
    final normalized = original.replaceAll(RegExp(r'[^0-9]'), '');
    setState(() {
      _checkDigits = digitsOnly;
      _checkLength = normalized.length == 10 || normalized.length == 11;
      _checkNoHyphen = !original.contains('-');
      _checkStartsWith01 = normalized.startsWith('01');
    });
  }

  void _updatePhoneChecklistFromInput(String input) {
    final original = input;
    final digitsOnly = RegExp(r'^\d+$').hasMatch(original);
    final normalized = original.replaceAll(RegExp(r'[^0-9]'), '');
    setState(() {
      _checkDigits = digitsOnly;
      _checkLength = normalized.length == 10 || normalized.length == 11;
      _checkNoHyphen = !original.contains('-');
      _checkStartsWith01 = normalized.startsWith('01');
    });
  }


  Future<void> _submit() async {
    if (_isSubmitting) return;
    final form = _formKey.currentState;
    if (form == null) return;
    form.save();

    setState(() {
      _isSubmitting = true;
      _message = null;
      _isError = false;
    });

    // Validate only on press; show errors under the field
    final isValid = form.validate();
    if (!isValid) {
      final raw = (form.value['contact'] as String? ?? '').trim();
      final looksLikePhone = !raw.contains('@');
      final isDigitsOnly = RegExp(r'^\d+$').hasMatch(raw);
      setState(() {
        _showPhoneChecklist = looksLikePhone && isDigitsOnly;
        _canSubmit = false; // disable immediately on first invalid press
      });
      if (_showPhoneChecklist) {
        _updatePhoneChecklistFromInputFixed(raw);
      }
      setState(() {
        _isSubmitting = false;
        _message = null; // keep container hidden for field validation errors
        _isError = true;
      });
      return;
    }

    final value = (form.value['contact'] as String? ?? '').trim();
    // Hide checklist once validation has passed and we are submitting
    setState(() {
      _showPhoneChecklist = false;
    });
    final res = await AuthService.sendEmailVerificationCode(value);

    setState(() {
      _isSubmitting = false;
      _message = res.message;
      _isError = !res.success;
    });

    if (res.success && mounted) {
      final encoded = Uri.encodeComponent(value);
      context.go('${AppRoutes.emailOtp}?email=$encoded');
    }
  }

  @override
  void dispose() {
    // Explicit dispose for lifecycle hygiene across pages.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAuthed = authProvider.isAuthenticated;
    final bool isFormatError = _message == 'Invalid email or contact number format';

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'images/background_image.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to the available PNG if JPG is not present
                return Image.asset(
                  'images/background_image.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFFF3E6), Color(0xFFFFE5CC)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 24.0),
              decoration: BoxDecoration(
                color: const Color(0xFFF6EDDF),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 24,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        height: 44,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Verify Account',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1F1F1F),
                          fontSize: 50,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Please enter your registered email address or contact number to reset your password.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFDC711F),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FormBuilder(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.disabled,
                    child: Column(
                      children: [
                        FormBuilderTextField(
                          name: 'contact',
                          decoration: InputDecoration(
                            labelText: 'Email Address / Contact Number (without "-")',
                            filled: true,
                            fillColor: const Color(0xFFFECC7C),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            errorMaxLines: 3,
                          ),
                          onChanged: (val) {
                            setState(() {
                              _canSubmit = true; // re-enable while editing
                            });

                            if (_showPhoneChecklist) {
                              _updatePhoneChecklistFromInputFixed(val ?? '');
                            }
                          },
                          validator: (value) {
                            final v = (value ?? '').trim();
                            if (v.isEmpty) {
                              return 'Please enter your email address or contact number';
                            }
                            if (v.contains('@')) {
                              if (!_isValidEmail(v)) {
                                return 'invalid email address (e.g. example@domain.com)';
                              }
                              return null;
                            }
                            // If user types letters without '@', treat as email guidance error
                            if (RegExp(r'[A-Za-z]').hasMatch(v)) {
                              return 'invalid email address (e.g. example@domain.com)';
                            }
                            if (!_isValidPhone(v)) {
                              return 'Invalid Contact Number (e.g. 01xxxxxxxx)';
                            }
                            return null;
                          },
                        ),
                        if (_showPhoneChecklist) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _CriteriaRow(label: 'starts with 01', checked: _checkStartsWith01),
                                  _CriteriaRow(label: 'digits', checked: _checkDigits),
                                  _CriteriaRow(label: '10 or 11 digits in total', checked: _checkLength),
                                  _CriteriaRow(label: 'without "-"', checked: _checkNoHyphen),
                                ],
                              ),
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: (_isSubmitting || !_canSubmit) ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC711F),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFFFFD2A3),
                              disabledForegroundColor: Colors.white70,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text(
                                    'Send',
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isError ? const Color(0xFFFDECEC) : const Color(0xFFE7F6E7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _isError ? const Color(0xFFF0B3B3) : const Color(0xFFB7E3B7)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            _message!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _isError ? const Color(0xFFB00020) : const Color(0xFF1F6B1F),
                              fontSize: 18,
                            ),
                          ),
                          if (isFormatError) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Email format: example@domain.com',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: _isError ? const Color(0xFFB00020) : const Color(0xFF1F6B1F),
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Contact number format: digits only, min 8, no '-'",
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: _isError ? const Color(0xFFB00020) : const Color(0xFF1F6B1F),
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      if (isAuthed) {
                        context.go('/dashboard');
                      } else {
                        context.go('/login');
                      }
                    },
                    child: const Text(
                      'Back to Login',
                      style: TextStyle(
                        color: Color(0xFFDC711F),
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CriteriaRow extends StatelessWidget {
  final String label;
  final bool checked;
  const _CriteriaRow({super.key, required this.label, required this.checked});

  @override
  Widget build(BuildContext context) {
    // Match Remember Me checkbox color from login screen
    const rememberMeColor = Color(0xFFDC711F);
    final color = rememberMeColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(checked ? Icons.check_box : Icons.check_box_outline_blank, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 16,
                  color: Colors.black87,
                ),
          ),
        ],
      ),
    );
  }
}
