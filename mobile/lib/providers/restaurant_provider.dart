import 'package:flutter/foundation.dart';

import '../api/restaurant_api.dart';
import '../models.dart';
import '../realtime/socket_service.dart';

class RestaurantProvider extends ChangeNotifier {
  final RestaurantApi _api;
  final SocketService _socket;

  List<MenuCategory> _categories = [];
  List<MenuItem> _menuItems = [];
  List<RestaurantTable> _tables = [];
  List<Order> _orders = [];

  bool _loading = false;
  String? _error;

  RestaurantProvider({required RestaurantApi api, required SocketService socket})
      : _api = api,
        _socket = socket;

  bool get isLoading => _loading;
  String? get error => _error;

  List<MenuCategory> get categories => List.unmodifiable(_categories);
  List<MenuItem> get menuItems => List.unmodifiable(_menuItems);
  List<RestaurantTable> get tables => List.unmodifiable(_tables);
  List<Order> get orders => List.unmodifiable(_orders);

  void attachRealtime() {
    _socket.off('order:new');
    _socket.off('order:updated');
    _socket.on('order:new', (payload) {
      if (payload is Map) {
        final order = Order.fromJson(Map<String, dynamic>.from(payload));
        _orders = [order, ..._orders.where((o) => o.id != order.id)];
        notifyListeners();
      }
    });
    _socket.on('order:updated', (payload) {
      if (payload is Map) {
        final order = Order.fromJson(Map<String, dynamic>.from(payload));
        _orders = [order, ..._orders.where((o) => o.id != order.id)];
        notifyListeners();
      }
    });
  }

  Future<void> loadMenu() async {
    await _run(() async {
      _categories = await _api.listCategories();
      _menuItems = await _api.listMenuItems();
    });
  }

  Future<MenuCategory> createCategory({required String name}) async {
    final cat = await _api.createCategory(name: name);
    _categories = [cat, ..._categories.where((c) => c.id != cat.id)];
    notifyListeners();
    return cat;
  }

  Future<void> updateCategory({required String id, required String name}) async {
    await _api.updateCategory(id: id, name: name);
    await loadMenu();
  }

  Future<void> deleteCategory({required String id}) async {
    await _api.deleteCategory(id: id);
    await loadMenu();
  }

  Future<MenuItem> createMenuItem({
    required String categoryId,
    required String name,
    String? description,
    required int priceCents,
    bool isAvailable = true,
  }) async {
    final item = await _api.createMenuItem(
      categoryId: categoryId,
      name: name,
      description: description,
      priceCents: priceCents,
      isAvailable: isAvailable,
    );
    _menuItems = [item, ..._menuItems.where((m) => m.id != item.id)];
    notifyListeners();
    return item;
  }

  Future<void> updateMenuItem({
    required String id,
    String? categoryId,
    String? name,
    String? description,
    int? priceCents,
    bool? isAvailable,
  }) async {
    await _api.updateMenuItem(
      id: id,
      categoryId: categoryId,
      name: name,
      description: description,
      priceCents: priceCents,
      isAvailable: isAvailable,
    );
    await loadMenu();
  }

  Future<void> deleteMenuItem({required String id}) async {
    await _api.deleteMenuItem(id: id);
    await loadMenu();
  }

  Future<void> loadTables() async {
    await _run(() async {
      _tables = await _api.listTables();
    });
  }

  Future<void> loadOrders({String? status}) async {
    await _run(() async {
      _orders = await _api.listOrders(status: status);
    });
  }

  Future<Order> createOrderPublic({
    required String tableId,
    required List<Map<String, dynamic>> items,
  }) async {
    final order = await _api.createOrderPublic(tableId: tableId, items: items);
    _orders = [order, ..._orders.where((o) => o.id != order.id)];
    notifyListeners();
    return order;
  }

  Future<Order> advanceOrderStatus(Order order) async {
    final next = switch (order.status) {
      'pending' => 'processing',
      'processing' => 'done',
      _ => order.status,
    };
    final updated = await _api.updateOrderStatus(orderId: order.id, status: next);
    _orders = [updated, ..._orders.where((o) => o.id != updated.id)];
    notifyListeners();
    return updated;
  }

  Future<RestaurantTable> createTable({required String name}) async {
    final table = await _api.createTable(name: name);
    _tables = [table, ..._tables.where((t) => t.id != table.id)];
    notifyListeners();
    return table;
  }

  Future<void> updateTable({required String id, String? name, String? status}) async {
    await _api.updateTable(id: id, name: name, status: status);
    await loadTables();
  }

  Future<void> deleteTable({required String id}) async {
    await _api.deleteTable(id: id);
    await loadTables();
  }

  Future<void> _run(Future<void> Function() fn) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await fn();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
