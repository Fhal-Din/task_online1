import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/auth_provider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  String? _otpauthUrl;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() {
      _error = null;
      _otpauthUrl = null;
    });
    try {
      final resp = await context.read<AuthProvider>().register(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
          );
      final tf = resp['twoFactor'] as Map<String, dynamic>?;
      setState(() {
        _otpauthUrl = tf?['otpauthUrl'] as String?;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _confirm() async {
    setState(() {
      _error = null;
    });
    try {
      await context.read<AuthProvider>().confirm2fa(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
            otp: _otpCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
            ),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(labelText: 'Password (min 8)'),
              obscureText: true,
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: auth.isLoading ? null : _register,
                child: auth.isLoading ? const Text('Loading...') : const Text('Register'),
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_otpauthUrl != null) ...[
              const SizedBox(height: 16),
              const Text('Scan QR di Authenticator App, lalu masukkan OTP'),
              const SizedBox(height: 12),
              QrImageView(data: _otpauthUrl!, size: 220),
              const SizedBox(height: 12),
              TextField(
                controller: _otpCtrl,
                decoration: const InputDecoration(labelText: 'OTP'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _confirm,
                  child: auth.isLoading ? const Text('Loading...') : const Text('Aktifkan 2FA'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

