import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/restaurant_provider.dart';
import 'order_create_sheet.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<RestaurantProvider>();
      provider.loadMenu();
      provider.loadTables();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final items = _filtered(provider.menuItems);
    return RefreshIndicator(
      onRefresh: () async {
        await provider.loadMenu();
        await provider.loadTables();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Digital Menu',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton(
                onPressed: provider.tables.isEmpty
                    ? null
                    : () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => const OrderCreateSheet(),
                        );
                      },
                child: const Text('Buat Pesanan'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (provider.isLoading) const LinearProgressIndicator(),
          if (provider.error != null)
            Text(provider.error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          _buildCategoryChips(provider.categories),
          const SizedBox(height: 8),
          ...items.map(_buildItemCard),
          if (!provider.isLoading && items.isEmpty)
            const Text('Tidak ada menu untuk kategori ini.'),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(List<MenuCategory> categories) {
    final allSelected = _selectedCategoryId == null;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Semua'),
            selected: allSelected,
            onSelected: (_) => setState(() => _selectedCategoryId = null),
          ),
          const SizedBox(width: 8),
          ...categories.map((c) {
            final selected = _selectedCategoryId == c.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(c.name),
                selected: selected,
                onSelected: (_) => setState(() => _selectedCategoryId = c.id),
              ),
            );
          }),
        ],
      ),
    );
  }

  List<MenuItem> _filtered(List<MenuItem> items) {
    final catId = _selectedCategoryId;
    if (catId == null) return items;
    return items.where((i) => i.categoryId == catId).toList();
  }

  Widget _buildItemCard(MenuItem item) {
    final price = item.priceCents.toString();
    return Card(
      child: ListTile(
        title: Text(item.name),
        subtitle: Text(item.description ?? ''),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Rp $price'),
            Text(item.isAvailable ? 'Available' : 'Unavailable'),
          ],
        ),
      ),
    );
  }
}
