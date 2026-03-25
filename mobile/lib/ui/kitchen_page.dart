import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/auth_provider.dart';
import '../providers/restaurant_provider.dart';
import 'login_page.dart';

class KitchenPage extends StatefulWidget {
  const KitchenPage({super.key});

  @override
  State<KitchenPage> createState() => _KitchenPageState();
}

class _KitchenPageState extends State<KitchenPage> {
  final _searchCtrl = TextEditingController();
  String _status = 'pending';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isAuthenticated) {
        context.read<RestaurantProvider>().loadOrders(status: _status);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<RestaurantProvider>();

    if (!auth.isAuthenticated) {
      return Center(
        child: ElevatedButton(
          onPressed: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginPage()));
            if (!mounted) return;
            if (context.read<AuthProvider>().isAuthenticated) {
              await context.read<RestaurantProvider>().loadOrders(status: _status);
            }
          },
          child: const Text('Login untuk Kitchen Display'),
        ),
      );
    }

    final canAccess = auth.role == 'admin' || auth.role == 'kitchen';
    if (!canAccess) {
      return const Center(child: Text('Akses ditolak: hanya role kitchen/admin.'));
    }

    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = provider.orders.where((o) {
      if (o.status != _status) return false;
      if (q.isEmpty) return true;
      return o.id.toLowerCase().contains(q) ||
          o.tableId.toLowerCase().contains(q) ||
          o.items.any((i) => i.nameSnapshot.toLowerCase().contains(q));
    }).toList();

    return RefreshIndicator(
      onRefresh: () => provider.loadOrders(status: _status),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Kitchen Display System', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Search',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _status,
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'processing', child: Text('Processing')),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => _status = v);
                  await provider.loadOrders(status: _status);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (provider.isLoading) const LinearProgressIndicator(),
          if (provider.error != null)
            Text(provider.error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          ...filtered.map((o) => _KitchenOrderCard(order: o)),
          if (!provider.isLoading && filtered.isEmpty) const Text('Tidak ada order.'),
        ],
      ),
    );
  }
}

class _KitchenOrderCard extends StatelessWidget {
  final Order order;
  const _KitchenOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canUpdate = auth.role == 'admin' || auth.role == 'kitchen';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order ${order.id.substring(0, 6)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(order.status.toUpperCase()),
              ],
            ),
            const SizedBox(height: 8),
            ...order.items.map((i) => Text('- ${i.nameSnapshot} x${i.qty}')),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: !canUpdate || order.status == 'done'
                    ? null
                    : () async {
                        try {
                          await context.read<RestaurantProvider>().advanceOrderStatus(order);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        }
                      },
                child: Text(order.status == 'pending' ? 'Mulai' : 'Selesai'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
