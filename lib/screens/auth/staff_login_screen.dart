import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/auth_models.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _skipSetup = false;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/background_image.png'), context);
    precacheImage(const AssetImage('assets/images/logo.png'), context);
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = AuthService.currentUser != null;
    return Scaffold(
      body: Stack(
        children: [
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
                            Image.asset('assets/images/logo.png', height: 44),
                            const SizedBox(width: 12),
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
                        Text(
                          'Impact what you serve. Track every ingredient, ensure\n'
                          'hygiene, and comply with MOH standards.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Color(0xFFDC711F),
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        isLoggedIn ? _buildLogoutContent(context) : _buildLoginForm(context),
                        const SizedBox(height: 16),
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

  Widget _buildLoginForm(BuildContext context) {
    return FormBuilder(
      key: _formKey,
      initialValue: _initialFormValues,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _skipSetup,
                  onChanged: (v) {
                    setState(() => _skipSetup = v ?? false);
                  },
                  activeColor: const Color(0xFFDC711F),
                  side: const BorderSide(color: Color(0xFFDC711F)),
                ),
                const Text(
                  'Skip verification (dev)',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
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
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _seedSupervisor,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text(
                'Add Supervisor (Seed)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC711F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutContent(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: AuthService.getCurrentUserData(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: SpinKitThreeBounce(color: Colors.green, size: 20),
              ),
            if (user != null) ...[
              Row(
                children: [
                  const Icon(Icons.email_outlined),
                  const SizedBox(width: 8),
                  Text(user.email),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.badge_outlined),
                  const SizedBox(width: 8),
                  Text('Role: ${user.role.name}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.verified_user_outlined),
                  const SizedBox(width: 8),
                  Text('Status: ${user.status.name}'),
                ],
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _handleLogout(context),
                icon: const Icon(Icons.logout),
                label: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

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
          throw Exception('Invalid login method for this account type');
        }

        if (_rememberMe) {
          await _persistCredentials(loginRequest.email, loginRequest.password);
        } else {
          await _clearCredentials();
        }

        if (mounted) {
          if (_skipSetup) {
            // Enable dev bypass and navigate directly
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            authProvider.setDevBypass(true);
            context.go(AppRoutes.dashboard);
            return;
          }
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
              throw Exception('Invalid login method for this account type');
            }

            if (_rememberMe) {
              await _persistCredentials(loginRequest.email, loginRequest.password);
            } else {
              await _clearCredentials();
            }

            // Navigate franchise owners to Staff Management
            final fid = user.franchiseId;
            if (mounted) {
              if (_skipSetup) {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                authProvider.setDevBypass(true);
              }
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

  Future<void> _handleLogout(BuildContext context) async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have been logged out.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Stay on the same unified screen; it will now show the login form
        setState(() {});
        // After showing the login form again, reload saved credentials to prefill
        _loadSavedCredentials();
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Logout failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _seedSupervisor() async {
    try {
      setState(() => _isLoading = true);
      // Use current form email if available, otherwise let service generate a unique email
      _formKey.currentState?.save();
      final values = _formKey.currentState?.value ?? {};
      final email = (values['email'] as String?)?.trim();

      final resp = await AuthService.seedSupervisorUser(email: email);
      if (resp.success) {
        final data = resp.data ?? {};
        final seededEmail = (data['email'] ?? '') as String;
        final tempPassword = (data['temporaryPassword'] ?? '') as String;
        final fid = (data['franchiseId'] ?? '') as String;

        // Prefill credentials so you can immediately log in
        _initialFormValues = {
          'email': seededEmail,
          'password': tempPassword,
        };
        _formKey.currentState?.reset();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Supervisor created for franchise $fid. Temp password: $tempPassword'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        final msg = resp.message ?? 'Failed to seed supervisor';
        if (mounted) _showErrorDialog(msg);
      }
    } catch (e) {
      if (mounted) _showErrorDialog('Failed to seed supervisor: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

  void _showContactSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('If you need help with your login, please contact:'),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.email, size: 16),
                SizedBox(width: 8),
                Text('support@franchise.com'),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone, size: 16),
                SizedBox(width: 8),
                Text('+1 (555) 123-4567'),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Or contact your franchise owner directly.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}