import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';

class EmailOtpScreen extends StatefulWidget {
  final String email;
  const EmailOtpScreen({super.key, required this.email});

  @override
  State<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends State<EmailOtpScreen> {
  final List<TextEditingController> _ctrs = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  final TapGestureRecognizer _resendRecognizer = TapGestureRecognizer();
  bool _submitting = false;
  String? _message;
  bool _error = false;
  int _secondsLeft = 300;
  Timer? _timer;
  String? _devOtp;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadDevOtp();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 300);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  Future<void> _loadDevOtp() async {
    if (!kIsWeb) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('email_verifications').doc(widget.email).get();
      final data = doc.data();
      final code = (data?['code'] ?? '') as String;
      if (code.isNotEmpty && mounted) {
        setState(() => _devOtp = code);
      }
    } catch (_) {}
  }

  String get _code => _ctrs.map((c) => c.text.trim()).join();

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _message = null;
      _error = false;
    });
    final code = _code;
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _submitting = false;
        _message = 'Please enter the 6-digit code';
        _error = true;
      });
      return;
    }
    final res = await AuthService.verifyEmailCode(email: widget.email, code: code);
    setState(() {
      _submitting = false;
      _message = res.message;
      _error = !res.success;
    });
    if (res.success && mounted) {
      final encoded = Uri.encodeComponent(widget.email);
      context.go('${AppRoutes.passwordUpdate}?email=$encoded');
    }
  }

  Future<void> _resend() async {
    setState(() {
      _message = null;
      _error = false;
    });
    final res = await AuthService.sendEmailVerificationCode(widget.email);
    setState(() {
      _message = res.message;
      _error = !res.success;
    });
    _startTimer();
    await _loadDevOtp();
  }

  Widget _digitBox(int i) {
    return SizedBox(
      width: 60,
      child: TextField(
        controller: _ctrs[i],
        focusNode: _nodes[i],
        maxLength: 1,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: const Color(0xFFFFF3E6),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        onChanged: (v) {
          if (v.isNotEmpty && i < 5) {
            _nodes[i + 1].requestFocus();
          }
        },
        onSubmitted: (_) {
          if (i == 5) _submit();
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resendRecognizer.dispose();
    for (final f in _nodes) f.dispose();
    for (final c in _ctrs) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mm = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final ss = (_secondsLeft % 60).toString().padLeft(2, '0');
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background_image.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFFFFF3E6), Color(0xFFFFE5CC)])
                  ),
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
                  BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 24, spreadRadius: 2, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/logo.png', height: 44, errorBuilder: (_, __, ___) => const SizedBox()),
                      const SizedBox(width: 12),
                      Text(
                        'VERIFICATION CODE',
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
                    'A one-time password (OTP) has been sent to ${widget.email}.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFDC711F),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Enter OTP',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: Colors.black),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, _digitBox),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Code expired in: $mm : $ss',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700]),
                        children: [
                          const TextSpan(text: 'OTP not received? '),
                          TextSpan(
                            text: 'Click Here',
                            style: const TextStyle(
                              color: Color(0xFFDC711F),
                              decoration: TextDecoration.underline,
                              decorationColor: Color(0xFFDC711F),
                              fontWeight: FontWeight.w700,
                            ),
                            recognizer: _resendRecognizer..onTap = _resend,
                          ),
                      ],
                    ),
                  ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC711F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                      child: _submitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Submit'),
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _error ? const Color(0xFFFDECEC) : const Color(0xFFE7F6E7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _error ? const Color(0xFFF0B3B3) : const Color(0xFFB7E3B7)),
                      ),
                      child: Text(_message!, textAlign: TextAlign.center),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
