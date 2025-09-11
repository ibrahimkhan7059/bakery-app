import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/cart_item.dart';
import 'product_detail_screen.dart';

class CategoryProductsScreen extends StatefulWidget {
  final Category category;

  const CategoryProductsScreen({
    super.key,
    required this.category,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  List<Product> products = [];
  bool _isLoading = true;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final fetchedProducts =
          await _apiService.getProductsByCategory(widget.category.id);
      setState(() {
        products = fetchedProducts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load products: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> addToCart(Product product) async {
    final prefs = await SharedPreferences.getInstance();
    final cartItemStrings = prefs.getStringList('cart_items') ?? [];
    List<CartItem> cartItems = cartItemStrings
        .map((item) => CartItem.fromJson(jsonDecode(item)))
        .toList();
    final index = cartItems.indexWhere((item) => item.productId == product.id);
    if (index != -1) {
      cartItems[index].quantity += 1;
      cartItems[index].total =
          cartItems[index].price * cartItems[index].quantity;
    } else {
      cartItems.add(CartItem(
        productId: product.id,
        name: product.name,
        price: product.price,
        image: product.imageUrl,
        quantity: 1,
        total: product.price,
      ));
    }
    final updatedCart =
        cartItems.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList('cart_items', updatedCart);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('${product.name} added to cart!'),
          duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.primaryColor,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: theme.colorScheme.surface,
          statusBarIconBrightness: theme.brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(true),
        ),
        title: Text(
          widget.category.name,
          style: theme.textTheme.displaySmall?.copyWith(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // TODO: Implement search
            },
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/cart');
            },
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : products.isEmpty
              ? _buildEmptyState(theme)
              : _buildProductsGrid(theme),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading products...'),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No products found',
            style: theme.textTheme.displaySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This category doesn\'t have any products yet.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final result = await Navigator.pushNamed(
                    context, '/product-detail',
                    arguments: product);
                // No need to handle result here as this screen will pop back to home
              },
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16)),
                          child: product.imageUrl.isNotEmpty
                              ? Image.network(product.imageUrl,
                                  fit: BoxFit.cover)
                              : Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.image,
                                      size: 48, color: Colors.grey),
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('Rs. ${product.price.toStringAsFixed(0)}',
                                style: TextStyle(
                                    color: theme.primaryColor,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text(product.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.white.withOpacity(0.8),
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: const Icon(Icons.add, color: Colors.green),
                        tooltip: 'Add to Cart',
                        onPressed: () {
                          addToCart(product);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
