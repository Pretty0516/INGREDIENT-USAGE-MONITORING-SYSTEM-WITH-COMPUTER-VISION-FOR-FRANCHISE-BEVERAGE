// login page
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';
import '../../models/auth_models.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final _formKey = GlobalKey<FormBuilderState>(); // validation
  bool _isLoading = false; 
  bool _obscurePassword = true; // password visibility
  bool _rememberMe = false; 
  Map<String, dynamic> _initialFormValues = const {
    'email': '',
    'password': '',
  };

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/background_image.png'), context);
    precacheImage(const AssetImage('assets/images/logo.png'), context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/background_image.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // Fallback visual so you can immediately see if asset lookup fails
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF7FDF4), Color(0xFFEFF8E6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // logo image
                            Image.asset('assets/images/logo.png', height: 44),
                            const SizedBox(width: 12),
                            // title
                            Text(
                              'LOGIN',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
                                    fontSize: 50,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // subtitle
                        Text(
                          'Impact what you serve. Track every ingredient, ensure\n'
                          'hygiene, and comply with MOH standards.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Color(0xFFDC711F),
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        // display the login form
                        _buildLoginForm(context),
                        const SizedBox(height: 16),
                        // forget password
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Forgot your password?',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                ),
                              ),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        context.go('/verify-account');
                                      },
                                child: const Text(
                                  ' Click Here',
                                  style: TextStyle(
                                    color: Color(0xFFDC711F),
                                    decoration: TextDecoration.underline,
                                    decorationColor: Color(0xFFDC711F),
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // login form
  Widget _buildLoginForm(BuildContext context) {
    return FormBuilder(
      key: _formKey,
      initialValue: _initialFormValues,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // email
          FormBuilderTextField(
            name: 'email',
            decoration: InputDecoration(
              labelText: 'Name',
              hintText: 'Enter your name (email)',
              prefixIcon: const Icon(Icons.email_outlined),
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
              filled: true,
              fillColor: const Color(0xFFFECC7C),
              errorStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.red,
              ),
            ),
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(errorText: 'Please enter your name'),
            ]),
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            onChanged: (val) {
              if (_rememberMe) {
                final email = val ?? '';
                final password = (_formKey.currentState?.fields['password']?.value ?? '') as String;
                _persistCredentials(email, password);
              }
            },
          ),
          const SizedBox(height: 16),
          // password
          FormBuilderTextField(
            name: 'password',
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
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
              filled: true,
              fillColor: const Color(0xFFFECC7C),
              errorStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.red,
              ),
            ),
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(errorText: 'Please enter your password'),
              FormBuilderValidators.minLength(
                6,
                errorText: 'Password shall not be less than 6 characters',
              ),
            ]),
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleLogin(),
            onChanged: (val) {
              if (_rememberMe) {
                final password = val ?? '';
                final email = (_formKey.currentState?.fields['email']?.value ?? '') as String;
                _persistCredentials(email, password);
              }
            },
          ),
          const SizedBox(height: 8),
          // remember me
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: (v) async {
                    final checked = v ?? false;
                    setState(() => _rememberMe = checked);
                    if (checked) {
                      // Save current form values immediately
                      final state = _formKey.currentState;
                      state?.save();
                      final values = state?.value ?? {};
                      final email = (values['email'] ?? '') as String;
                      final password = (values['password'] ?? '') as String;
                      await _persistCredentials(email, password);
                    } else {
                      await _clearCredentials();
                    }
                  },
                  activeColor: const Color(0xFFDC711F),
                  side: const BorderSide(color: Color(0xFFDC711F)),
                ),
                const Text(
                  'Remember Me',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // login button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
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
                      'LOGIN',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // handle login function for authentication
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.saveAndValidate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final formData = _formKey.currentState!.value;
      
      final loginRequest = LoginRequest(
        email: formData['email'],
        password: formData['password'],
      );

      // Try staff login first
      final staffResp = await AuthService.staffLogin(loginRequest);

      if (staffResp.success) {
        final user = await AuthService.getCurrentUserData();
        if (user == null) {
          throw Exception('Failed to get user data');
        }
        // Allow staff and supervisors
        if (user.role != UserRole.staff && user.role != UserRole.supervisor) {
          throw Exception('Invalid email or password. Please try again.');
        }

        if (_rememberMe) {
          await _persistCredentials(loginRequest.email, loginRequest.password);
        } else {
          await _clearCredentials();
        }

        if (mounted) {
          switch (user.status) {
            case UserStatus.pending:
            case UserStatus.emailVerified:
              context.go('/phone-verification');
              break;
            case UserStatus.phoneVerified:
              context.go('/password-update');
              break;
            case UserStatus.active:
              // Supervisors and staff both head to dashboard
              context.go('/dashboard');
              break;
            case UserStatus.suspended:
              throw Exception('Your account has been suspended. Please contact your franchise owner.');
          }
        }
      } else {
        // If the account is not a staff account, attempt franchise owner login
        final isWrongMethod = (staffResp.message ?? '').contains('Invalid login method for this account type');
        if (isWrongMethod) {
          final ownerResp = await AuthService.franchiseOwnerLogin(loginRequest);
          if (ownerResp.success) {
            final user = await AuthService.getCurrentUserData();
            if (user == null) {
              throw Exception('Failed to get user data');
            }
            if (user.role != UserRole.franchiseOwner) {
              throw Exception('Invalid email or password. Please try again.');
            }

            if (_rememberMe) {
              await _persistCredentials(loginRequest.email, loginRequest.password);
            } else {
              await _clearCredentials();
            }

            // Navigate franchise owners to Staff Management
            final fid = user.franchiseId;
            if (mounted) {
              if (fid != null && fid.isNotEmpty) {
                context.go('${AppRoutes.staffManagement}?franchiseId=$fid');
              } else {
                // Fallback to dashboard if franchise ID missing
                context.go(AppRoutes.dashboard);
              }
            }
          } else {
            // Show original error message for staff login
            final code = staffResp.errorCode ?? '';
            String msg;
            if (code == 'account-suspended') {
              msg = 'Your account has been suspended. Please contact your franchise owner.';
            } else if (code == 'invalid-email') {
              msg = 'Please enter a valid email address.';
            } else if (code == 'invalid-credential' || code == 'wrong-password' || code == 'user-not-found') {
              msg = 'Incorrect email or password.';
            } else if (code == 'too-many-requests') {
              msg = 'Too many attempts. Try again later.';
            } else {
              msg = staffResp.message ?? 'Incorrect email or password.';
            }
            if (mounted) {
              _showErrorDialog(msg);
            }
            return;
          }
        } else {
          // Not a role mismatch; show staff login error
          final code = staffResp.errorCode ?? '';
          String msg;
          if (code == 'account-suspended') {
            msg = 'Your account has been suspended. Please contact your franchise owner.';
          } else if (code == 'invalid-email') {
            msg = 'Please enter a valid email address.';
          } else if (code == 'invalid-credential' || code == 'wrong-password' || code == 'user-not-found') {
            msg = 'Incorrect email or password.';
          } else if (code == 'too-many-requests') {
            msg = 'Too many attempts. Try again later.';
          } else {
            msg = staffResp.message ?? 'Incorrect email or password.';
          }
          if (mounted) {
            _showErrorDialog(msg);
          }
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // show error dialog alert box
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF6EDDF),
        title: const Text(
          'Error',
          style: TextStyle(color: Colors.black),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18, // Match "Forgot your password?" font size
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC711F),
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 18),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Load saved credentials on init use shared preferences
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_me') ?? false;
    final email = prefs.getString('remember_email') ?? '';
    final password = prefs.getString('remember_password') ?? '';

    setState(() {
      _rememberMe = remember;
      _initialFormValues = {
        'email': email,
        'password': password,
      };
    });

    // Ensure fields update even if FormBuilder timing causes currentState to be null.
    // Retry patching a few times until the form exists.
    void patchWhenReady(String e, String p, {int attempts = 0}) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final state = _formKey.currentState;
        if (state != null) {
          state.patchValue({'email': e, 'password': p});
        } else if (attempts < 10) {
          Future.delayed(const Duration(milliseconds: 50), () {
            patchWhenReady(e, p, attempts: attempts + 1);
          });
        }
      });
    }

    patchWhenReady(email, password);
  }

  Future<void> _persistCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', true);
    await prefs.setString('remember_email', email);
    await prefs.setString('remember_password', password);
  }

  Future<void> _clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', false);
    await prefs.remove('remember_email');
    await prefs.remove('remember_password');
  }
}