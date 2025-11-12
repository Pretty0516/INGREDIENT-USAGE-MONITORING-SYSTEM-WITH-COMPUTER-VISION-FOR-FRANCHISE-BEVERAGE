import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
// Web-only import is safe because this project targets web; guarded by kIsWeb
import 'dart:html' as html;

class EmailService {
  static const String _senderEmail = 'yanningchew@gmail.com'; // Replace with your email
  static const String _senderPassword = 'aitu leul pfrw sgve'; // Replace with app password
  static const String _senderName = 'Ingredient Usage Monitoring System';

  static SmtpServer get _smtpServer => gmail(_senderEmail, _senderPassword);

  /// Generates a secure temporary password
  static String generateTemporaryPassword({int length = 12}) {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*';
    final Random random = Random.secure();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Sends temporary password email to newly registered staff
  static Future<bool> sendTemporaryPasswordEmail({
    required String recipientEmail,
    required String staffName,
    required String franchiseName,
    required String temporaryPassword,
  }) async {
    try {
      // On Flutter Web, raw SMTP sockets are not available.
      // Open the user's email client with a prefilled message instead.
      if (kIsWeb) {
        final subject = 'Welcome to $franchiseName - Your Account Details';
        final body = _buildTemporaryPasswordEmailPlaintext(
          staffName: staffName,
          franchiseName: franchiseName,
          temporaryPassword: temporaryPassword,
          recipientEmail: recipientEmail,
        );
        final mailto = 'mailto:$recipientEmail'
            '?subject=' + Uri.encodeComponent(subject) +
            '&body=' + Uri.encodeComponent(body);
        html.window.open(mailto, '_blank');
        return true; // Considered sent (user completes in their client)
      }

      final message = Message()
        ..from = Address(_senderEmail, _senderName)
        ..recipients.add(recipientEmail)
        ..subject = 'Welcome to $franchiseName - Your Account Details'
        ..html = _buildTemporaryPasswordEmailTemplate(
          staffName: staffName,
          franchiseName: franchiseName,
          temporaryPassword: temporaryPassword,
          recipientEmail: recipientEmail,
        );

      final sendReport = await send(message, _smtpServer);
      print('Email sent successfully: ${sendReport.toString()}');
      return true;
    } catch (e) {
      print('Error sending email: $e');
      return false;
    }
  }

  /// Sends an email prompting the user to verify recent failed login attempts
  static Future<bool> sendSuspiciousLoginEmail({
    required String recipientEmail,
    required String staffName,
    required String franchiseName,
    String? franchiseContactEmail,
  }) async {
    try {
      final message = Message()
        ..from = Address(_senderEmail, _senderName)
        ..recipients.add(recipientEmail)
        ..subject = 'Verify Recent Login Attempts'
        ..html = _buildSuspiciousLoginEmailTemplate(
          staffName: staffName,
          franchiseName: franchiseName,
          recipientEmail: recipientEmail,
          franchiseContactEmail: franchiseContactEmail,
        );

      final sendReport = await send(message, _smtpServer);
      print('Suspicious login email sent: ${sendReport.toString()}');
      return true;
    } catch (e) {
      print('Error sending suspicious login email: $e');
      return false;
    }
  }

  /// Builds the HTML template for suspicious login verification email
  static String _buildSuspiciousLoginEmailTemplate({
    required String staffName,
    required String franchiseName,
    required String recipientEmail,
    String? franchiseContactEmail,
  }) {
    final contactEmail = franchiseContactEmail ?? 'support@${franchiseName.replaceAll(' ', '').toLowerCase()}.com';
    final confirmMailto = 'mailto:$contactEmail?subject=Confirm%20Login%20Attempt&body=I%20confirm%20it%27s%20me%20(%20$recipientEmail%20)';
    final notMeMailto = 'mailto:$contactEmail?subject=NOT%20ME%20-%20Freeze%20Account&body=Please%20temporarily%20suspend%20my%20account%20(%20$recipientEmail%20)%20due%20to%20suspicious%20activity.';

    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Verify Recent Login Attempts</title>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #DC711F; color: white; padding: 20px; text-align: center; }
            .content { padding: 20px; background-color: #F6EDDF; }
            .button { display: inline-block; padding: 12px 18px; margin: 8px; border-radius: 6px; text-decoration: none; font-weight: bold; }
            .primary { background-color: #DC711F; color: white; }
            .secondary { background-color: #333; color: white; }
            .note { background-color: #fff3cd; border: 1px solid #ffeaa7; padding: 10px; margin: 15px 0; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>Action Required</h1>
                <p>Verify Recent Login Attempts</p>
            </div>
            <div class="content">
                <p>Hello $staffName,</p>
                <p>We detected multiple failed login attempts (3 or more) on your account for the $franchiseName system.</p>
                <p>Please select one of the options below:</p>
                <p>
                  <a class="button primary" href="$confirmMailto" target="_blank">Confirm it's me</a>
                  <a class="button secondary" href="$notMeMailto" target="_blank">Not me — Freeze account</a>
                </p>
                <div class="note">
                  <strong>Forgot your password?</strong>
                  <p>We have also sent a separate password reset email to $recipientEmail. You can use that email to reset your password securely.</p>
                </div>
                <p>If you did not initiate these attempts, we recommend freezing your account and contacting your franchise owner immediately.</p>
                <p>Thank you and stay safe.</p>
            </div>
            <div class="footer" style="text-align:center; padding: 20px; color: #666; font-size: 12px;">
                <p>This email was sent from the Ingredient Usage Monitoring System</p>
                <p>Please do not share verification links or passwords</p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  /// Sends phone verification reminder email
  static Future<bool> sendPhoneVerificationReminderEmail({
    required String recipientEmail,
    required String staffName,
  }) async {
    try {
      final message = Message()
        ..from = Address(_senderEmail, _senderName)
        ..recipients.add(recipientEmail)
        ..subject = 'Complete Your Account Setup - Phone Verification Required'
        ..html = _buildPhoneVerificationReminderTemplate(staffName: staffName);

      final sendReport = await send(message, _smtpServer);
      print('Phone verification reminder sent: ${sendReport.toString()}');
      return true;
    } catch (e) {
      print('Error sending phone verification reminder: $e');
      return false;
    }
  }

  /// Sends account activation confirmation email
  static Future<bool> sendAccountActivationEmail({
    required String recipientEmail,
    required String staffName,
    required String franchiseName,
  }) async {
    try {
      final message = Message()
        ..from = Address(_senderEmail, _senderName)
        ..recipients.add(recipientEmail)
        ..subject = 'Account Activated - Welcome to $franchiseName!'
        ..html = _buildAccountActivationTemplate(
          staffName: staffName,
          franchiseName: franchiseName,
        );

      final sendReport = await send(message, _smtpServer);
      print('Account activation email sent: ${sendReport.toString()}');
      return true;
    } catch (e) {
      print('Error sending account activation email: $e');
      return false;
    }
  }

  /// Builds the HTML template for temporary password email
  static String _buildTemporaryPasswordEmailTemplate({
    required String staffName,
    required String franchiseName,
    required String temporaryPassword,
    required String recipientEmail,
  }) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Welcome to $franchiseName</title>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #4CAF50; color: white; padding: 20px; text-align: center; }
            .content { padding: 20px; background-color: #f9f9f9; }
            .password-box { background-color: #e8f5e8; border: 2px solid #4CAF50; padding: 15px; margin: 20px 0; text-align: center; }
            .password { font-size: 18px; font-weight: bold; color: #2e7d32; letter-spacing: 2px; }
            .warning { background-color: #fff3cd; border: 1px solid #ffeaa7; padding: 10px; margin: 15px 0; }
            .steps { background-color: white; padding: 15px; margin: 15px 0; border-left: 4px solid #4CAF50; }
            .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>Welcome to $franchiseName!</h1>
                <p>Your account has been created</p>
            </div>
            
            <div class="content">
                <h2>Hello $staffName,</h2>
                
                <p>Your franchise owner has created an account for you in the Ingredient Usage Monitoring System. Below are your login credentials:</p>
                
                <div class="password-box">
                    <p><strong>Email:</strong> $recipientEmail</p>
                    <p><strong>Temporary Password:</strong></p>
                    <div class="password">$temporaryPassword</div>
                </div>
                
                <div class="warning">
                    <strong>⚠️ Important Security Notice:</strong>
                    <ul>
                        <li>This is a temporary password that must be changed after your first login</li>
                        <li>Do not share this password with anyone</li>
                        <li>Keep this email secure and delete it after completing setup</li>
                    </ul>
                </div>
                
                <div class="steps">
                    <h3>Next Steps:</h3>
                    <ol>
                        <li><strong>Login</strong> using the credentials above</li>
                        <li><strong>Verify your phone number</strong> for security</li>
                        <li><strong>Update your password</strong> to something secure and memorable</li>
                        <li><strong>Complete your profile</strong> setup</li>
                    </ol>
                </div>
                
                <p>If you have any questions or need assistance, please contact your franchise owner or our support team.</p>
                
                <p>Welcome aboard!</p>
            </div>
            
            <div class="footer">
                <p>This email was sent from the Ingredient Usage Monitoring System</p>
                <p>Please do not reply to this email</p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  // Plaintext fallback for mailto (used on web)
  static String _buildTemporaryPasswordEmailPlaintext({
    required String staffName,
    required String franchiseName,
    required String temporaryPassword,
    required String recipientEmail,
  }) {
    return 'Hello $staffName,\n\n'
        'Your account has been created in $franchiseName.\n\n'
        'Email: $recipientEmail\n'
        'Temporary Password: $temporaryPassword\n\n'
        'Next steps:\n'
        '1) Login with the credentials above.\n'
        '2) Verify your phone number.\n'
        '3) Update your password.\n\n'
        'Please keep this email secure.';
  }

  /// Builds the HTML template for phone verification reminder
  static String _buildPhoneVerificationReminderTemplate({
    required String staffName,
  }) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Phone Verification Required</title>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #ff9800; color: white; padding: 20px; text-align: center; }
            .content { padding: 20px; background-color: #f9f9f9; }
            .action-box { background-color: #fff3e0; border: 2px solid #ff9800; padding: 15px; margin: 20px 0; text-align: center; }
            .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>Phone Verification Required</h1>
            </div>
            
            <div class="content">
                <h2>Hello $staffName,</h2>
                
                <p>To complete your account setup and ensure security, please verify your phone number.</p>
                
                <div class="action-box">
                    <p><strong>Please log in to the app and complete phone verification</strong></p>
                </div>
                
                <p>Phone verification helps us:</p>
                <ul>
                    <li>Secure your account with two-factor authentication</li>
                    <li>Send important notifications about your work</li>
                    <li>Verify your identity for security purposes</li>
                </ul>
            </div>
            
            <div class="footer">
                <p>This email was sent from the Ingredient Usage Monitoring System</p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  /// Builds the HTML template for account activation confirmation
  static String _buildAccountActivationTemplate({
    required String staffName,
    required String franchiseName,
  }) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Account Activated</title>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #4CAF50; color: white; padding: 20px; text-align: center; }
            .content { padding: 20px; background-color: #f9f9f9; }
            .success-box { background-color: #e8f5e8; border: 2px solid #4CAF50; padding: 15px; margin: 20px 0; text-align: center; }
            .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🎉 Account Activated!</h1>
            </div>
            
            <div class="content">
                <h2>Congratulations $staffName!</h2>
                
                <div class="success-box">
                    <p><strong>Your account is now fully activated and ready to use!</strong></p>
                </div>
                
                <p>You have successfully completed all setup steps:</p>
                <ul>
                    <li>✅ Email verification</li>
                    <li>✅ Phone number verification</li>
                    <li>✅ Password update</li>
                </ul>
                
                <p>You can now access all features of the Ingredient Usage Monitoring System for $franchiseName.</p>
                
                <p>Thank you for completing the setup process!</p>
            </div>
            
            <div class="footer">
                <p>This email was sent from the Ingredient Usage Monitoring System</p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }
}