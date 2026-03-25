import '../api/api_client.dart';
import '../models.dart';

class RestaurantApi {
  final ApiClient _client;
  RestaurantApi(this._client);

  Future<List<MenuCategory>> listCategories() async {
    final obj = await _client.getJson('/categories');
    final list = obj as List<dynamic>;
    return list
        .map((e) => MenuCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MenuCategory> createCategory({required String name}) async {
    final obj = await _client.postJson('/categories', {'name': name});
    return MenuCategory.fromJson(obj as Map<String, dynamic>);
  }

  Future<void> updateCategory({required String id, required String name}) async {
    await _client.putJson('/categories/$id', {'name': name});
  }

  Future<void> deleteCategory({required String id}) async {
    await _client.deleteJson('/categories/$id');
  }

  Future<List<MenuItem>> listMenuItems({String? categoryId}) async {
    final obj = await _client.getJson(
      '/menu-items',
      query: categoryId != null ? {'categoryId': categoryId} : null,
    );
    final list = obj as List<dynamic>;
    return list.map((e) => MenuItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<MenuItem> createMenuItem({
    required String categoryId,
    required String name,
    String? description,
    required int priceCents,
    bool isAvailable = true,
  }) async {
    final obj = await _client.postJson('/menu-items', {
      'categoryId': categoryId,
      'name': name,
      'description': description,
      'priceCents': priceCents,
      'isAvailable': isAvailable,
    });
    return MenuItem.fromJson(obj as Map<String, dynamic>);
  }

  Future<void> updateMenuItem({
    required String id,
    String? categoryId,
    String? name,
    String? description,
    int? priceCents,
    bool? isAvailable,
  }) async {
    final body = <String, dynamic>{};
    if (categoryId != null) body['categoryId'] = categoryId;
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (priceCents != null) body['priceCents'] = priceCents;
    if (isAvailable != null) body['isAvailable'] = isAvailable;
    await _client.putJson('/menu-items/$id', body);
  }

  Future<void> deleteMenuItem({required String id}) async {
    await _client.deleteJson('/menu-items/$id');
  }

  Future<List<RestaurantTable>> listTables() async {
    final obj = await _client.getJson('/tables');
    final list = obj as List<dynamic>;
    return list
        .map((e) => RestaurantTable.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Order>> listOrders({String? status}) async {
    final obj = await _client.getJson(
      '/orders',
      query: status != null ? {'status': status} : null,
    );
    final list = obj as List<dynamic>;
    return list.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Order> createOrderPublic({
    required String tableId,
    required List<Map<String, dynamic>> items,
  }) async {
    final obj = await _client.postJson('/orders/public', {
      'tableId': tableId,
      'items': items,
    });
    return Order.fromJson(obj as Map<String, dynamic>);
  }

  Future<Order> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    final obj = await _client.putJson('/orders/$orderId/status', {'status': status});
    return Order.fromJson(obj as Map<String, dynamic>);
  }

  Future<RestaurantTable> createTable({
    required String name,
    String status = 'available',
  }) async {
    final obj = await _client.postJson('/tables', {'name': name, 'status': status});
    return RestaurantTable.fromJson(obj as Map<String, dynamic>);
  }

  Future<void> updateTable({
    required String id,
    String? name,
    String? status,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (status != null) body['status'] = status;
    await _client.putJson('/tables/$id', body);
  }

  Future<void> deleteTable({required String id}) async {
    await _client.deleteJson('/tables/$id');
  }
}
