import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/restaurant_provider.dart';

class OrderCreateSheet extends StatefulWidget {
  const OrderCreateSheet({super.key});

  @override
  State<OrderCreateSheet> createState() => _OrderCreateSheetState();
}

class _OrderCreateSheetState extends State<OrderCreateSheet> {
  String? _tableId;
  final Map<String, int> _qtyByMenuItemId = {};
  String? _error;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final menu = provider.menuItems.where((m) => m.isAvailable).toList();
    final tables = provider.tables;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Buat Pesanan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _tableId,
              items: tables
                  .map((t) => DropdownMenuItem(value: t.id, child: Text('${t.name} (${t.status})')))
                  .toList(),
              onChanged: (v) => setState(() => _tableId = v),
              decoration: const InputDecoration(labelText: 'Pilih Meja'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: ListView.builder(
                itemCount: menu.length,
                itemBuilder: (context, idx) {
                  final item = menu[idx];
                  final qty = _qtyByMenuItemId[item.id] ?? 0;
                  return _MenuQtyRow(
                    item: item,
                    qty: qty,
                    onChanged: (n) {
                      setState(() {
                        if (n <= 0) {
                          _qtyByMenuItemId.remove(item.id);
                        } else {
                          _qtyByMenuItemId[item.id] = n;
                        }
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : () => _submit(context),
                child: _submitting ? const Text('Loading...') : const Text('Kirim Order'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    setState(() {
      _error = null;
    });
    final tableId = _tableId;
    if (tableId == null) {
      setState(() {
        _error = 'Meja wajib dipilih';
      });
      return;
    }
    if (_qtyByMenuItemId.isEmpty) {
      setState(() {
        _error = 'Minimal 1 item';
      });
      return;
    }

    setState(() {
      _submitting = true;
    });
    try {
      final items = _qtyByMenuItemId.entries
          .map((e) => {'menuItemId': e.key, 'qty': e.value})
          .toList();
      final order = await context.read<RestaurantProvider>().createOrderPublic(
            tableId: tableId,
            items: items,
          );
      if (!mounted) return;
      Navigator.of(context).pop(order);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order dibuat: ${order.id.substring(0, 6)}')),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _submitting = false;
      });
    }
  }
}

class _MenuQtyRow extends StatelessWidget {
  final MenuItem item;
  final int qty;
  final ValueChanged<int> onChanged;

  const _MenuQtyRow({required this.item, required this.qty, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final price = item.priceCents.toString();
    return ListTile(
      title: Text(item.name),
      subtitle: Text('Rp $price'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: qty <= 0 ? null : () => onChanged(qty - 1),
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            onPressed: () => onChanged(qty + 1),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
