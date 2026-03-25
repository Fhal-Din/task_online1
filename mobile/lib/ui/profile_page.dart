import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/auth_provider.dart';
import 'admin_categories_page.dart';
import 'admin_menu_items_page.dart';
import 'admin_users_page.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _otpauthUrl;
  final _otpCtrl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _setup2fa() async {
    setState(() {
      _error = null;
      _busy = true;
      _otpauthUrl = null;
    });
    try {
      final resp = await context.read<AuthProvider>().setup2fa();
      setState(() {
        _otpauthUrl = resp['otpauthUrl'] as String?;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _enable2fa() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await context.read<AuthProvider>().enable2fa(otp: _otpCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('2FA enabled')),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthenticated) {
      return Center(
        child: ElevatedButton(
          onPressed: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginPage()));
          },
          child: const Text('Login'),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Text('Email: ${auth.email ?? '-'}'),
        Text('Role: ${auth.role ?? '-'}'),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _busy ? null : () => auth.logout(),
          child: const Text('Logout'),
        ),
        if (auth.role == 'admin') ...[
          const SizedBox(height: 24),
          const Text('Admin Tools', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminCategoriesPage()),
              );
            },
            child: const Text('Manage Categories'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminMenuItemsPage()),
              );
            },
            child: const Text('Manage Menu Items'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminUsersPage()),
              );
            },
            child: const Text('Users & Roles'),
          ),
        ],
        const SizedBox(height: 24),
        const Text('2FA (TOTP)', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : _setup2fa,
          child: const Text('Setup / Reset 2FA'),
        ),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        if (_otpauthUrl != null) ...[
          const SizedBox(height: 12),
          QrImageView(data: _otpauthUrl!, size: 220),
          const SizedBox(height: 12),
          TextField(
            controller: _otpCtrl,
            decoration: const InputDecoration(labelText: 'OTP'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _busy ? null : _enable2fa,
            child: const Text('Enable 2FA'),
          ),
        ],
      ],
    );
  }
}
