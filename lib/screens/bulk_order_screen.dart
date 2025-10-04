import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async'; // Added for Timer
import 'package:http/http.dart' as http;
import '../models/bulk_order.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'payment_screen.dart';

const Color primaryPurple = Color(0xFF6B46C1);
const Color secondaryPurple = Color(0xFF9333EA);
const Color accentBlue = Color(0xFF3B82F6);
const Color accentPink = Color(0xFFEC4899);
const Color lightPurple = Color(0xFFF3F4F6);
const Color darkPurple = Color(0xFF4C1D95);

class BulkOrderScreen extends StatefulWidget {
  const BulkOrderScreen({super.key});

  @override
  _BulkOrderScreenState createState() => _BulkOrderScreenState();
}

class _BulkOrderScreenState extends State<BulkOrderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  List<BulkOrder> _bulkOrders = [];
  bool _isLoading = true;
  int _selectedIndex = 1; // Bulk Order tab index
  Timer? _autoRefreshTimer; // Timer for auto refresh

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBulkOrders();
    _startAutoRefresh(); // Start auto refresh timer

    // Set status bar color to match app bar gradient (primaryPurple)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: primaryPurple, // Same as app bar background
        statusBarIconBrightness: Brightness.light,
      ));
    });
  }

  Future<void> _loadBulkOrders({bool isManualRefresh = false}) async {
    try {
      // Test server connection first
      print('Testing server connection...');
      final connectionTest = await _apiService.testServerConnection();
      print('Server connection test result: $connectionTest');

      if (!connectionTest) {
        print('Server connection test failed - trying anyway...');
      }

      // Get all bulk orders from API
      final allOrders = await _apiService.getBulkOrders();
      print('Total orders fetched: ${allOrders.length}'); // Debug log

      // Debug: Print each order's details with ownership check
      for (int i = 0; i < allOrders.length; i++) {
        final order = allOrders[i];
        final belongsToUser = await _isCurrentUserOrder(order);
        print(
            'Order $i: ID=${order.id}, CustomerName=${order.customerName}, UserId=${order.userId}, BelongsToCurrentUser=$belongsToUser');
      }

      // Debug: Check all available keys in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      print('Available SharedPreferences keys: $allKeys');
      print('auth_token: ${prefs.getString('auth_token')}');
      print('authToken: ${prefs.getString('authToken')}');
      print('user_data: ${prefs.getString('user_data')}');
      print('user_name: ${prefs.getString('user_name')}');
      print('user_id: ${prefs.getInt('user_id')}');

      // Get current user ID from AuthService
      final AuthService authService = AuthService();
      final currentUser = await authService.getCurrentUser();
      print('Current user from AuthService: $currentUser'); // Debug log

      List<BulkOrder> userOrders = [];

      // Get user identification data
      final directUserId = prefs.getInt('user_id');
      final token = prefs.getString('authToken');
      final userName = prefs.getString('user_name');

      print('User identification data:');
      print('- AuthService user: $currentUser');
      print('- SharedPrefs user_id: $directUserId');
      print('- AuthToken: ${token != null ? "Present" : "Missing"}');
      print('- User name: $userName');

      // Try multiple filtering strategies to ensure we catch ONLY the user's orders
      if (currentUser != null && currentUser['id'] != null) {
        final currentUserId = currentUser['id'];
        userOrders =
            allOrders.where((order) => order.userId == currentUserId).toList();
        print(
            'Strategy 1 (AuthService ID): Found ${userOrders.length} orders for user ID $currentUserId');
      }

      // If no orders found with AuthService, try SharedPrefs user_id (STRICT matching)
      if (userOrders.isEmpty && directUserId != null) {
        userOrders =
            allOrders.where((order) => order.userId == directUserId).toList();
        print(
            'Strategy 2 (SharedPrefs ID): Found ${userOrders.length} orders for user ID $directUserId');
      }

      // REMOVE name-based filtering as it can show other users' orders with similar names
      // Only use user ID based filtering for security

      // If still no orders and we have a valid user session, try default user ID (1) but ONLY with exact name match
      if (userOrders.isEmpty &&
          token != null &&
          token.isNotEmpty &&
          userName != null &&
          userName.isNotEmpty) {
        const defaultUserId = 1;
        // Very strict name matching - must be exact match (case insensitive)
        userOrders = allOrders
            .where((order) =>
                order.userId == defaultUserId &&
                order.customerName.toLowerCase() == userName.toLowerCase())
            .toList();
        print(
            'Strategy 3 (Default ID + Exact Name): Found ${userOrders.length} orders for default ID with exact name match');

        // Save the default user ID for future use if not already saved
        if (directUserId == null) {
          await prefs.setInt('user_id', defaultUserId);
          print('Saved default user_id: $defaultUserId');
        }
      }

      // SECURITY: Never show all orders for debugging in production
      if (userOrders.isEmpty && allOrders.isNotEmpty) {
        print('No orders found for current user');
        print(
            'Current user data: ID=${currentUser?['id']}, Name=$userName, StoredID=$directUserId');
        print(
            'Available order user IDs: ${allOrders.map((o) => o.userId).toSet()}');
        print(
            'Available customer names: ${allOrders.map((o) => o.customerName).toSet()}');
        // Keep userOrders empty for security - don't show other users' orders
      }

      setState(() {
        _bulkOrders = userOrders;
        _isLoading = false;
      });
      print(
          'Successfully updated state with ${userOrders.length} orders'); // Debug log
    } catch (e) {
      print('Error loading bulk orders: $e'); // Debug log
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to load bulk orders');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Helper method to check if an order belongs to current user
  Future<bool> _isCurrentUserOrder(BulkOrder order) async {
    final prefs = await SharedPreferences.getInstance();
    final AuthService authService = AuthService();
    final currentUser = await authService.getCurrentUser();
    final directUserId = prefs.getInt('user_id');
    final userName = prefs.getString('user_name');

    // Primary check: AuthService user ID
    if (currentUser != null && currentUser['id'] != null) {
      return order.userId == currentUser['id'];
    }

    // Secondary check: SharedPreferences user ID
    if (directUserId != null) {
      return order.userId == directUserId;
    }

    // Tertiary check: Exact name match with default user ID
    if (userName != null && userName.isNotEmpty) {
      return order.userId == 1 &&
          order.customerName.toLowerCase() == userName.toLowerCase();
    }

    return false; // Default: not user's order
  }

  // Auto refresh timer methods
  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(Duration(seconds: 20), (timer) {
      if (mounted) {
        _loadBulkOrders();
        print('Auto refreshing bulk orders...');
      }
    });
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryPurple,
              secondaryPurple,
              accentBlue,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildCustomAppBar(),
              _buildTabBar(),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCreateOrderTab(),
                      _buildOrderHistoryTab(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context, true),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bulk Orders',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Order in large quantities',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width > 600
            ? 20
            : 16, // Responsive margin
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(25),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        labelColor: primaryPurple,
        unselectedLabelColor: Colors.white,
        labelStyle: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: MediaQuery.of(context).size.width > 600
              ? 16
              : 14, // Responsive font size
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: MediaQuery.of(context).size.width > 600
              ? 16
              : 14, // Responsive font size
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_shopping_cart,
                    size: MediaQuery.of(context).size.width > 600
                        ? 20
                        : 18), // Responsive icon size
                SizedBox(
                    width: MediaQuery.of(context).size.width > 600
                        ? 8
                        : 6), // Responsive spacing
                Flexible(
                  // Added Flexible to prevent overflow
                  child: Text(
                    'Create Order',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history,
                    size: MediaQuery.of(context).size.width > 600
                        ? 20
                        : 18), // Responsive icon size
                SizedBox(
                    width: MediaQuery.of(context).size.width > 600
                        ? 8
                        : 6), // Responsive spacing
                Flexible(
                  // Added Flexible to prevent overflow
                  child: Text(
                    'Order History',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.topRight,
          colors: [
            primaryPurple.withOpacity(0.1),
            accentBlue.withOpacity(0.1),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: primaryPurple,
        unselectedItemColor: Colors.grey.shade600,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        currentIndex: _selectedIndex,
        onTap: (index) async {
          if (index == _selectedIndex) return;
          setState(() {
            _selectedIndex = index;
          });
          switch (index) {
            case 0:
              final result = await Navigator.pushNamed(context, '/home');
              if (result == true || result == null) {
                setState(() {
                  _selectedIndex = 1; // Stay on Bulk Order
                });
              }
              break;
            case 1:
              // Already on Bulk Order
              break;
            case 2:
              final result =
                  await Navigator.pushNamed(context, '/custom-cake-options');
              if (result == true || result == null) {
                setState(() {
                  _selectedIndex = 1; // Stay on Bulk Order
                });
              }
              break;
            case 3:
              final result = await Navigator.pushNamed(context, '/menu');
              if (result == true || result == null) {
                setState(() {
                  _selectedIndex = 1; // Stay on Bulk Order
                });
              }
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business_outlined),
            activeIcon: Icon(Icons.business),
            label: 'Bulk Order',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cake_outlined),
            activeIcon: Icon(Icons.cake),
            label: 'Custom Cake',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Menu',
          ),
        ],
      ),
    );
  }

  Widget _buildCreateOrderTab() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width > 600
            ? 20
            : 16, // Responsive padding
        vertical: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 20), // Reduced spacing
            _buildQuickStatsCard(),
            const SizedBox(height: 20), // Reduced spacing
            _buildCreateOrderForm(),
            const SizedBox(
                height: 20), // Added bottom padding for better scrolling
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width > 600
          ? 24
          : 16), // Responsive padding
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryPurple.withOpacity(0.1),
            accentBlue.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryPurple.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [primaryPurple, accentBlue],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_offer,
              color: Colors.white,
              size: 32,
            ),
          ),
          SizedBox(
              width: MediaQuery.of(context).size.width > 600
                  ? 20
                  : 12), // Responsive spacing
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Special Bulk Pricing',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: darkPurple,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Get up to 25% discount on orders above 50 items',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsCard() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.shopping_cart,
            title: 'Min Order',
            value: '10 Items',
            color: accentBlue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            icon: Icons.discount,
            title: 'Max Discount',
            value: '25% Off',
            color: accentPink,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            icon: Icons.schedule,
            title: 'Lead Time',
            value: '5-6 Days',
            color: secondaryPurple,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: darkPurple,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateOrderForm() {
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width > 600
          ? 24
          : 16), // Responsive padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryPurple, accentBlue],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(
                  width: MediaQuery.of(context).size.width > 600
                      ? 12
                      : 8), // Responsive spacing
              Expanded(
                // Added Expanded to prevent overflow
                child: Text(
                  'Create New Bulk Order',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width > 600
                        ? 20
                        : 18, // Responsive font size
                    fontWeight: FontWeight.bold,
                    color: darkPurple,
                  ),
                  overflow: TextOverflow.ellipsis, // Handle text overflow
                ),
              ),
            ],
          ),
          SizedBox(
              height: MediaQuery.of(context).size.width > 600
                  ? 24
                  : 16), // Responsive spacing
          const CreateBulkOrderForm(),
        ],
      ),
    );
  }

  Widget _buildOrderHistoryTab() {
    if (_isLoading) {
      return Container(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width > 600
            ? 40
            : 24), // Responsive padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width > 600
                  ? 20
                  : 16), // Responsive padding
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryPurple.withOpacity(0.1),
                    accentBlue.withOpacity(0.1)
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryPurple),
              ),
            ),
            SizedBox(
                height: MediaQuery.of(context).size.width > 600
                    ? 20
                    : 16), // Responsive spacing
            Text(
              'Loading your orders...',
              style: TextStyle(
                color: darkPurple,
                fontSize: MediaQuery.of(context).size.width > 600
                    ? 16
                    : 14, // Responsive font size
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    if (_bulkOrders.isEmpty) {
      return Container(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width > 600
            ? 40
            : 24), // Responsive padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width > 600
                  ? 24
                  : 20), // Responsive padding
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryPurple.withOpacity(0.1),
                    accentBlue.withOpacity(0.1)
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: MediaQuery.of(context).size.width > 600
                    ? 80
                    : 64, // Responsive icon size
                color: Colors.grey.shade400,
              ),
            ),
            SizedBox(
                height: MediaQuery.of(context).size.width > 600
                    ? 24
                    : 20), // Responsive spacing
            Text(
              'No bulk orders found',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width > 600
                    ? 24
                    : 20, // Responsive font size
                fontWeight: FontWeight.bold,
                color: darkPurple,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your bulk orders will appear here once you create them.\nOnly your orders are shown for security.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: MediaQuery.of(context).size.width > 600
                    ? 16
                    : 14, // Responsive font size
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(
                height: MediaQuery.of(context).size.width > 600
                    ? 24
                    : 20), // Responsive spacing
            // Make buttons responsive for smaller screens
            MediaQuery.of(context).size.width > 600
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          _loadBulkOrders(
                              isManualRefresh: true); // Refresh orders
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          _tabController.animateTo(0);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Create Order'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _tabController.animateTo(0);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Order'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _loadBulkOrders(
                                isManualRefresh: true); // Refresh orders
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: primaryPurple,
      onRefresh: () => _loadBulkOrders(isManualRefresh: true),
      child: ListView.builder(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width > 600
            ? 20
            : 16), // Responsive padding
        itemCount: _bulkOrders.length,
        itemBuilder: (context, index) {
          final order = _bulkOrders[index];
          return _buildOrderCard(order);
        },
      ),
    );
  }

  Widget _buildOrderCard(BulkOrder order) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (order.status.toLowerCase()) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending_actions;
        statusText = 'Pending';
        break;
      case 'confirmed':
        statusColor = Colors.blue;
        statusIcon = Icons.verified;
        statusText = 'Confirmed';
        break;
      case 'processing':
      case 'in_progress':
        statusColor = accentBlue;
        statusIcon = Icons.timer;
        statusText = 'In Progress';
        break;
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Approved';
        break;
      case 'completed':
        statusColor = Colors.green.shade700;
        statusIcon = Icons.task_alt;
        statusText = 'Completed';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_outlined;
        statusText = 'Cancelled';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = 'Unknown';
    }

    return Container(
      margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.width > 600
              ? 16
              : 12), // Responsive margin
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: primaryPurple.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _viewOrderDetails(order),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.all(MediaQuery.of(context).size.width > 600
              ? 20
              : 16), // Responsive padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(
                        MediaQuery.of(context).size.width > 600
                            ? 12
                            : 10), // Responsive padding
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryPurple.withOpacity(0.1),
                          accentBlue.withOpacity(0.1)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      color: primaryPurple,
                      size: MediaQuery.of(context).size.width > 600
                          ? 24
                          : 20, // Responsive icon size
                    ),
                  ),
                  SizedBox(
                      width: MediaQuery.of(context).size.width > 600
                          ? 16
                          : 12), // Responsive spacing
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.customerName,
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width > 600
                                ? 18
                                : 16, // Responsive font size
                            fontWeight: FontWeight.bold,
                            color: darkPurple,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.width > 600
                                ? 4
                                : 2), // Responsive spacing
                        Text(
                          'Order #${order.id}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: MediaQuery.of(context).size.width > 600
                                ? 14
                                : 12, // Responsive font size
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width *
                          0.3, // Responsive width limit
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width > 600
                          ? 12
                          : 10, // Responsive padding
                      vertical: MediaQuery.of(context).size.width > 600 ? 8 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon,
                            size: MediaQuery.of(context).size.width > 600
                                ? 16
                                : 14,
                            color: statusColor), // Responsive icon size
                        SizedBox(
                            width: MediaQuery.of(context).size.width > 600
                                ? 6
                                : 4), // Responsive spacing
                        Expanded(
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: MediaQuery.of(context).size.width > 600
                                  ? 12
                                  : 10, // Responsive font size
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(
                  height: MediaQuery.of(context).size.width > 600
                      ? 20
                      : 16), // Responsive spacing
              Container(
                padding: EdgeInsets.all(MediaQuery.of(context).size.width > 600
                    ? 16
                    : 12), // Responsive padding
                decoration: BoxDecoration(
                  color: lightPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: MediaQuery.of(context).size.width > 600
                    ? Row(
                        children: [
                          Expanded(
                            child: _buildOrderDetail(
                              icon: Icons.shopping_bag_outlined,
                              label: 'Quantity',
                              value:
                                  '${order.items.fold(0, (sum, item) => sum + item.quantity)} items',
                              color: accentBlue,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey.shade300,
                          ),
                          Expanded(
                            child: _buildOrderDetail(
                              icon: Icons.attach_money,
                              label: 'Total',
                              value:
                                  'Rs. ${order.totalAmount.toStringAsFixed(0)}',
                              color: accentPink,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey.shade300,
                          ),
                          Expanded(
                            child: _buildOrderDetail(
                              icon: Icons.calendar_today,
                              label: 'Date',
                              value: _formatDate(order.createdAt),
                              color: secondaryPurple,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        // Stack vertically for smaller screens
                        children: [
                          _buildOrderDetail(
                            icon: Icons.shopping_bag_outlined,
                            label: 'Quantity',
                            value:
                                '${order.items.fold(0, (sum, item) => sum + item.quantity)} items',
                            color: accentBlue,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildOrderDetail(
                                  icon: Icons.attach_money,
                                  label: 'Total',
                                  value:
                                      'Rs. ${order.totalAmount.toStringAsFixed(0)}',
                                  color: accentPink,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildOrderDetail(
                                  icon: Icons.calendar_today,
                                  label: 'Date',
                                  value: _formatDate(order.createdAt),
                                  color: secondaryPurple,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              if (order.specialInstructions != null &&
                  order.specialInstructions!.isNotEmpty) ...[
                SizedBox(
                    height: MediaQuery.of(context).size.width > 600
                        ? 16
                        : 12), // Responsive spacing
                Container(
                  padding: EdgeInsets.all(
                      MediaQuery.of(context).size.width > 600
                          ? 12
                          : 10), // Responsive padding
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.shade200,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.note,
                          color: Colors.blue.shade600,
                          size: MediaQuery.of(context).size.width > 600
                              ? 16
                              : 14), // Responsive icon size
                      SizedBox(
                          width: MediaQuery.of(context).size.width > 600
                              ? 8
                              : 6), // Responsive spacing
                      Expanded(
                        child: Text(
                          order.specialInstructions!,
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: MediaQuery.of(context).size.width > 600
                                ? 12
                                : 10, // Responsive font size
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Action buttons with responsive design
              SizedBox(
                  height: MediaQuery.of(context).size.width > 600
                      ? 16
                      : 12), // Responsive spacing
              MediaQuery.of(context).size.width > 600
                  ? Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _viewOrderDetails(order),
                            icon: const Icon(Icons.visibility, size: 16),
                            label: const Text('View Details'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        if (_canDeleteOrder(order)) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _deleteOrder(order),
                              icon: const Icon(Icons.delete, size: 16),
                              label: const Text('Delete'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    )
                  : Column(
                      // Stack vertically for smaller screens
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _viewOrderDetails(order),
                            icon: const Icon(Icons.visibility, size: 16),
                            label: const Text('View Details'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        if (_canDeleteOrder(order)) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _deleteOrder(order),
                              icon: const Icon(Icons.delete, size: 16),
                              label: const Text('Delete'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canDeleteOrder(BulkOrder order) {
    // Check if order is within 2 days of creation
    final twoDaysFromCreation = order.createdAt.add(const Duration(days: 2));
    final now = DateTime.now();

    // Check if status allows deletion
    final allowedStatuses = ['pending', 'confirmed'];

    return now.isBefore(twoDaysFromCreation) &&
        allowedStatuses.contains(order.status.toLowerCase());
  }

  Future<void> _deleteOrder(BulkOrder order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: const Text(
            'Are you sure you want to delete this order? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        print('Attempting to delete order ${order.id}');
        print(
            'API URL: http://192.168.100.4:8080/api/v1/bulk-orders/${order.id}');

        // Test connection first
        final testResponse = await http.get(
          Uri.parse('http://192.168.100.4:8080/api/v1/bulk-orders'),
          headers: {'Content-Type': 'application/json'},
        );
        print('Test connection status: ${testResponse.statusCode}');

        final response = await http.delete(
          Uri.parse('http://192.168.100.4:8080/api/v1/bulk-orders/${order.id}'),
          headers: {'Content-Type': 'application/json'},
        );

        print('Delete response status: ${response.statusCode}');
        print('Delete response body: ${response.body}');

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadBulkOrders(); // Refresh the orders list
        } else {
          final errorData = json.decode(response.body);
          print('Delete error: $errorData');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['message'] ?? 'Failed to delete order'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        print('Delete exception: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildOrderDetail({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon,
            color: color,
            size: MediaQuery.of(context).size.width > 600
                ? 20
                : 18), // Responsive icon size
        SizedBox(
            height: MediaQuery.of(context).size.width > 600
                ? 8
                : 6), // Responsive spacing
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: MediaQuery.of(context).size.width > 600
                ? 12
                : 10, // Responsive font size
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(
            height: MediaQuery.of(context).size.width > 600
                ? 4
                : 2), // Responsive spacing
        Text(
          value,
          style: TextStyle(
            color: darkPurple,
            fontSize: MediaQuery.of(context).size.width > 600
                ? 14
                : 12, // Responsive font size
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _viewOrderDetails(BulkOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => OrderDetailsSheet(
          order: order,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopAutoRefresh(); // Stop auto refresh timer
    _tabController.dispose();
    super.dispose();
  }
}

class CreateBulkOrderForm extends StatefulWidget {
  const CreateBulkOrderForm({super.key});

  @override
  _CreateBulkOrderFormState createState() => _CreateBulkOrderFormState();
}

class _CreateBulkOrderFormState extends State<CreateBulkOrderForm> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  final _eventDetailsController = TextEditingController();
  final _specialInstructionsController = TextEditingController();

  String _orderType = 'birthday';
  String _paymentMethod = 'cash';
  DateTime _deliveryDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay? _deliveryTime;
  final List<BulkOrderItem> _items = [];
  bool? _isUserLoggedIn;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');

      print('Loading user data for bulk order...');
      print('Auth token exists: ${token != null}');

      setState(() {
        _isUserLoggedIn = token != null;
      });

      if (token != null) {
        // User is logged in, try to fetch latest profile data
        try {
          print('Fetching user profile from API...');
          final ApiService apiService = ApiService();
          final userData = await apiService.getUserProfile();
          print('API Response: $userData');

          setState(() {
            // API response structure: { success: true, data: { user fields } }
            final data = userData['data'] ?? userData;
            _customerNameController.text = data['name'] ?? '';
            _customerEmailController.text = data['email'] ?? '';
            _customerPhoneController.text = data['phone'] ?? '';
            _deliveryAddressController.text = data['address'] ?? '';
          });
          print('Form fields filled from API data');
          return;
        } catch (e) {
          print('Error fetching user profile: $e');
          // Fall back to cached data
        }

        // Load cached user data from SharedPreferences
        final userName = prefs.getString('user_name') ?? '';
        final userEmail = prefs.getString('user_email') ?? '';
        final userPhone = prefs.getString('user_phone') ?? '';
        final userAddress = prefs.getString('user_address') ?? '';

        print('SharedPreferences data:');
        print('Name: $userName');
        print('Email: $userEmail');
        print('Phone: $userPhone');
        print('Address: $userAddress');

        // Pre-fill form fields
        setState(() {
          _customerNameController.text = userName;
          _customerEmailController.text = userEmail;
          _customerPhoneController.text = userPhone;
          _deliveryAddressController.text = userAddress;
        });
        print('Form fields filled from SharedPreferences');
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width > 600
          ? 16
          : 12), // Responsive padding
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            SizedBox(
                height: MediaQuery.of(context).size.width > 600
                    ? 20
                    : 16), // Responsive spacing
            _buildCompanyDetailsSection(),
            SizedBox(height: MediaQuery.of(context).size.width > 600 ? 20 : 16),
            _buildDeliverySection(),
            SizedBox(height: MediaQuery.of(context).size.width > 600 ? 20 : 16),
            _buildItemsSection(),
            SizedBox(height: MediaQuery.of(context).size.width > 600 ? 20 : 16),
            _buildNotesSection(),
            SizedBox(height: MediaQuery.of(context).size.width > 600 ? 20 : 16),
            _buildPaymentInfoSection(),
            SizedBox(height: MediaQuery.of(context).size.width > 600 ? 20 : 16),
            _buildSubmitButton(),
            const SizedBox(
                height: 20), // Extra bottom padding for better scrolling
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: AppTheme.primaryColor.withOpacity(0.1),
      child: Padding(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width > 600
            ? 16
            : 12), // Responsive padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  // Added Expanded to prevent overflow
                  child: Text(
                    'Bulk Order Benefits',
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width > 600
                          ? 18
                          : 16, // Responsive font size
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                    overflow: TextOverflow.ellipsis, // Handle overflow
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Make benefit text responsive
            ...const [
              '• Minimum 10 items for bulk pricing',
              '• Up to 20% discount on large orders',
              '• Flexible delivery scheduling',
              '• Dedicated customer support',
              '• Custom payment terms available',
            ].map((text) => Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    text,
                    style: TextStyle(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Customer Details',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width > 600
                    ? 18
                    : 16, // Responsive font size
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (_isUserLoggedIn == true)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Auto-filled',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        SizedBox(
            height: MediaQuery.of(context).size.width > 600
                ? 16
                : 12), // Responsive spacing
        TextFormField(
          controller: _customerNameController,
          decoration: const InputDecoration(
            labelText: 'Customer Name *',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(
                horizontal: 12, vertical: 16), // Added padding
          ),
          validator: (value) => value?.isEmpty == true ? 'Required' : null,
        ),
        SizedBox(height: MediaQuery.of(context).size.width > 600 ? 16 : 12),
        TextFormField(
          controller: _customerPhoneController,
          decoration: const InputDecoration(
            labelText: 'Customer Phone *',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          keyboardType: TextInputType.phone,
          validator: (value) => value?.isEmpty == true ? 'Required' : null,
        ),
        SizedBox(height: MediaQuery.of(context).size.width > 600 ? 16 : 12),
        TextFormField(
          controller: _customerEmailController,
          decoration: const InputDecoration(
            labelText: 'Customer Email *',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value?.isEmpty == true) return 'Required';
            if (!value!.contains('@')) return 'Invalid email';
            return null;
          },
        ),
        SizedBox(height: MediaQuery.of(context).size.width > 600 ? 16 : 12),
        TextFormField(
          controller: _deliveryAddressController,
          decoration: const InputDecoration(
            labelText: 'Delivery Address *',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          maxLines: 3,
          validator: (value) => value?.isEmpty == true ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildDeliverySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delivery Details',
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width > 600
                ? 18
                : 16, // Responsive font size
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(
            height: MediaQuery.of(context).size.width > 600
                ? 16
                : 12), // Responsive spacing
        DropdownButtonFormField<String>(
          value: _orderType,
          decoration: const InputDecoration(
            labelText: 'Order Type',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          items: const [
            DropdownMenuItem(value: 'birthday', child: Text('Birthday')),
            DropdownMenuItem(value: 'party', child: Text('Party')),
            DropdownMenuItem(value: 'corporate', child: Text('Corporate')),
            DropdownMenuItem(value: 'other', child: Text('Other')),
          ],
          onChanged: (value) => setState(() => _orderType = value!),
        ),
        SizedBox(height: MediaQuery.of(context).size.width > 600 ? 16 : 12),
        DropdownButtonFormField<String>(
          value: _paymentMethod,
          decoration: const InputDecoration(
            labelText: 'Payment Method',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          items: const [
            DropdownMenuItem(value: 'cash', child: Text('Cash on Delivery')),
            DropdownMenuItem(
                value: 'online', child: Text('Online Payment (PayFast)')),
          ],
          onChanged: (value) => setState(() => _paymentMethod = value!),
        ),
        SizedBox(height: MediaQuery.of(context).size.width > 600 ? 16 : 12),
        InkWell(
          onTap: () => _selectDeliveryDate(),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Delivery Date',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
            child: Text(
              '${_deliveryDate.day}/${_deliveryDate.month}/${_deliveryDate.year}',
            ),
          ),
        ),
        SizedBox(height: MediaQuery.of(context).size.width > 600 ? 16 : 12),
        InkWell(
          onTap: () => _selectDeliveryTime(),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Delivery Time',
              border: OutlineInputBorder(),
            ),
            child: Text(
              _deliveryTime?.format(context) ?? 'Select Time',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              // Added Expanded to prevent overflow
              child: Text(
                'Order Items',
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width > 600
                      ? 18
                      : 16, // Responsive font size
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis, // Handle overflow
              ),
            ),
            const SizedBox(width: 8), // Small space between title and button
            Flexible(
              // Changed to Flexible to allow shrinking
              child: ElevatedButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add, size: 18), // Smaller icon
                label: Text(
                  MediaQuery.of(context).size.width > 600
                      ? 'Add Item'
                      : 'Add', // Responsive text
                  style: const TextStyle(fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        MediaQuery.of(context).size.width > 600 ? 16 : 8,
                    vertical: 8,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(
            height: MediaQuery.of(context).size.width > 600
                ? 16
                : 12), // Responsive spacing
        if (_items.isEmpty)
          Container(
            padding: EdgeInsets.all(MediaQuery.of(context).size.width > 600
                ? 32
                : 20), // Responsive padding
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.add_shopping_cart,
                      size: MediaQuery.of(context).size.width > 600
                          ? 48
                          : 40, // Responsive icon size
                      color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'No items added yet',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Minimum 10 items required for bulk pricing',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          )
        else
          ..._items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width > 600 ? 16 : 12,
                  vertical: 8,
                ),
                title: Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  'Qty: ${item.quantity} × Rs. ${item.price.toStringAsFixed(0)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Rs. ${item.total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 32, // Fixed width for delete button
                      child: IconButton(
                        onPressed: () => _removeItem(index),
                        icon: const Icon(Icons.delete,
                            color: Colors.red, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        if (_items.isNotEmpty) ...[
          SizedBox(height: MediaQuery.of(context).size.width > 600 ? 16 : 12),
          _buildPricingSummary(),
        ],
      ],
    );
  }

  Widget _buildPricingSummary() {
    final totalAmount = _items.fold(0.0, (sum, item) => sum + item.total);
    final totalItems = _items.fold(0, (sum, item) => sum + item.quantity);

    double discountPercent = 0;
    if (totalItems >= 100) {
      discountPercent = 20;
    } else if (totalItems >= 50)
      discountPercent = 15;
    else if (totalItems >= 10) discountPercent = 10;

    final discountAmount = totalAmount * (discountPercent / 100);
    final finalAmount = totalAmount - discountAmount;

    return Card(
      color: AppTheme.primaryColor.withOpacity(0.05),
      child: Padding(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width > 600
            ? 16
            : 12), // Responsive padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pricing Summary',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width > 600
                    ? 16
                    : 14, // Responsive font size
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Total Items: $totalItems',
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (totalItems >= 10)
                  Flexible(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3), // Reduced padding
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Bulk Eligible!',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                else
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Need ${10 - totalItems} more for bulk pricing',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  flex: 1,
                  child: Text(
                    'Subtotal:',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Rs. ${totalAmount.toStringAsFixed(0)}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (discountPercent > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Discount ($discountPercent%):',
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '- Rs. ${discountAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  flex: 1,
                  child: Text(
                    'Final Amount:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Rs. ${finalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Notes',
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width > 600
                ? 18
                : 16, // Responsive font size
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(
            height: MediaQuery.of(context).size.width > 600
                ? 16
                : 12), // Responsive spacing
        TextFormField(
          controller: _specialInstructionsController,
          decoration: const InputDecoration(
            labelText: 'Special instructions or requirements',
            border: OutlineInputBorder(),
            hintText: 'e.g., Specific delivery time, packaging requirements...',
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildPaymentInfoSection() {
    // Calculate totals for display
    final totalAmount = _items.fold(0.0, (sum, item) => sum + item.total);
    final totalItems = _items.fold(0, (sum, item) => sum + item.quantity);

    double discountPercent = 0;
    if (totalItems >= 100) {
      discountPercent = 20;
    } else if (totalItems >= 50) {
      discountPercent = 15;
    } else if (totalItems >= 10) {
      discountPercent = 10;
    }

    final discountAmount = totalAmount * (discountPercent / 100);
    final finalAmount = totalAmount - discountAmount;

    return Card(
      color: _paymentMethod == 'online'
          ? Colors.blue.withOpacity(0.05)
          : Colors.grey.withOpacity(0.05),
      child: Padding(
        padding:
            EdgeInsets.all(MediaQuery.of(context).size.width > 600 ? 16 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _paymentMethod == 'online'
                      ? Icons.credit_card
                      : _paymentMethod == 'cash'
                          ? Icons.local_shipping
                          : Icons.account_balance,
                  color: _paymentMethod == 'online'
                      ? Colors.blue
                      : _paymentMethod == 'cash'
                          ? Colors.green
                          : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Payment Information',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width > 600 ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: _paymentMethod == 'online'
                        ? Colors.blue
                        : AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_paymentMethod == 'online') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Secure Online Payment',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('• Pay instantly with PayFast gateway'),
                    const Text('• Secure credit/debit card processing'),
                    const Text('• Instant payment confirmation'),
                    const Text('• Order processing begins immediately'),
                  ],
                ),
              ),
            ] else if (_paymentMethod == 'cash') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_shipping,
                            color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Cash on Delivery',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('• Pay when your order is delivered'),
                    const Text('• No advance payment required'),
                    const Text('• Order confirmed via phone call'),
                    const Text('• Flexible payment at delivery'),
                  ],
                ),
              ),
            ],
            // Show payment amount if items exist
            if (_items.isNotEmpty && totalItems >= 10) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Items:',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        Text('$totalItems items',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal:'),
                        Text('Rs. ${totalAmount.toStringAsFixed(0)}'),
                      ],
                    ),
                    if (discountPercent > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              'Discount (${discountPercent.toStringAsFixed(0)}%):'),
                          Text('- Rs. ${discountAmount.toStringAsFixed(0)}',
                              style: const TextStyle(color: Colors.green)),
                        ],
                      ),
                    ],
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            '${_paymentMethod == 'online' ? 'Amount to Pay:' : 'Total Amount:'}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Rs. ${finalAmount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _paymentMethod == 'online'
                                  ? Colors.blue
                                  : AppTheme.primaryColor,
                            )),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final totalItems = _items.fold(0, (sum, item) => sum + item.quantity);
    final canSubmit = _items.isNotEmpty && totalItems >= 10;

    return SizedBox(
      width: double.infinity,
      height: MediaQuery.of(context).size.width > 600
          ? 50
          : 48, // Responsive height
      child: ElevatedButton(
        onPressed: canSubmit ? _submitOrder : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: Text(
          canSubmit
              ? (_paymentMethod == 'online'
                  ? 'Proceed to Payment'
                  : 'Submit Bulk Order')
              : 'Add at least 10 items to proceed',
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width > 600
                ? 16
                : 14, // Responsive font size
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  void _selectDeliveryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deliveryDate,
      firstDate: DateTime.now()
          .add(const Duration(days: 5)), // Only allow dates 5 days after today
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _deliveryDate = date);
    }
  }

  void _selectDeliveryTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _deliveryTime ?? TimeOfDay.now(),
    );
    if (time != null) {
      setState(() => _deliveryTime = time);
    }
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (context) => AddItemDialog(
        onItemAdded: (item) {
          setState(() {
            _items.add(item);
          });
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  void _submitOrder() async {
    if (_formKey.currentState!.validate()) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        // Calculate final amount with discount
        final totalAmount = _items.fold(0.0, (sum, item) => sum + item.total);
        final totalItems = _items.fold(0, (sum, item) => sum + item.quantity);

        double discountPercent = 0;
        if (totalItems >= 100) {
          discountPercent = 20;
        } else if (totalItems >= 50) {
          discountPercent = 15;
        } else if (totalItems >= 10) {
          discountPercent = 10;
        }

        final discountAmount = totalAmount * (discountPercent / 100);
        final finalAmount = totalAmount - discountAmount;

        // Validate amounts
        if (totalAmount <= 0 || finalAmount <= 0) {
          Navigator.pop(context); // Close loading dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Invalid Amount'),
              content: const Text('Please ensure all items have valid prices.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return;
        }

        print('Total items: $totalItems');
        print('Total amount: $totalAmount');
        print('Final amount: $finalAmount');
        print('Discount percent: $discountPercent');

        // Get current user ID
        final AuthService authService = AuthService();
        final currentUser = await authService.getCurrentUser();
        print('Submit Order - Current user from AuthService: $currentUser');

        int userId = 1; // Default fallback

        if (currentUser != null && currentUser['id'] != null) {
          userId = currentUser['id'];
          print('Using AuthService user ID: $userId');
        } else {
          // Try alternative approach - get user ID directly from SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          final directUserId = prefs.getInt('user_id');
          final token = prefs.getString('authToken');
          final userName = prefs.getString('user_name');

          if (directUserId != null) {
            userId = directUserId;
            print('Using direct SharedPreferences user_id: $userId');
          } else if (token != null && token.isNotEmpty && userName != null) {
            // User is logged in but no user_id saved, use default and save it
            userId = 1; // Default for logged in users
            await prefs.setInt('user_id', userId);
            print(
                'User is logged in ($userName) but no user_id found, using and saving default ID: $userId');
          } else {
            print('No user ID found, using default: $userId');
          }
        }

        // Create bulk order object
        final bulkOrder = BulkOrder(
          id: 0, // Will be assigned by backend
          orderNumber: '', // Will be generated by backend
          customerName: _customerNameController.text,
          customerPhone: _customerPhoneController.text,
          customerEmail: _customerEmailController.text.isNotEmpty
              ? _customerEmailController.text
              : null,
          deliveryAddress: _deliveryAddressController.text,
          orderType: _orderType,
          paymentMethod: _paymentMethod, // Send 'online' or 'cash' directly
          paymentStatus: 'pending', // Default payment status
          deliveryDate: _deliveryDate,
          deliveryTime: _deliveryTime?.format(context),
          eventDetails: _eventDetailsController.text.isNotEmpty
              ? _eventDetailsController.text
              : null,
          totalAmount: finalAmount,
          advancePayment: 0.0, // Will be set later
          status: 'pending',
          userId: userId, // Use current user's ID
          specialInstructions: _specialInstructionsController.text.isNotEmpty
              ? _specialInstructionsController.text
              : null,
          items: _items,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Submit to backend
        final ApiService apiService = ApiService();
        final createdOrder = await apiService.createBulkOrder(bulkOrder);
        print(
            'Order successfully created with ID: ${createdOrder.id}'); // Debug log

        // Close loading dialog
        Navigator.pop(context);

        // Handle payment based on method
        if (_paymentMethod == 'online') {
          // Navigate to payment screen for online payment
          final paymentResult = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentScreen(
                amount: finalAmount,
                orderId: createdOrder.id.toString(),
                customerName: _customerNameController.text,
                customerEmail: _customerEmailController.text.isNotEmpty
                    ? _customerEmailController.text
                    : 'bulk@bakehub.com',
                customerMobile: _customerPhoneController.text,
                description: 'BakeHub Bulk Order #${createdOrder.id}',
              ),
            ),
          );

          if (paymentResult == true) {
            // Payment successful - show success message
            _showOrderSuccessDialog(createdOrder.id.toString(), true);
          } else {
            // Payment failed or cancelled - show appropriate message
            _showPaymentFailedDialog(createdOrder.id.toString());
            return;
          }
        } else {
          // Cash payment - show success immediately
          _showOrderSuccessDialog(createdOrder.id.toString(), false);
        }

        // Clear form first
        _clearForm();

        // Get reference to the main screen state
        final bulkOrderState =
            context.findAncestorStateOfType<_BulkOrderScreenState>();
        if (bulkOrderState != null) {
          // Add the created order to local state immediately for instant feedback
          bulkOrderState.setState(() {
            // Add to beginning of list so it appears at top
            bulkOrderState._bulkOrders.insert(0, createdOrder);
          });
          print('Added created order to local state for instant feedback');

          // Switch to Order History tab immediately
          bulkOrderState._tabController.animateTo(1);
          print('Switched to Order History tab'); // Debug log

          // Multiple refresh attempts with longer delays to ensure order appears from API
          await bulkOrderState._loadBulkOrders();
          print('First refresh completed'); // Debug log

          // Additional refreshes with increasing delays
          Future.delayed(const Duration(seconds: 1), () {
            if (bulkOrderState.mounted) {
              print('Second refresh after 1 second');
              bulkOrderState._loadBulkOrders();
            }
          });

          Future.delayed(const Duration(seconds: 3), () {
            if (bulkOrderState.mounted) {
              print('Third refresh after 3 seconds');
              bulkOrderState._loadBulkOrders();
            }
          });

          Future.delayed(const Duration(seconds: 5), () {
            if (bulkOrderState.mounted) {
              print('Fourth refresh after 5 seconds');
              bulkOrderState._loadBulkOrders();
            }
          });
        }

        // Show success dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Order Submitted!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your bulk order has been submitted successfully!',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order Summary:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('• Items: $totalItems'),
                      Text(
                          '• Total Amount: Rs. ${finalAmount.toStringAsFixed(0)}'),
                      if (discountPercent > 0)
                        Text(
                            '• Discount Applied: ${discountPercent.toStringAsFixed(0)}%'),
                      Text('• Status: Pending Approval'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'What happens next?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('1. Our team will review your order'),
                const Text('2. You\'ll receive a confirmation call'),
                const Text('3. We\'ll confirm delivery details'),
                const Text('4. Production will begin after approval'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  // Get reference to the main screen state and ensure we're on Order History tab
                  final bulkOrderState =
                      context.findAncestorStateOfType<_BulkOrderScreenState>();
                  if (bulkOrderState != null) {
                    bulkOrderState._tabController.animateTo(1);
                    // Refresh the orders list after a short delay to ensure tab is switched
                    Future.delayed(const Duration(milliseconds: 300), () {
                      bulkOrderState._loadBulkOrders(isManualRefresh: true);
                    });
                  }
                },
                child: const Text('View Orders'),
              ),
              TextButton(
                onPressed: () {
                  // Manual refresh without closing dialog
                  final bulkOrderState =
                      context.findAncestorStateOfType<_BulkOrderScreenState>();
                  if (bulkOrderState != null) {
                    bulkOrderState._tabController.animateTo(1);
                    bulkOrderState._loadBulkOrders(isManualRefresh: true);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Refreshing order history...'),
                        backgroundColor: AppTheme.primaryColor,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: const Text('Refresh Now'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  // Switch back to Create Order tab for new order
                  final bulkOrderState =
                      context.findAncestorStateOfType<_BulkOrderScreenState>();
                  if (bulkOrderState != null) {
                    bulkOrderState._tabController.animateTo(0);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Create New Order'),
              ),
            ],
          ),
        );
      } catch (e) {
        // Close loading dialog
        Navigator.pop(context);

        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.error,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Submission Failed'),
              ],
            ),
            content: Text(
              'Failed to submit bulk order: $e\n\nPlease check your internet connection and try again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _submitOrder(); // Retry submission
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _clearForm() {
    _customerNameController.clear();
    _customerPhoneController.clear();
    _customerEmailController.clear();
    _deliveryAddressController.clear();
    _eventDetailsController.clear();
    _specialInstructionsController.clear();

    setState(() {
      _orderType = 'birthday';
      _paymentMethod = 'cash';
      _deliveryDate = DateTime.now().add(const Duration(days: 7));
      _deliveryTime = null;
      _items.clear();
    });
    // Reload user data for next order
    _loadUserData();
  }

  void _showOrderSuccessDialog(String orderId, bool isPaidOnline) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isPaidOnline ? 'Payment Successful!' : 'Order Submitted!',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isPaidOnline
                      ? 'Your bulk order payment has been processed successfully!'
                      : 'Your bulk order has been submitted successfully!',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order #$orderId',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                          'Payment Status: ${isPaidOnline ? "Paid Online" : "Pending"}'),
                      const Text('Order Status: Processing'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You will receive a confirmation call from our team within 24 hours.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Switch to Order History tab
              final bulkOrderState =
                  context.findAncestorStateOfType<_BulkOrderScreenState>();
              if (bulkOrderState != null) {
                bulkOrderState._tabController.animateTo(1);
                Future.delayed(const Duration(milliseconds: 300), () {
                  bulkOrderState._loadBulkOrders(isManualRefresh: true);
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('View Orders'),
          ),
        ],
      ),
    );
  }

  void _showPaymentFailedDialog(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning,
                color: Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Payment Incomplete',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your bulk order has been created but payment was not completed.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order #$orderId',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Payment Status: Pending'),
                      const Text('Order Status: Awaiting Payment'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You can complete the payment later from your order history or contact us for alternative payment methods.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Switch to Order History tab
              final bulkOrderState =
                  context.findAncestorStateOfType<_BulkOrderScreenState>();
              if (bulkOrderState != null) {
                bulkOrderState._tabController.animateTo(1);
                Future.delayed(const Duration(milliseconds: 300), () {
                  bulkOrderState._loadBulkOrders(isManualRefresh: true);
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('View Orders'),
          ),
        ],
      ),
    );
  }

  String _getPaymentMethodDisplayName(String paymentMethod) {
    switch (paymentMethod) {
      case 'cash':
        return 'Cash on Delivery';
      case 'online':
        return 'Online Payment (PayFast)';
      case 'gcash': // Legacy support
        return 'Online Payment (PayFast)';
      case 'bank_transfer': // Legacy support
        return 'Bank Transfer';
      case 'cash_on_delivery': // Legacy support
        return 'Cash on Delivery';
      case 'online_payment': // Legacy support
        return 'Online Payment (PayFast)';
      default:
        return paymentMethod;
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    _deliveryAddressController.dispose();
    _eventDetailsController.dispose();
    _specialInstructionsController.dispose();
    super.dispose();
  }
}

class OrderDetailsSheet extends StatelessWidget {
  final BulkOrder order;
  final ScrollController scrollController;

  const OrderDetailsSheet({
    super.key,
    required this.order,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Order: ${order.orderNumber}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection('Contact Information', [
                    'Customer: ${order.customerName}',
                    'Phone: ${order.customerPhone}',
                    if (order.customerEmail != null)
                      'Email: ${order.customerEmail}',
                    'Address: ${order.deliveryAddress}',
                    'Status: ${order.status}',
                    'Order Type: ${order.orderType}',
                    'Payment Method: ${_getPaymentMethodDisplayName(order.paymentMethod)}',
                  ]),
                  _buildDetailSection('Delivery Details', [
                    'Delivery Date: ${order.deliveryDate.toString().split(' ')[0]}',
                    if (order.deliveryTime != null)
                      'Delivery Time: ${order.deliveryTime}',
                    if (order.eventDetails != null)
                      'Event Details: ${order.eventDetails}',
                  ]),
                  _buildDetailSection('Order Summary', [
                    'Items: ${order.items.length}',
                    ...order.items.map((item) =>
                        '  ${item.productName} x${item.quantity} @ Rs.${item.price}'),
                    'Total Amount: Rs.${order.totalAmount.toStringAsFixed(0)}',
                    'Advance Payment: Rs.${order.advancePayment.toStringAsFixed(0)}',
                    'Remaining: Rs.${(order.totalAmount - order.advancePayment).toStringAsFixed(0)}',
                    if (order.specialInstructions?.isNotEmpty == true)
                      'Notes: ${order.specialInstructions}',
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(item),
            )),
        const SizedBox(height: 16),
      ],
    );
  }

  String _getPaymentMethodDisplayName(String paymentMethod) {
    switch (paymentMethod) {
      case 'cash':
        return 'Cash on Delivery';
      case 'online':
        return 'Online Payment (PayFast)';
      case 'gcash': // Legacy support
        return 'Online Payment (PayFast)';
      case 'bank_transfer': // Legacy support
        return 'Bank Transfer';
      case 'cash_on_delivery': // Legacy support
        return 'Cash on Delivery';
      case 'online_payment': // Legacy support
        return 'Online Payment (PayFast)';
      default:
        return paymentMethod;
    }
  }
}

class AddItemDialog extends StatefulWidget {
  final Function(BulkOrderItem) onItemAdded;

  const AddItemDialog({super.key, required this.onItemAdded});

  @override
  _AddItemDialogState createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  final ApiService _apiService = ApiService();
  List<Product> _products = [];
  Product? _selectedProduct;
  int _quantity = 1;
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _apiService.getProducts();
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load products: $e')),
      );
    }
  }

  List<Product> get filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    return _products
        .where((product) =>
            product.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6B46C1), Color(0xFF3B82F6)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.add_shopping_cart,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Add Item to Bulk Order',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4C1D95),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 20),

            // Products List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredProducts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 80,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'No products available'
                                    : 'No products found for "$_searchQuery"',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            final isSelected =
                                _selectedProduct?.id == product.id;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF6B46C1).withOpacity(0.1)
                                    : Colors.white,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF6B46C1)
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedProduct = product;
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          color: Colors.grey.shade200,
                                        ),
                                        child: product.imageUrl.isNotEmpty
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.network(
                                                  product.imageUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return Icon(
                                                      Icons.cake,
                                                      color:
                                                          Colors.grey.shade400,
                                                      size: 24,
                                                    );
                                                  },
                                                ),
                                              )
                                            : Icon(
                                                Icons.cake,
                                                color: Colors.grey.shade400,
                                                size: 24,
                                              ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product.name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: isSelected
                                                    ? const Color(0xFF6B46C1)
                                                    : Colors.black,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (product
                                                .description.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                product.description,
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                            const SizedBox(height: 4),
                                            Text(
                                              'Rs. ${product.price.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF6B46C1),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle,
                                          color: Color(0xFF6B46C1),
                                          size: 24,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),

            if (_selectedProduct != null) ...[
              const Divider(),
              const SizedBox(height: 16),

              // Quantity Selector
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quantity:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF6B46C1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: _quantity > 1
                                  ? () => setState(() => _quantity--)
                                  : null,
                              icon: const Icon(Icons.remove),
                              color: const Color(0xFF6B46C1),
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Text(
                                _quantity.toString(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _quantity++),
                              icon: const Icon(Icons.add),
                              color: const Color(0xFF6B46C1),
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          'Total: Rs. ${(_selectedProduct!.price * _quantity).toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B46C1),
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Add Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    final item = BulkOrderItem(
                      id: 0,
                      bulkOrderId: 0,
                      productId: _selectedProduct!.id,
                      productName: _selectedProduct!.name,
                      quantity: _quantity,
                      price: _selectedProduct!.price,
                      discount: 0.0,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    widget.onItemAdded(item);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B46C1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Add to Order',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
