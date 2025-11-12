import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/franchise_owner_registration_screen.dart';
import '../screens/auth/staff_management_screen.dart';
import '../screens/auth/staff_login_screen.dart';
import '../screens/auth/phone_verification_screen.dart';
import '../screens/auth/password_update_screen.dart';
import '../screens/auth/verify_account_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/suspended_screen.dart';
import '../screens/product_management_screen.dart';
import '../screens/ingredient_management_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String franchiseOwnerRegistration = '/franchise-owner-registration';
  static const String staffManagement = '/staff-management';
  static const String phoneVerification = '/phone-verification';
  static const String passwordUpdate = '/password-update';
  static const String verifyAccount = '/verify-account';
  static const String dashboard = '/dashboard';
  static const String suspended = '/suspended';
  static const String productManagement = '/product-management';
  static const String ingredientManagement = '/ingredient-management';

  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: splash,
      redirect: (context, state) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final currentLocation = state.matchedLocation;
        final devBypass = authProvider.devBypass;

        // If on splash screen, let it handle the navigation
        if (currentLocation == splash) {
          return null;
        }

        // If user is not authenticated, redirect to login
        if (!authProvider.isAuthenticated) {
          if (currentLocation != login && currentLocation != franchiseOwnerRegistration && currentLocation != verifyAccount) {
            return login;
          }
          return null;
        }

        // If user is authenticated, check their status (respect dev bypass)
        if (authProvider.isAuthenticated) {
          // If suspended, redirect to suspended screen
          if (authProvider.isSuspended) {
            if (currentLocation != suspended) {
              return suspended;
            }
            return null;
          }

          // If needs phone verification
          if (!devBypass && authProvider.needsPhoneVerification) {
            if (currentLocation != phoneVerification) {
              return phoneVerification;
            }
            return null;
          }

          // If needs password update
          if (!devBypass && authProvider.needsPasswordUpdate) {
            if (currentLocation != passwordUpdate) {
              return passwordUpdate;
            }
            return null;
          }

          // If fully setup, redirect away from setup flows but allow login for logout
          if (authProvider.isFullySetup || devBypass) {
            if (currentLocation == phoneVerification || 
                currentLocation == passwordUpdate) {
              // Franchise owners land on Staff Management; staff on Dashboard
              if (authProvider.isFranchiseOwner) {
                final fid = authProvider.currentUser?.franchiseId;
                if (fid != null && fid.isNotEmpty) {
                  return '$staffManagement?franchiseId=$fid';
                }
              }
              return dashboard;
            }
            // Keep login accessible to allow unified login/logout screen across devices
            return null;
          }
        }

        return null;
      },
      routes: [
        GoRoute(
          path: splash,
          name: 'splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: login,
          name: 'login',
          builder: (context, state) => const StaffLoginScreen(),
        ),
        GoRoute(
          path: franchiseOwnerRegistration,
          name: 'franchise-owner-registration',
          builder: (context, state) => const FranchiseOwnerRegistrationScreen(),
        ),
        GoRoute(
          path: staffManagement,
          name: 'staff-management',
          builder: (context, state) {
            final franchiseId = state.uri.queryParameters['franchiseId'];
            if (franchiseId == null) {
              return const Scaffold(
                body: Center(child: Text('Franchise ID required')),
              );
            }
            return StaffManagementScreen(franchiseId: franchiseId);
          },
        ),
        GoRoute(
          path: phoneVerification,
          name: 'phone-verification',
          builder: (context, state) {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            final user = authProvider.currentUser;
            
            if (user == null) {
              return const Scaffold(
                body: Center(child: Text('User not found')),
              );
            }
            
            return PhoneVerificationScreen(
              userId: user.id,
              email: user.email,
            );
          },
        ),
        GoRoute(
          path: passwordUpdate,
          name: 'password-update',
          builder: (context, state) {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            final user = authProvider.currentUser;
            
            if (user == null) {
              return const Scaffold(
                body: Center(child: Text('User not found')),
              );
            }
            
            return PasswordUpdateScreen(
              userId: user.id,
              email: user.email,
            );
          },
        ),
        GoRoute(
          path: verifyAccount,
          name: 'verify-account',
          builder: (context, state) => const VerifyAccountScreen(),
        ),
        GoRoute(
          path: dashboard,
          name: 'dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: suspended,
          name: 'suspended',
          builder: (context, state) => const SuspendedScreen(),
        ),
        GoRoute(
          path: productManagement,
          name: 'product-management',
          builder: (context, state) => const ProductManagementScreen(),
        ),
        GoRoute(
          path: ingredientManagement,
          name: 'ingredient-management',
          builder: (context, state) => const IngredientManagementScreen(),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Page not found',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                state.error.toString(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(splash),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}