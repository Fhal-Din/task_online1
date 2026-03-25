import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/auth_provider.dart';
import '../providers/restaurant_provider.dart';

class AdminMenuItemsPage extends StatefulWidget {
  const AdminMenuItemsPage({super.key});

  @override
  State<AdminMenuItemsPage> createState() => _AdminMenuItemsPageState();
}

class _AdminMenuItemsPageState extends State<AdminMenuItemsPage> {
  String? _categoryId;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  bool _available = true;
  String _query = '';
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RestaurantProvider>().loadMenu();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<RestaurantProvider>();
    if (!auth.isAuthenticated || auth.role != 'admin') {
      return const Scaffold(body: Center(child: Text('Akses ditolak (admin only).')));
    }

    final categories = provider.categories;
    final menu = provider.menuItems.where((m) {
      if (_query.isEmpty) return true;
      return m.name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Admin: Menu Items')),
      body: RefreshIndicator(
        onRefresh: () => provider.loadMenu(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            TextField(
              decoration: const InputDecoration(labelText: 'Cari menu'),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text('Tambah Menu Item'),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                DropdownButtonFormField<String>(
                  value: _categoryId,
                  items: categories
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama'),
                ),
                TextField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Deskripsi (opsional)'),
                ),
                TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Harga (contoh: 25000)'),
                ),
                SwitchListTile(
                  value: _available,
                  onChanged: (v) => setState(() => _available = v),
                  title: const Text('Available'),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final catId = _categoryId;
                            final name = _nameCtrl.text.trim();
                            final price = int.tryParse(_priceCtrl.text.trim());
                            if (catId == null || name.isEmpty || price == null) {
                              setState(() {
                                _error = 'Category, nama, dan harga wajib valid';
                              });
                              return;
                            }
                            setState(() {
                              _busy = true;
                              _error = null;
                            });
                            try {
                              await provider.createMenuItem(
                                categoryId: catId,
                                name: name,
                                description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
                                priceCents: price,
                                isAvailable: _available,
                              );
                              _nameCtrl.clear();
                              _descCtrl.clear();
                              _priceCtrl.clear();
                              setState(() {
                                _categoryId = null;
                                _available = true;
                              });
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
                    child: const Text('Simpan'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...menu.map((m) => _MenuItemCard(item: m)),
            if (!provider.isLoading && menu.isEmpty) const Text('Tidak ada menu.'),
          ],
        ),
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final MenuItem item;
  const _MenuItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<RestaurantProvider>();
    final categories = context.watch<RestaurantProvider>().categories;
    final categoryName = categories.firstWhere(
      (c) => c.id == item.categoryId,
      orElse: () => MenuCategory(id: item.categoryId, name: item.categoryId.substring(0, 6)),
    );
    final price = item.priceCents.toString();

    return Card(
      child: ListTile(
        title: Text(item.name),
        subtitle: Text('${categoryName.name}\nRp $price\n${item.description ?? ''}'),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'toggle') {
              try {
                await provider.updateMenuItem(id: item.id, isAvailable: !item.isAvailable);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            }
            if (v == 'edit') {
              final patch = await _promptEdit(context, item, categories);
              if (patch == null) return;
              try {
                await provider.updateMenuItem(
                  id: item.id,
                  categoryId: patch.categoryId,
                  name: patch.name,
                  description: patch.description,
                  priceCents: patch.priceCents,
                  isAvailable: patch.isAvailable,
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            }
            if (v == 'delete') {
              final ok = await _confirmDelete(context, item.name);
              if (ok != true) return;
              try {
                await provider.deleteMenuItem(id: item.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'toggle', child: Text(item.isAvailable ? 'Set Unavailable' : 'Set Available')),
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  Future<_MenuEdit?> _promptEdit(
    BuildContext context,
    MenuItem current,
    List<MenuCategory> categories,
  ) {
    final nameCtrl = TextEditingController(text: current.name);
    final descCtrl = TextEditingController(text: current.description ?? '');
    final priceCtrl = TextEditingController(text: '${current.priceCents}');
    String categoryId = current.categoryId;
    bool available = current.isAvailable;

    return showDialog<_MenuEdit>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Menu Item'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: categoryId,
                items: categories
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  categoryId = v;
                },
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama')),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Deskripsi')),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Harga (cents)'),
              ),
              StatefulBuilder(
                builder: (context, setState) => SwitchListTile(
                  value: available,
                  onChanged: (v) => setState(() => available = v),
                  title: const Text('Available'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              nameCtrl.dispose();
              descCtrl.dispose();
              priceCtrl.dispose();
              Navigator.pop(context);
            },
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final price = int.tryParse(priceCtrl.text.trim());
              if (price == null) return;
              final patch = _MenuEdit(
                categoryId: categoryId,
                name: nameCtrl.text.trim(),
                description: descCtrl.text.trim(),
                priceCents: price,
                isAvailable: available,
              );
              nameCtrl.dispose();
              descCtrl.dispose();
              priceCtrl.dispose();
              Navigator.pop(context, patch);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Menu Item'),
        content: Text('Hapus $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
  }
}

class _MenuEdit {
  final String categoryId;
  final String name;
  final String description;
  final int priceCents;
  final bool isAvailable;

  _MenuEdit({
    required this.categoryId,
    required this.name,
    required this.description,
    required this.priceCents,
    required this.isAvailable,
  });
}
