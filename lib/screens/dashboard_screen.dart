import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser;
        final franchise = authProvider.currentFranchise;

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: Text(
              authProvider.isFranchiseOwner 
                  ? 'Franchise Dashboard' 
                  : 'Staff Dashboard'
            ),
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(context, value, authProvider),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 18),
                        SizedBox(width: 8),
                        Text('Profile'),
                      ],
                    ),
                  ),
                  if (authProvider.isFranchiseOwner)
                    const PopupMenuItem(
                      value: 'staff_management',
                      child: Row(
                        children: [
                          Icon(Icons.people, size: 18),
                          SizedBox(width: 8),
                          Text('Manage Staff'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings, size: 18),
                        SizedBox(width: 8),
                        Text('Settings'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Logout', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green[600]!, Colors.green[400]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.white,
                              child: Text(
                                user != null 
                                    ? '${user.firstName[0]}${user.lastName[0]}'
                                    : 'U',
                                style: TextStyle(
                                  color: Colors.green[600],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome back,',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                  Text(
                                    user?.fullName ?? 'User',
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (franchise != null)
                                    Text(
                                      franchise.name,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            authProvider.isFranchiseOwner ? 'Franchise Owner' : 'Staff Member',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Quick Actions
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  if (authProvider.isFranchiseOwner) ...[
                    // Franchise Owner Actions
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                      children: [
                        _buildActionCard(
                          context,
                          icon: Icons.people,
                          title: 'Manage Staff',
                          subtitle: 'Add and manage staff members',
                          color: Colors.blue,
                          onTap: () => _navigateToStaffManagement(context, authProvider),
                        ),
                        _buildActionCard(
                          context,
                          icon: Icons.analytics,
                          title: 'Analytics',
                          subtitle: 'View usage reports',
                          color: Colors.purple,
                          onTap: () => _showComingSoon(context),
                        ),
                        _buildActionCard(
                          context,
                          icon: Icons.inventory,
                          title: 'Inventory',
                          subtitle: 'Manage ingredients',
                          color: Colors.orange,
                          onTap: () => _showComingSoon(context),
                        ),
                        _buildActionCard(
                          context,
                          icon: Icons.settings,
                          title: 'Settings',
                          subtitle: 'Franchise settings',
                          color: Colors.grey,
                          onTap: () => _showComingSoon(context),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Staff Actions
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                      children: [
                        _buildActionCard(
                          context,
                          icon: Icons.camera_alt,
                          title: 'Scan Ingredients',
                          subtitle: 'Monitor ingredient usage',
                          color: Colors.green,
                          onTap: () => _showComingSoon(context),
                        ),
                        _buildActionCard(
                          context,
                          icon: Icons.history,
                          title: 'Usage History',
                          subtitle: 'View past scans',
                          color: Colors.blue,
                          onTap: () => _showComingSoon(context),
                        ),
                        _buildActionCard(
                          context,
                          icon: Icons.notifications,
                          title: 'Notifications',
                          subtitle: 'View alerts',
                          color: Colors.red,
                          onTap: () => _showComingSoon(context),
                        ),
                        _buildActionCard(
                          context,
                          icon: Icons.person,
                          title: 'Profile',
                          subtitle: 'Update your profile',
                          color: Colors.grey,
                          onTap: () => _showComingSoon(context),
                        ),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Recent Activity (Placeholder)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20.0),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Activity',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.timeline,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No recent activity',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Activity will appear here once you start using the system',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
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

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16.0),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action, AuthProvider authProvider) {
    switch (action) {
      case 'profile':
        _showComingSoon(context);
        break;
      case 'staff_management':
        _navigateToStaffManagement(context, authProvider);
        break;
      case 'settings':
        _showComingSoon(context);
        break;
      case 'logout':
        _showLogoutDialog(context, authProvider);
        break;
    }
  }

  void _navigateToStaffManagement(BuildContext context, AuthProvider authProvider) {
    final franchiseId = authProvider.currentUser?.franchiseId;
    if (franchiseId != null && franchiseId.isNotEmpty) {
      context.go('${AppRoutes.staffManagement}?franchiseId=$franchiseId');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Franchise information not available'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This feature is coming soon!'),
        backgroundColor: Colors.blue,
      ),
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
}