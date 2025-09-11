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
  final List<String>? allergens;
  final Product? alternativeProduct;

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
    this.allergens,
    this.alternativeProduct,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    List<String>? allergensList;
    if (json['allergens'] is List) {
      allergensList =
          (json['allergens'] as List).map((e) => e.toString()).toList();
    } else if (json['allergens'] is String &&
        (json['allergens'] as String).isNotEmpty) {
      allergensList = (json['allergens'] as String)
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else {
      allergensList = [];
    }
    return Product(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      price: double.parse(json['price'].toString()),
      stock: json['stock'] ?? 0,
      image: json['image'],
      categoryId: json['category_id'],
      categoryName: json['category']?['name'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      allergens: allergensList,
      alternativeProduct: json['alternative_product'] != null
          ? Product.fromJson(json['alternative_product'])
          : null,
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
      'allergens': allergens,
      'alternative_product': alternativeProduct?.toJson(),
    };
  }

  String get imageUrl {
    if (image != null && image!.isNotEmpty) {
      // If image already contains full URL, return as is
      if (image!.startsWith('http')) {
        return image!;
      }
      // Otherwise, construct full URL using your network IP
      return image!;
    }
    return ''; // Return empty string for placeholder handling
  }

  String get formattedPrice {
    return 'PKR ${price.toStringAsFixed(0)}';
  }
}
