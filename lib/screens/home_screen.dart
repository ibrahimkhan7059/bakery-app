import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import 'category_products_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/app_drawer.dart';
import 'custom_cake_options_screen.dart';
import 'menu_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  List<Category> categories = [];
  List<Product> popularProducts = [];
  bool _isLoadingCategories = true;
  final bool _isLoadingProducts = true;
  int cartItemCount = 0;
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> popularItems = [
    {
      'name': 'Chocolate Cake',
      'price': 'Rs. 1500',
      'rating': 4.8,
      'image': 'assets/images/chocolate_cake.jpg',
      'description': 'Rich chocolate cake with creamy frosting'
    },
    {
      'name': 'Strawberry Pastry',
      'price': 'Rs. 300',
      'rating': 4.6,
      'image': 'assets/images/strawberry_pastry.jpg',
      'description': 'Fresh strawberry pastry with vanilla cream'
    },
    {
      'name': 'Croissant',
      'price': 'Rs. 200',
      'rating': 4.7,
      'image': 'assets/images/croissant.jpg',
      'description': 'Buttery, flaky croissant baked fresh daily'
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadCartCount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh cart count when screen becomes active
    _loadCartCount();
  }

  Future<void> _loadCategories() async {
    try {
      print('Loading categories...'); // Debug log
      final fetchedCategories = await _apiService.getCategories();
      print('Categories loaded: ${fetchedCategories.length}'); // Debug log

      setState(() {
        categories = fetchedCategories;
        _isLoadingCategories = false;
      });
    } catch (e) {
      print('Error loading categories: $e'); // Debug log
      setState(() {
        _isLoadingCategories = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load categories: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadCategories,
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadCartCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartItems = prefs.getStringList('cart_items') ?? [];
      setState(() {
        cartItemCount = cartItems.length;
      });
    } catch (e) {
      setState(() {
        cartItemCount = 0;
      });
    }
  }

  void _navigateToCart() async {
    final result = await Navigator.pushNamed(context, '/cart');
    // Refresh cart count when returning from cart screen
    _loadCartCount();
    if (result == true || result == null) {
      setState(() {
        _selectedIndex = 0; // Reset to Home when returning
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      drawer: const AppDrawer(),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.primaryColor,
        automaticallyImplyLeading: true,
        toolbarHeight: 70,
        leading: Builder(
          builder: (context) => Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.menu,
                color: Colors.white,
                size: 22,
              ),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: theme.colorScheme.surface,
          statusBarIconBrightness: theme.brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Good Morning! 👋',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'BakeHub',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () async {
                    final result =
                        await Navigator.pushNamed(context, '/search');
                    if (result == true || result == null) {
                      setState(() {
                        _selectedIndex = 0; // Reset to Home when returning
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.shopping_cart,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _navigateToCart,
                    ),
                    if (cartItemCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$cartItemCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Card
            _buildBannerCard(theme),
            const SizedBox(height: 24),

            // Categories Section
            _buildSectionTitle('Categories', theme),
            const SizedBox(height: 12),
            _buildCategoriesGrid(theme),
            const SizedBox(height: 24),

            // Popular Items Section
            _buildSectionTitle('Popular Items', theme),
            const SizedBox(height: 12),
            _buildPopularItemsList(theme),
            const SizedBox(height: 24),

            // Special Offers Section
            _buildSectionTitle('Special Offers', theme),
            const SizedBox(height: 12),
            _buildSpecialOffers(theme),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBannerCard(ThemeData theme) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor.withOpacity(0.8),
            theme.primaryColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Fresh Baked Daily!',
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Get 20% off on your first order',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Implement order now
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: theme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Order Now'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: theme.textTheme.displaySmall,
        ),
        TextButton(
          onPressed: () {
            // TODO: Implement see all
          },
          child: Text(
            'See All',
            style: TextStyle(color: theme.primaryColor),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesGrid(ThemeData theme) {
    if (_isLoadingCategories) {
      return SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 4, // Show 4 loading placeholders
          itemBuilder: (context, index) {
            return Container(
              width: 80,
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                children: [
                  Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    if (categories.isEmpty) {
      return SizedBox(
        height: 100,
        child: Center(
          child: Text(
            'No categories available',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Container(
            width: 80,
            margin: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CategoryProductsScreen(category: category),
                  ),
                );
                if (result == true || result == null) {
                  setState(() {
                    _selectedIndex = 0; // Reset to Home when returning
                  });
                }
              },
              child: Column(
                children: [
                  Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.primaryColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: category.image != null
                          ? Image.network(
                              category.image!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _getCategoryIcon(category.name, theme);
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                            )
                          : _getCategoryIcon(category.name, theme),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category.name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _getCategoryIcon(String categoryName, ThemeData theme) {
    IconData icon;
    switch (categoryName.toLowerCase()) {
      case 'cakes':
      case 'cake':
        icon = Icons.cake;
        break;
      case 'pastries':
      case 'pastry':
        icon = Icons.restaurant;
        break;
      case 'cookies':
      case 'cookie':
        icon = Icons.cookie;
        break;
      case 'breads':
      case 'bread':
        icon = Icons.bakery_dining;
        break;
      case 'donuts':
      case 'donut':
        icon = Icons.donut_large;
        break;
      case 'muffins':
      case 'muffin':
        icon = Icons.cake_outlined;
        break;
      default:
        icon = Icons.fastfood;
    }

    return Icon(
      icon,
      size: 30,
      color: theme.primaryColor,
    );
  }

  Widget _buildPopularItemsList(ThemeData theme) {
    return SizedBox(
      height: 300, // Increased height to prevent overflow
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: popularItems.length,
        itemBuilder: (context, index) {
          final item = popularItems[index];
          return Container(
            width: 200,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor,
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.image,
                      size: 50,
                      color: theme.primaryColor.withOpacity(0.5),
                    ),
                  ),
                ),
                Expanded(
                  // Make the content area flexible
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment
                          .spaceBetween, // Distribute space evenly
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'],
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF333333),
                              ),
                              maxLines: 1, // Limit to 1 line to save space
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['description'],
                              style: theme.textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Colors.amber[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  item['rating'].toString(),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['price'],
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.primaryColor,
                              ),
                            ),
                            Container(
                              height: 32,
                              width: 32,
                              decoration: BoxDecoration(
                                color: theme.primaryColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpecialOffers(ThemeData theme) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor.withOpacity(0.7),
            theme.primaryColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            bottom: -30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Weekend Special',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Buy 2 Get 1 Free on all pastries',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          // TODO: Implement claim offer
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: theme.primaryColor,
                          minimumSize: const Size(100, 32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Claim Now'),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.local_offer,
                  size: 50,
                  color: Colors.white30,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: AppTheme.primaryColor,
      unselectedItemColor: Colors.grey,
      currentIndex: _selectedIndex,
      onTap: (index) async {
        setState(() {
          _selectedIndex = index;
        });
        switch (index) {
          case 0:
            // Already on home
            break;
          case 1:
            final result = await Navigator.pushNamed(context, '/bulk-order');
            if (result == true || result == null) {
              setState(() {
                _selectedIndex = 0; // Reset to Home
              });
            }
            break;
          case 2:
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CustomCakeOptionsScreen(),
              ),
            );
            if (result == true || result == null) {
              setState(() {
                _selectedIndex = 0; // Reset to Home
              });
            }
            break;
          case 3:
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MenuScreen(),
              ),
            );
            if (result == true || result == null) {
              setState(() {
                _selectedIndex = 0; // Reset to Home
              });
            }
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
    );
  }
}
