import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<Category> categories = [];
  List<Product> popularProducts = [];
  bool _isLoadingCategories = true;
  int cartItemCount = 0;
  int _selectedIndex = 0;

  // Banner carousel variables
  PageController? _bannerController;
  int _currentBannerIndex = 0;
  Timer? _bannerTimer;

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
    _initializeBannerController();
  }

  void _initializeBannerController() {
    _bannerController = PageController();
    _startBannerAutoScroll();
  }

  void _startBannerAutoScroll() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_bannerController?.hasClients == true) {
        _currentBannerIndex = (_currentBannerIndex + 1) % 3; // 3 banners total
        _bannerController?.animateToPage(
          _currentBannerIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController?.dispose();
    super.dispose();
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Set status bar immediately on build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );
    });

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      drawer: const AppDrawer(),
      appBar: _buildAppBar(theme, screenWidth),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            screenWidth *
                0.02, // Reduced from 4% to 2% since banner now has its own margin
            8,
            screenWidth * 0.02, // Reduced from 4% to 2%
            16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Carousel - Main, Bulk Order, AI Matching
            _buildBannerCarousel(theme, screenWidth, screenHeight),
            SizedBox(height: screenHeight * 0.03), // 3% of screen height

            // Categories Section
            _buildSectionTitle('Categories', theme, screenWidth),
            SizedBox(height: screenHeight * 0.015), // 1.5% of screen height
            _buildCategoriesGrid(theme, screenWidth),
            SizedBox(height: screenHeight * 0.03), // 3% of screen height

            // Popular Items Section
            _buildSectionTitle('Popular Items', theme, screenWidth),
            SizedBox(height: screenHeight * 0.015), // 1.5% of screen height
            _buildPopularItemsList(theme, screenWidth, screenHeight),
            SizedBox(height: screenHeight * 0.03), // 3% of screen height

            // Special Offers Section
            _buildSectionTitle('Special Offers', theme, screenWidth),
            SizedBox(height: screenHeight * 0.015), // 1.5% of screen height
            _buildSpecialOffers(theme, screenWidth, screenHeight),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBannerCarousel(
      ThemeData theme, double screenWidth, double screenHeight) {
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 600;

    return Container(
      height: isSmallScreen
          ? 140
          : isMediumScreen
              ? 160
              : 180,
      margin: EdgeInsets.symmetric(
          horizontal:
              screenWidth * 0.01), // Reduced margin to make banners wider
      child: Stack(
        children: [
          PageView(
            controller: _bannerController!,
            onPageChanged: (index) {
              setState(() {
                _currentBannerIndex = index;
              });
            },
            children: [
              _buildMainBanner(theme, screenWidth, screenHeight),
              _buildBulkOrderBanner(theme, screenWidth, screenHeight),
              _buildAIMatchingBanner(theme, screenWidth, screenHeight),
            ],
          ),
          // Page indicator dots
          Positioned(
            bottom: 12,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentBannerIndex == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainBanner(
      ThemeData theme, double screenWidth, double screenHeight) {
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 600;

    return Container(
      height: isSmallScreen
          ? 140
          : isMediumScreen
              ? 160
              : 180,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Animated gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.primaryColor.withOpacity(0.9),
                    theme.primaryColor,
                    const Color(0xFF8B4513)
                        .withOpacity(0.8), // Brown color for bakery theme
                    const Color(0xFFD2691E), // Chocolate color
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.0, 0.4, 0.7, 1.0],
                ),
              ),
            ),

            // Main content
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Welcome badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Text(
                      '🎉 Welcome to BakeHub',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 10 : 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  SizedBox(height: isSmallScreen ? 4 : 6),

                  // Main heading with gradient text effect
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [Colors.white, Colors.white.withOpacity(0.8)],
                    ).createShader(bounds),
                    child: Text(
                      'Freshly Baked Every Day! 🍰',
                      style: TextStyle(
                        fontSize: isSmallScreen
                            ? 16
                            : isMediumScreen
                                ? 18
                                : 20,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  SizedBox(height: isSmallScreen ? 2 : 4),

                  // App advertisement text
                  Text(
                    'Your favorite bakery items delivered fresh to your doorstep',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: isSmallScreen
                          ? 11
                          : isMediumScreen
                              ? 12
                              : 13,
                      fontWeight: FontWeight.w400,
                      height: 1.1,
                    ),
                  ),

                  SizedBox(height: isSmallScreen ? 2 : 3),

                  // Special offer container
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '🔥 25% OFF on first 3 orders',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen
                            ? 10
                            : isMediumScreen
                                ? 11
                                : 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkOrderBanner(
      ThemeData theme, double screenWidth, double screenHeight) {
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 600;
    final bannerHeight = isSmallScreen
        ? 175.0
        : isMediumScreen
            ? 195.0
            : 215.0;

    return Container(
      height: bannerHeight,
      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.01, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B46C1)
                .withOpacity(0.3), // Purple shadow matching bulk order theme
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Gradient background for bulk order - Matching Bulk Order Screen Theme
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF6B46C1), // Primary Purple from bulk order screen
                    Color(
                        0xFF9333EA), // Secondary Purple from bulk order screen
                    Color(0xFF3B82F6), // Accent Blue from bulk order screen
                    Color(0xFF8B5CF6), // Additional purple shade
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),

            // Main content
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Bulk order badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Text(
                      '🏢 Business Orders',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 10 : 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  SizedBox(height: isSmallScreen ? 4 : 6),

                  // Main heading
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [Colors.white, Colors.white.withOpacity(0.8)],
                    ).createShader(bounds),
                    child: Text(
                      'Bulk Orders Made Easy! 📦',
                      style: TextStyle(
                        fontSize: isSmallScreen
                            ? 16
                            : isMediumScreen
                                ? 18
                                : 20,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  SizedBox(height: isSmallScreen ? 2 : 4),

                  // Description text
                  Text(
                    'Perfect for corporate events, parties and celebrations',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: isSmallScreen
                          ? 11
                          : isMediumScreen
                              ? 12
                              : 13,
                      fontWeight: FontWeight.w400,
                      height: 1.1,
                    ),
                  ),

                  SizedBox(height: isSmallScreen ? 2 : 3),

                  // Special offer container
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9333EA)
                          .withOpacity(0.3), // secondaryPurple accent
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '💼 Special rates for bulk orders',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen
                            ? 11
                            : isMediumScreen
                                ? 12
                                : 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIMatchingBanner(
      ThemeData theme, double screenWidth, double screenHeight) {
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 600;
    final bannerHeight = isSmallScreen
        ? 160.0
        : isMediumScreen
            ? 180.0
            : 200.0;
    return Container(
      height: bannerHeight,
      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.01, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0)
                .withOpacity(0.4), // AI theme purple shadow
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // AI Matching Screen gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF9C27B0), // Primary AI theme color
                    Color(0xFFBA68C8), // Lighter purple
                    Color(0xFFE1BEE7), // Even lighter purple
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.6, 1.0],
                ),
              ),
            ),

            // Main content
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Text(
                      '🤖 AI Powered',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 10 : 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 4 : 8),
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [Colors.white, Colors.white.withOpacity(0.8)],
                    ).createShader(bounds),
                    child: Text(
                      'Smart Cake Matching! 🎯',
                      style: TextStyle(
                        fontSize: isSmallScreen
                            ? 18
                            : isMediumScreen
                                ? 20
                                : 22,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 2 : 4),

                  // Description text
                  Text(
                    'AI finds the perfect cake for your taste and budget',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: isSmallScreen
                          ? 11
                          : isMediumScreen
                              ? 12
                              : 13,
                      fontWeight: FontWeight.w400,
                      height: 1.1,
                    ),
                  ),

                  SizedBox(height: isSmallScreen ? 2 : 3),

                  // Special offer container
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C27B0)
                          .withOpacity(0.3), // AI theme purple accent
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '🧠 Try our intelligent recommendations',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen
                            ? 10
                            : isMediumScreen
                                ? 11
                                : 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme, double screenWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: theme.textTheme.displaySmall,
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MenuScreen()),
            );
          },
          child: Text(
            'See All',
            style: TextStyle(color: theme.primaryColor),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesGrid(ThemeData theme, double screenWidth) {
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 600;

    if (_isLoadingCategories) {
      return SizedBox(
        height: isSmallScreen ? 90 : 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 4, // Show 4 loading placeholders
          itemBuilder: (context, index) {
            return Container(
              width: isSmallScreen ? 70 : 80,
              margin: EdgeInsets.only(right: isSmallScreen ? 12 : 16),
              child: Column(
                children: [
                  Container(
                    height: isSmallScreen ? 50 : 60,
                    width: isSmallScreen ? 50 : 60,
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
                    width: isSmallScreen ? 50 : 60,
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
        height: isSmallScreen ? 90 : 100,
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

    // For larger screens, show more categories in a grid
    if (!isMediumScreen && categories.length > 4) {
      return Column(
        children: [
          // First row - horizontal scroll
          SizedBox(
            height: isSmallScreen ? 90 : 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length > 6 ? 6 : categories.length,
              itemBuilder: (context, index) =>
                  _buildCategoryItem(categories[index], theme, isSmallScreen),
            ),
          ),
          // Second row if more than 6 categories
          if (categories.length > 6) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: isSmallScreen ? 90 : 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount:
                    categories.length - 6 > 6 ? 6 : categories.length - 6,
                itemBuilder: (context, index) => _buildCategoryItem(
                    categories[index + 6], theme, isSmallScreen),
              ),
            ),
          ],
        ],
      );
    }

    // Default horizontal scroll for small/medium screens
    return SizedBox(
      height: isSmallScreen ? 90 : 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) =>
            _buildCategoryItem(categories[index], theme, isSmallScreen),
      ),
    );
  }

  Widget _buildCategoryItem(
      Category category, ThemeData theme, bool isSmallScreen) {
    return Container(
      width: isSmallScreen ? 70 : 80,
      margin: EdgeInsets.only(right: isSmallScreen ? 12 : 16),
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryProductsScreen(category: category),
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
              height: isSmallScreen ? 50 : 60,
              width: isSmallScreen ? 50 : 60,
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
                          return _getCategoryIcon(
                              category.name, theme, isSmallScreen);
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                      )
                    : _getCategoryIcon(category.name, theme, isSmallScreen),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: isSmallScreen ? 11 : 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _getCategoryIcon(
      String categoryName, ThemeData theme, bool isSmallScreen) {
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
      size: isSmallScreen ? 24 : 30,
      color: theme.primaryColor,
    );
  }

  Widget _buildPopularItemsList(
      ThemeData theme, double screenWidth, double screenHeight) {
    return SizedBox(
      height: screenHeight < 600 ? 250 : 300, // Responsive height
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

  Widget _buildSpecialOffers(
      ThemeData theme, double screenWidth, double screenHeight) {
    final isSmallScreen = screenWidth < 360;

    return Container(
      height: isSmallScreen ? 100 : 120,
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

  PreferredSizeWidget _buildAppBar(ThemeData theme, double screenWidth) {
    final isSmallScreen = screenWidth < 360;

    return AppBar(
      backgroundColor: theme.primaryColor,
      elevation: 0,
      title: Text(
        'BakeHub',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: isSmallScreen ? 20 : 24,
        ),
      ),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () {
            // TODO: Implement search functionality
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Search feature coming soon!'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
        IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.shopping_cart, color: Colors.white),
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
                      cartItemCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: _navigateToCart,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
