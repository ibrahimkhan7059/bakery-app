class Product {
  final int id;
  final String name;
  final String description;
  final double price;
  final int stock;
  final String? image;
  final int categoryId;
  final String? categoryName;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    this.image,
    required this.categoryId,
    this.categoryName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      price: double.parse(json['price'].toString()),
      stock: json['stock'] ?? 0,
      image: json['image'],
      categoryId: json['category_id'],
      categoryName: json['category']?['name'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'stock': stock,
      'image': image,
      'category_id': categoryId,
      'category_name': categoryName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get imageUrl {
    if (image != null && image!.isNotEmpty) {
      // If image already contains full URL, return as is
      if (image!.startsWith('http')) {
        return image!;
      }
      // Otherwise, construct full URL using your network IP
      return 'http:// 127.0.0.1:8000/storage/$image';
    }
    return ''; // Return empty string for placeholder handling
  }

  String get formattedPrice {
    return 'Rs. ${price.toStringAsFixed(0)}';
  }
}
