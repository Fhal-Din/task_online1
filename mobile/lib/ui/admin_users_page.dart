import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await context.read<AuthProvider>().listUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthenticated || auth.role != 'admin') {
      return const Scaffold(body: Center(child: Text('Akses ditolak (admin only).')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Admin: Users & Roles')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ..._users.map((u) => _UserRow(
                  user: u,
                  onRoleChanged: (role) => _setRole(u['id'] as String, role),
                )),
            if (!_loading && _users.isEmpty) const Text('Belum ada user.'),
          ],
        ),
      ),
    );
  }

  Future<void> _setRole(String userId, String role) async {
    try {
      await context.read<AuthProvider>().updateUserRole(userId: userId, role: role);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }
}

class _UserRow extends StatelessWidget {
  final Map<String, dynamic> user;
  final ValueChanged<String> onRoleChanged;

  const _UserRow({required this.user, required this.onRoleChanged});

  @override
  Widget build(BuildContext context) {
    final email = (user['email'] as String?) ?? '-';
    final role = (user['role'] as String?) ?? 'cashier';
    return Card(
      child: ListTile(
        title: Text(email),
        subtitle: Text('id: ${(user['id'] as String).substring(0, 8)}'),
        trailing: DropdownButton<String>(
          value: role,
          items: const [
            DropdownMenuItem(value: 'admin', child: Text('admin')),
            DropdownMenuItem(value: 'cashier', child: Text('cashier')),
            DropdownMenuItem(value: 'kitchen', child: Text('kitchen')),
          ],
          onChanged: (v) {
            if (v == null) return;
            onRoleChanged(v);
          },
        ),
      ),
    );
  }
}

