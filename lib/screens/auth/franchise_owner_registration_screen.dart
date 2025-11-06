import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../../models/auth_models.dart';
import '../../services/auth_service.dart';
import 'staff_management_screen.dart';

class FranchiseOwnerRegistrationScreen extends StatefulWidget {
  const FranchiseOwnerRegistrationScreen({super.key});

  @override
  State<FranchiseOwnerRegistrationScreen> createState() => _FranchiseOwnerRegistrationScreenState();
}

class _FranchiseOwnerRegistrationScreenState extends State<FranchiseOwnerRegistrationScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Franchise Owner Registration'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
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
                child: Column(
                  children: [
                    Icon(
                      Icons.business,
                      size: 64,
                      color: Colors.green[600],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Create Your Franchise Account',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Set up your franchise and start managing your ingredient monitoring system',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Registration Form
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
                      // Personal Information Section
                      Text(
                        'Personal Information',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: FormBuilderTextField(
                              name: 'firstName',
                              decoration: InputDecoration(
                                labelText: 'First Name',
                                prefixIcon: const Icon(Icons.person),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              validator: FormBuilderValidators.compose([
                                FormBuilderValidators.required(),
                                FormBuilderValidators.minLength(2),
                              ]),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FormBuilderTextField(
                              name: 'lastName',
                              decoration: InputDecoration(
                                labelText: 'Last Name',
                                prefixIcon: const Icon(Icons.person),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              validator: FormBuilderValidators.compose([
                                FormBuilderValidators.required(),
                                FormBuilderValidators.minLength(2),
                              ]),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      FormBuilderTextField(
                        name: 'email',
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                          FormBuilderValidators.email(),
                        ]),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      FormBuilderTextField(
                        name: 'contactPhone',
                        decoration: InputDecoration(
                          labelText: 'Contact Phone',
                          prefixIcon: const Icon(Icons.phone),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                          FormBuilderValidators.minLength(10),
                        ]),
                        keyboardType: TextInputType.phone,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Password Section
                      Text(
                        'Security',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      FormBuilderTextField(
                        name: 'password',
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        obscureText: _obscurePassword,
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                          FormBuilderValidators.minLength(8),
                          (value) {
                            if (value == null) return null;
                            if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
                              return 'Password must contain uppercase, lowercase, and number';
                            }
                            return null;
                          },
                        ]),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      FormBuilderTextField(
                        name: 'confirmPassword',
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        obscureText: _obscureConfirmPassword,
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                          (value) {
                            final password = _formKey.currentState?.fields['password']?.value;
                            if (value != password) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ]),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Franchise Information Section
                      Text(
                        'Franchise Information',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      FormBuilderTextField(
                        name: 'franchiseName',
                        decoration: InputDecoration(
                          labelText: 'Franchise Name',
                          prefixIcon: const Icon(Icons.store),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                          FormBuilderValidators.minLength(3),
                        ]),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      FormBuilderTextField(
                        name: 'franchiseAddress',
                        decoration: InputDecoration(
                          labelText: 'Franchise Address',
                          prefixIcon: const Icon(Icons.location_on),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                          FormBuilderValidators.minLength(10),
                        ]),
                        maxLines: 2,
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Register Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegistration,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SpinKitThreeBounce(
                                  color: Colors.white,
                                  size: 24,
                                )
                              : const Text(
                                  'Create Franchise Account',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Login Link
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Already have an account? Sign In',
                            style: TextStyle(
                              color: Colors.green[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.saveAndValidate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final formData = _formKey.currentState!.value;
      
      final request = FranchiseOwnerRegistrationRequest(
        email: formData['email'],
        password: formData['password'],
        firstName: formData['firstName'],
        lastName: formData['lastName'],
        franchiseName: formData['franchiseName'],
        franchiseAddress: formData['franchiseAddress'],
        contactPhone: formData['contactPhone'],
      );

      final response = await AuthService.registerFranchiseOwner(request);

      if (response.success) {
        if (mounted) {
          // Show success dialog
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              icon: Icon(Icons.check_circle, color: Colors.green[600], size: 48),
              title: const Text('Registration Successful!'),
              content: const Text(
                'Your franchise account has been created successfully. You can now start adding staff members to your franchise.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => StaffManagementScreen(
                          franchiseId: response.data!['franchiseId'],
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Continue to Staff Management'),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Registration failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
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
}