class MenuCategory {
  final String id;
  final String name;

  MenuCategory({required this.id, required this.name});

  factory MenuCategory.fromJson(Map<String, dynamic> json) => MenuCategory(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}

class MenuItem {
  final String id;
  final String categoryId;
  final String name;
  final String? description;
  final int priceCents;
  final bool isAvailable;

  MenuItem({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.priceCents,
    required this.isAvailable,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: json['id'] as String,
        categoryId: json['category_id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        priceCents: json['price_cents'] as int,
        isAvailable: (json['is_available'] as int) == 1,
      );
}

class RestaurantTable {
  final String id;
  final String name;
  final String status;

  RestaurantTable({required this.id, required this.name, required this.status});

  factory RestaurantTable.fromJson(Map<String, dynamic> json) => RestaurantTable(
        id: json['id'] as String,
        name: json['name'] as String,
        status: json['status'] as String,
      );
}

class OrderItem {
  final String id;
  final String menuItemId;
  final String nameSnapshot;
  final int priceCentsSnapshot;
  final int qty;

  OrderItem({
    required this.id,
    required this.menuItemId,
    required this.nameSnapshot,
    required this.priceCentsSnapshot,
    required this.qty,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: json['id'] as String,
        menuItemId: json['menu_item_id'] as String,
        nameSnapshot: json['name_snapshot'] as String,
        priceCentsSnapshot: json['price_cents_snapshot'] as int,
        qty: json['qty'] as int,
      );
}

class Order {
  final String id;
  final String tableId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.tableId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        tableId: json['table_id'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        items: (json['items'] as List<dynamic>)
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
