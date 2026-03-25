import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/auth_provider.dart';
import '../providers/restaurant_provider.dart';
import 'login_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<RestaurantProvider>();
      final auth = context.read<AuthProvider>();
      if (auth.isAuthenticated) {
        provider.loadOrders();
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
              await context.read<RestaurantProvider>().loadOrders();
            }
          },
          child: const Text('Login untuk Dashboard Order'),
        ),
      );
    }

    final canAccess = auth.role == 'admin' || auth.role == 'cashier' || auth.role == 'kitchen';
    if (!canAccess) {
      return const Center(child: Text('Akses ditolak.'));
    }

    final q = _searchCtrl.text.trim().toLowerCase();
    final orders = provider.orders.where((o) {
      if (q.isEmpty) return true;
      return o.id.toLowerCase().contains(q) || o.tableId.toLowerCase().contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: () => provider.loadOrders(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Order Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              labelText: 'Cari (order id / table id)',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          if (provider.isLoading) const LinearProgressIndicator(),
          if (provider.error != null)
            Text(provider.error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          ...orders.map((o) => _OrderCard(order: o)),
          if (!provider.isLoading && orders.isEmpty) const Text('Belum ada order.'),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canUpdate = auth.role == 'admin' || auth.role == 'kitchen';
    final itemsText = order.items.map((i) => '${i.nameSnapshot} x${i.qty}').join(', ');
    return Card(
      child: ListTile(
        title: Text('Order ${order.id.substring(0, 6)}'),
        subtitle: Text('Table: ${order.tableId.substring(0, 6)}\n$itemsText'),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(order.status.toUpperCase()),
            const SizedBox(height: 8),
            ElevatedButton(
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
              child: Text(order.status == 'pending'
                  ? 'Start'
                  : order.status == 'processing'
                      ? 'Done'
                      : 'Done'),
            ),
          ],
        ),
      ),
    );
  }
}
