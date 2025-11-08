import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Wait for a minimum splash duration for better UX
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Wait for auth state to be determined
      while (authProvider.state == AuthState.initial) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      if (mounted) {
        _navigateToAppropriateScreen(authProvider);
      }
    }
  }

  void _navigateToAppropriateScreen(AuthProvider authProvider) {
    if (authProvider.hasError) {
      // Show error and navigate to login
      context.go(AppRoutes.login);
      return;
    }

    if (!authProvider.isAuthenticated) {
      context.go(AppRoutes.login);
      return;
    }

    // User is authenticated, navigate based on their status
    if (authProvider.isSuspended) {
      context.go(AppRoutes.suspended);
    } else if (authProvider.needsPhoneVerification) {
      context.go(AppRoutes.phoneVerification);
    } else if (authProvider.needsPasswordUpdate) {
      context.go(AppRoutes.passwordUpdate);
    } else if (authProvider.isFullySetup) {
      // Franchise owners should land on Staff Management
      if (authProvider.isFranchiseOwner) {
        final fid = authProvider.currentUser?.franchiseId;
        if (fid != null && fid.isNotEmpty) {
          context.go('${AppRoutes.staffManagement}?franchiseId=$fid');
        } else {
          context.go(AppRoutes.dashboard);
        }
      } else {
        context.go(AppRoutes.dashboard);
      }
    } else {
      // Fallback to login
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fullscreen background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/background_image.png',
              fit: BoxFit.cover,
            ),
          ),
          // Foreground content
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo from asset
                Image.asset(
                  'assets/images/logo.png',
                  width: 120,
                  height: 120,
                ),
                
                const SizedBox(height: 32),
                
                // App Name
                Text(
                  'Franchise Manager',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 34,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Ingredient Usage Monitoring System',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.black,
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 60),
                
                // Loading Indicator
                const SpinKitWave(
                  color: Colors.white,
                  size: 40,
                ),
                
                const SizedBox(height: 24),
                
                Text(
                  'Loading...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black,
                    fontSize: 18,
                  ),
                ),
                
                const SizedBox(height: 100),
                
                // Version Info
                Text(
                  'Version 1.0.0',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}