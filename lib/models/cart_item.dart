class CartItem {
  final int productId;
  final String name;
  final double price;
  final String image;
  int quantity;
  double total;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.image,
    required this.quantity,
    required this.total,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: json['product_id'],
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      image: json['image'] ?? '',
      quantity: json['quantity'],
      total: (json['total'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'name': name,
      'price': price,
      'image': image,
      'quantity': quantity,
      'total': total,
    };
  }
}
