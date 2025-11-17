import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../widgets/app_shell.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../models/user_model.dart';

class PersonalProfileScreen extends StatefulWidget {
  const PersonalProfileScreen({super.key});

  @override
  State<PersonalProfileScreen> createState() => _PersonalProfileScreenState();
}

class _PersonalProfileScreenState extends State<PersonalProfileScreen> {
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    _emailCtrl.text = user?.email ?? '';
    _phoneCtrl.text = user?.phoneNumber ?? '';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String _roleText(UserRole role) {
    switch (role) {
      case UserRole.franchiseOwner:
        return 'Franchise Owner';
      case UserRole.supervisor:
        return 'Supervisor';
      case UserRole.staff:
      default:
        return 'Staff';
    }
  }

  InputDecoration _orangeInputDecoration() {
    return const InputDecoration(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Color(0xFFDC711F))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Color(0xFFDC711F))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Color(0xFFDC711F), width: 2)),
      fillColor: Color(0xFFF6EDDF),
      filled: true,
    );
  }

  Future<String?> _promptPassword() async {
    final ctrl = TextEditingController();
    String? value;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm Password'),
          content: TextField(
            controller: ctrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current Password'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            TextButton(onPressed: () { value = ctrl.text.trim(); Navigator.of(ctx).pop(); }, child: const Text('Confirm')),
          ],
        );
      },
    );
    if (value == null || value!.isEmpty) return null;
    return value;
  }

  Future<void> _save() async {
    if (_saving) return;
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;
    final oldEmail = user.email.trim();
    final newEmail = _emailCtrl.text.trim();
    final newPhone = _phoneCtrl.text.trim();
    final needsEmailChange = newEmail.isNotEmpty && newEmail != oldEmail;
    String? pwd;
    if (needsEmailChange) {
      pwd = await _promptPassword();
      if (pwd == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password required to change email')));
        return;
      }
    }
    try {
      setState(() => _saving = true);
      final authUser = fb_auth.FirebaseAuth.instance.currentUser;
      if (authUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not authenticated')));
        setState(() => _saving = false);
        return;
      }

      if (needsEmailChange) {
        await authUser.reauthenticateWithCredential(fb_auth.EmailAuthProvider.credential(email: oldEmail, password: pwd!));
        try {
          await authUser.verifyBeforeUpdateEmail(newEmail);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification email sent to $newEmail. Complete verification to finish update.')));
        } catch (_) {
          await authUser.updateEmail(newEmail);
          await authUser.sendEmailVerification();
          await FirebaseFirestore.instance.collection('users').doc(user.id).update({'email': newEmail});
          context.read<AuthProvider>().updateUser(user.copyWith(email: newEmail));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Email updated. Verification email sent to $newEmail')));
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(user.id).update({'phoneNumber': newPhone});
      context.read<AuthProvider>().updateUser(user.copyWith(phoneNumber: newPhone));

      setState(() => _editing = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final franchise = auth.currentFranchise;

    return AppShell(
      activeItem: 'Staff',
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.chevron_left, color: Colors.orange),
                      label: const Text('BACK', style: TextStyle(color: Colors.orange)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Text('PROFILE', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 12),
                        if (!_editing)
                          SizedBox(
                            width: 120,
                            height: 40,
                            child: OutlinedButton(
                              onPressed: () => setState(() => _editing = true),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange), foregroundColor: Colors.orange),
                              child: const Text('EDIT'),
                            ),
                          )
                        else ...[
                          SizedBox(
                            width: 120,
                            height: 40,
                            child: OutlinedButton(
                              onPressed: () => setState(() => _editing = false),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange), foregroundColor: Colors.orange),
                              child: const Text('CANCEL'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 120,
                            height: 40,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _save,
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC711F), foregroundColor: Colors.white),
                              child: const Text('SAVE'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.green[100],
                            child: Text(
                              ((user?.firstName ?? '').isNotEmpty ? user!.firstName[0] : '') +
                                  ((user?.lastName ?? '').isNotEmpty ? user!.lastName[0] : ''),
                              style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold, fontSize: 22),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user?.fullName ?? '-', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(_roleText(user?.role ?? UserRole.staff), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),

                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _statTile('First Name', user?.firstName ?? '-')),
                          const SizedBox(width: 16),
                          Expanded(child: _statTile('Last Name', user?.lastName ?? '-')),
                          const SizedBox(width: 16),
                          Expanded(child: _editing ? _profileField('Email', _emailCtrl, enabled: true) : _statTile('Email', user?.email ?? '-')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _editing ? _profileField('Contact', _phoneCtrl, enabled: true) : _statTile('Contact', user?.phoneNumber ?? '-')),
                          const SizedBox(width: 16),
                          Expanded(child: _statTile('Franchise', franchise?.name ?? (user?.franchiseId ?? '-'))),
                          const SizedBox(width: 16),
                          Expanded(child: _statTile('User ID', user?.id ?? '-')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _statTile('Last Login', _formatLoginTime(user?.lastLoginAt))),
                          const SizedBox(width: 16),
                          Expanded(child: _statTile('Role', _roleText(user?.role ?? UserRole.staff))),
                          const SizedBox(width: 16),
                          Expanded(child: _statTile('Account Status', user?.status.toString().split('.').last.toUpperCase() ?? '-')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _profileField(String label, TextEditingController controller, {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          decoration: _orangeInputDecoration(),
        ),
      ],
    );
  }

  String _formatLoginTime(DateTime? dt) {
    if (dt == null) return '-';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    int h = dt.hour;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h == 0) h = 12;
    return '$d/$m/$y $h:$min $ampm';
  }
}