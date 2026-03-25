import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/auth_provider.dart';
import '../providers/restaurant_provider.dart';
import 'login_page.dart';

class TablesPage extends StatefulWidget {
  const TablesPage({super.key});

  @override
  State<TablesPage> createState() => _TablesPageState();
}

class _TablesPageState extends State<TablesPage> {
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RestaurantProvider>().loadTables();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<RestaurantProvider>();
    final tables = provider.tables;
    final isAdmin = auth.role == 'admin';

    return RefreshIndicator(
      onRefresh: () => provider.loadTables(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Manajemen Meja', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (provider.isLoading) const LinearProgressIndicator(),
          if (provider.error != null)
            Text(provider.error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama meja (mis. T1)'),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: !auth.isAuthenticated
                    ? () async {
                        await Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const LoginPage()));
                      }
                    : isAdmin
                        ? () async {
                            final name = _nameCtrl.text.trim();
                            if (name.isEmpty) return;
                            await provider.createTable(name: name);
                            _nameCtrl.clear();
                          }
                        : null,
                child: Text(!auth.isAuthenticated ? 'Login' : 'Tambah'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tables.map((t) => _TableCard(table: t)),
          if (!provider.isLoading && tables.isEmpty) const Text('Belum ada meja.'),
        ],
      ),
    );
  }
}

class _TableCard extends StatelessWidget {
  final RestaurantTable table;
  const _TableCard({required this.table});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.role == 'admin';
    return Card(
      child: ListTile(
        title: Text(table.name),
        subtitle: Text('Status: ${table.status}'),
        trailing: isAdmin
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: table.status,
                    items: const [
                      DropdownMenuItem(value: 'available', child: Text('available')),
                      DropdownMenuItem(value: 'occupied', child: Text('occupied')),
                      DropdownMenuItem(value: 'reserved', child: Text('reserved')),
                      DropdownMenuItem(value: 'cleaning', child: Text('cleaning')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      await context.read<RestaurantProvider>().updateTable(id: table.id, status: v);
                    },
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'rename') {
                        final next = await _promptName(context, table.name);
                        if (next == null || next.trim().isEmpty) return;
                        await context
                            .read<RestaurantProvider>()
                            .updateTable(id: table.id, name: next.trim());
                      }
                      if (v == 'delete') {
                        final ok = await _confirmDelete(context, table.name);
                        if (ok != true) return;
                        await context.read<RestaurantProvider>().deleteTable(id: table.id);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Future<String?> _promptName(BuildContext context, String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Table'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Nama meja'),
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
        title: const Text('Hapus Table'),
        content: Text('Hapus $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
  }
}
