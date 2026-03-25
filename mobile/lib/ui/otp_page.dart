import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class OtpPage extends StatefulWidget {
  final String email;
  final String twoFactorToken;
  const OtpPage({super.key, required this.email, required this.twoFactorToken});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _otpCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _error = null;
    });
    try {
      await context.read<AuthProvider>().verifyOtp(
            email: widget.email,
            twoFactorToken: widget.twoFactorToken,
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
    final loading = context.watch<AuthProvider>().isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi OTP')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Masukkan OTP untuk ${widget.email}'),
            TextField(
              controller: _otpCtrl,
              decoration: const InputDecoration(labelText: 'OTP'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : _verify,
                child: loading ? const Text('Loading...') : const Text('Verifikasi'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

