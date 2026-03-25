import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/restaurant_provider.dart';

class AdminCategoriesPage extends StatefulWidget {
  const AdminCategoriesPage({super.key});

  @override
  State<AdminCategoriesPage> createState() => _AdminCategoriesPageState();
}

class _AdminCategoriesPageState extends State<AdminCategoriesPage> {
  final _nameCtrl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<RestaurantProvider>();
    if (!auth.isAuthenticated || auth.role != 'admin') {
      return const Scaffold(body: Center(child: Text('Akses ditolak (admin only).')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Admin: Categories')),
      body: RefreshIndicator(
        onRefresh: () => provider.loadMenu(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nama kategori'),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          final name = _nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          setState(() {
                            _busy = true;
                            _error = null;
                          });
                          try {
                            await provider.createCategory(name: name);
                            _nameCtrl.clear();
                          } catch (e) {
                            setState(() {
                              _error = e.toString();
                            });
                          } finally {
                            if (mounted) {
                              setState(() {
                                _busy = false;
                              });
                            }
                          }
                        },
                  child: const Text('Tambah'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...provider.categories.map((c) => Card(
                  child: ListTile(
                    title: Text(c.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () async {
                            final next = await _promptName(context, c.name);
                            if (next == null || next.trim().isEmpty) return;
                            try {
                              await provider.updateCategory(id: c.id, name: next.trim());
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          onPressed: () async {
                            final ok = await _confirmDelete(context, c.name);
                            if (ok != true) return;
                            try {
                              await provider.deleteCategory(id: c.id);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.delete),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptName(BuildContext context, String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Nama'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Simpan')),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  Future<bool?> _confirmDelete(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Category'),
        content: Text('Hapus $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
  }
}

