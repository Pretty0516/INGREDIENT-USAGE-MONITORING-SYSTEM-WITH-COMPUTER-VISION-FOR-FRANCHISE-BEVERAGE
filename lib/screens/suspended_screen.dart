import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';

class SuspendedScreen extends StatelessWidget {
  const SuspendedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser;
        final franchise = authProvider.currentFranchise;

        return Scaffold(
          backgroundColor: Colors.red[50],
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Warning Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.block,
                      size: 60,
                      color: Colors.red[600],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Title
                  Text(
                    'Account Suspended',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Message
                  Text(
                    'Your account has been temporarily suspended. Please contact your franchise owner or administrator for assistance.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // User Info Card
                  if (user != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red[200]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account Details',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            context,
                            icon: Icons.person,
                            label: 'Name',
                            value: user.fullName,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            context,
                            icon: Icons.email,
                            label: 'Email',
                            value: user.email,
                          ),
                          if (franchise != null) ...[
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              context,
                              icon: Icons.business,
                              label: 'Franchise',
                              value: franchise.name,
                            ),
                          ],
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            context,
                            icon: Icons.work,
                            label: 'Role',
                            value: user.role == UserRole.franchiseOwner ? 'Franchise Owner' : 'Staff Member',
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 32),
                  
                  // Contact Information
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.support_agent,
                          size: 32,
                          color: Colors.blue[600],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Need Help?',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Contact your franchise owner or system administrator to resolve this issue.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.blue[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (franchise != null && franchise.contactEmail.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[300]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.email,
                                  size: 16,
                                  color: Colors.blue[600],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  franchise.contactEmail,
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showLogoutDialog(context, authProvider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Refresh Button
                  TextButton(
                    onPressed: () => _refreshAccountStatus(context, authProvider),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh,
                          size: 18,
                          color: Colors.blue[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Check Account Status',
                          style: TextStyle(
                            color: Colors.blue[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[800],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await authProvider.signOut();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _refreshAccountStatus(BuildContext context, AuthProvider authProvider) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Refresh user data
      await authProvider.refreshUserData();

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Check if user status has changed
      final user = authProvider.currentUser;
      if (user != null && user.status != UserStatus.suspended) {
        // User is no longer suspended, navigate to appropriate screen
        if (context.mounted) {
          final initialRoute = authProvider.getInitialRoute();
          context.go(initialRoute);
        }
      } else {
        // Still suspended
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account is still suspended'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking account status: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}