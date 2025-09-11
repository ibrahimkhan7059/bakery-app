import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/category.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../models/cart_item.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({Key? key}) : super(key: key);

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<Category> categories = [];
  List<Product> products = [];
  int selectedCategoryIndex = 0;
  late TabController tabController;
  bool isLoadingCategories = true;
  bool isLoadingProducts = true;
  int _selectedIndex = 3; // Menu tab index

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() {
      isLoadingCategories = true;
    });
    try {
      categories = await _apiService.getCategories();
      tabController = TabController(length: categories.length, vsync: this);
      tabController.addListener(() {
        setState(() {
          selectedCategoryIndex = tabController.index;
          _fetchProducts(categories[selectedCategoryIndex].id);
        });
      });
      if (categories.isNotEmpty) {
        _fetchProducts(categories[0].id);
      }
    } catch (e) {
      // Handle error (show snackbar, etc.)
    } finally {
      setState(() {
        isLoadingCategories = false;
      });
    }
  }

  Future<void> _fetchProducts(int categoryId) async {
    setState(() {
      isLoadingProducts = true;
    });
    try {
      products = await _apiService.getProductsByCategory(categoryId);
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        isLoadingProducts = false;
      });
    }
  }

  Future<void> addToCart(Product product) async {
    final prefs = await SharedPreferences.getInstance();
    final cartItemStrings = prefs.getStringList('cart_items') ?? [];
    List<CartItem> cartItems = cartItemStrings
        .map((item) => CartItem.fromJson(jsonDecode(item)))
        .toList();
    // Check if product already in cart
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
        image: product.image ?? '',
        quantity: 1,
        total: product.price,
      ));
    }
    final updatedCart =
        cartItems.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList('cart_items', updatedCart);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product.name} added to cart!')),
    );
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar color to match theme
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Theme.of(context).primaryColor,
      statusBarIconBrightness: Brightness.light,
    ));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true),
        ),
        bottom: isLoadingCategories || categories.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Container(
                  color: Theme.of(context).primaryColor,
                  child: TabBar(
                    controller: tabController,
                    isScrollable: true,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.white
                          .withOpacity(0.35), // Lighter color for visibility
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    tabs: [
                      for (final category in categories)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Text(category.name),
                        ),
                    ],
                  ),
                ),
              ),
      ),
      backgroundColor: const Color(0xFFF7F7F7),
      body: isLoadingCategories
          ? const Center(child: CircularProgressIndicator())
          : categories.isEmpty
              ? const Center(child: Text('No categories found'))
              : TabBarView(
                  controller: tabController,
                  children: [
                    for (final category in categories)
                      _buildProductGrid(category),
                  ],
                ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == _selectedIndex) return;
          setState(() {
            _selectedIndex = index;
          });
          switch (index) {
            case 0:
              Navigator.pushNamed(context, '/home');
              break;
            case 1:
              Navigator.pushNamed(context, '/bulk-order');
              break;
            case 2:
              Navigator.pushNamed(context, '/custom-cake-options');
              break;
            case 3:
              // Already on Menu
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'Bulk Order',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cake),
            label: 'Custom Cake',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Menu',
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(Category category) {
    final filteredProducts =
        products.where((p) => p.categoryId == category.id).toList();
    if (isLoadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (filteredProducts.isEmpty) {
      return const Center(child: Text('No products found for this category'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        return Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              // Navigate to Product Detail screen (pass product)
              Navigator.pushNamed(context, '/product-detail',
                  arguments: product);
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
                        child: product.image != null
                            ? Image.network(product.image!, fit: BoxFit.cover)
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
                                  color: Theme.of(context).primaryColor,
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
    );
  }
}
