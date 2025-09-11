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

  Future<void> _loadBulkOrders() async {
    try {
      // Get all bulk orders from API
      final allOrders = await _apiService.getBulkOrders();
      print('Total orders fetched: ${allOrders.length}'); // Debug log

      // Debug: Print each order's details
      for (int i = 0; i < allOrders.length; i++) {
        final order = allOrders[i];
        print(
            'Order $i: ID=${order.id}, CustomerName=${order.customerName}, UserId=${order.userId}');
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

      if (currentUser != null && currentUser['id'] != null) {
        // Filter orders to show only current user's orders
        final currentUserId = currentUser['id'];
        userOrders =
            allOrders.where((order) => order.userId == currentUserId).toList();
        print(
            'Current user ID: $currentUserId, User orders: ${userOrders.length}'); // Debug log
      } else {
        // Try alternative approach - get user ID directly from SharedPreferences
        final directUserId = prefs.getInt('user_id');
        final token = prefs.getString('authToken');
        final userName = prefs.getString('user_name');

        if (directUserId != null) {
          // For now, also filter by customer name as a fallback since user_id might not be properly set in backend
          final userName = prefs.getString('user_name') ?? '';
          userOrders = allOrders
              .where((order) =>
                  order.userId == directUserId &&
                  (userName.isEmpty ||
                      order.customerName
                          .toLowerCase()
                          .contains(userName.toLowerCase())))
              .toList();
          print(
              'Using direct user_id: $directUserId with name filter: $userName, User orders: ${userOrders.length}');
        } else if (token != null && token.isNotEmpty && userName != null) {
          // User is logged in but no user_id saved, use default and save it
          final defaultUserId = 1; // Default for logged in users
          // Also filter by customer name as a fallback since user_id might not be properly set in backend
          userOrders = allOrders
              .where((order) =>
                  order.userId == defaultUserId &&
                  order.customerName
                      .toLowerCase()
                      .contains(userName.toLowerCase()))
              .toList();
          print(
              'User is logged in ($userName) but no user_id found, using default ID $defaultUserId with name filter, showing ${userOrders.length} orders');

          // Save the default user ID for future use
          await prefs.setInt('user_id', defaultUserId);
        } else {
          userOrders = [];
          print('No user logged in, showing empty list');
        }
      }

      setState(() {
        _bulkOrders = userOrders;
        _isLoading = false;
      });
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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_shopping_cart, size: 20),
                SizedBox(width: 8),
                Text('Create Order'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 20),
                SizedBox(width: 8),
                Text('Order History'),
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
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 24),
            _buildQuickStatsCard(),
            const SizedBox(height: 24),
            _buildCreateOrderForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(24),
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
          const SizedBox(width: 20),
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
      padding: const EdgeInsets.all(24),
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
              const SizedBox(width: 12),
              const Text(
                'Create New Bulk Order',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const CreateBulkOrderForm(),
        ],
      ),
    );
  }

  Widget _buildOrderHistoryTab() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 20),
            const Text(
              'Loading your orders...',
              style: TextStyle(
                color: darkPurple,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_bulkOrders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
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
                size: 80,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No bulk orders found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: darkPurple,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your bulk orders will appear here once you create them',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _loadBulkOrders(); // Refresh orders
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
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: primaryPurple,
      onRefresh: _loadBulkOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
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
      margin: const EdgeInsets.only(bottom: 16),
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
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
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.customerName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: darkPurple,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Order #${order.id}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: lightPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
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
                        value: 'Rs. ${order.totalAmount.toStringAsFixed(0)}',
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
                ),
              ),
              if (order.specialInstructions != null &&
                  order.specialInstructions!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
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
                      Icon(Icons.note, color: Colors.blue.shade600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.specialInstructions!,
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Action buttons
              const SizedBox(height: 16),
              Row(
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
            'API URL: http://192.168.100.81:8000/api/v1/bulk-orders/${order.id}');

        // Test connection first
        final testResponse = await http.get(
          Uri.parse('http://192.168.100.81:8000/api/v1/bulk-orders'),
          headers: {'Content-Type': 'application/json'},
        );
        print('Test connection status: ${testResponse.statusCode}');

        final response = await http.delete(
          Uri.parse(
              'http://192.168.100.81:8000/api/v1/bulk-orders/${order.id}'),
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
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(
          label,
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
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 20),
            _buildCompanyDetailsSection(),
            const SizedBox(height: 20),
            _buildDeliverySection(),
            const SizedBox(height: 20),
            _buildItemsSection(),
            const SizedBox(height: 20),
            _buildNotesSection(),
            const SizedBox(height: 20),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: AppTheme.primaryColor.withOpacity(0.1),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text(
                  'Bulk Order Benefits',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text('• Minimum 10 items for bulk pricing'),
            Text('• Up to 20% discount on large orders'),
            Text('• Flexible delivery scheduling'),
            Text('• Dedicated customer support'),
            Text('• Custom payment terms available'),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Company Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _customerNameController,
          decoration: const InputDecoration(
            labelText: 'Customer Name *',
            border: OutlineInputBorder(),
          ),
          validator: (value) => value?.isEmpty == true ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _customerPhoneController,
          decoration: const InputDecoration(
            labelText: 'Customer Phone *',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
          validator: (value) => value?.isEmpty == true ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _customerEmailController,
          decoration: const InputDecoration(
            labelText: 'Customer Email *',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value?.isEmpty == true) return 'Required';
            if (!value!.contains('@')) return 'Invalid email';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _deliveryAddressController,
          decoration: const InputDecoration(
            labelText: 'Delivery Address *',
            border: OutlineInputBorder(),
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
        const Text(
          'Delivery Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _orderType,
          decoration: const InputDecoration(
            labelText: 'Order Type',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'birthday', child: Text('Birthday')),
            DropdownMenuItem(value: 'party', child: Text('Party')),
            DropdownMenuItem(value: 'corporate', child: Text('Corporate')),
            DropdownMenuItem(value: 'other', child: Text('Other')),
          ],
          onChanged: (value) => setState(() => _orderType = value!),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _paymentMethod,
          decoration: const InputDecoration(
            labelText: 'Payment Method',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'cash', child: Text('Cash')),
            DropdownMenuItem(value: 'online', child: Text('Online')),
            DropdownMenuItem(value: 'credit', child: Text('Credit')),
          ],
          onChanged: (value) => setState(() => _paymentMethod = value!),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _selectDeliveryDate(),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Delivery Date',
              border: OutlineInputBorder(),
            ),
            child: Text(
              '${_deliveryDate.day}/${_deliveryDate.month}/${_deliveryDate.year}',
            ),
          ),
        ),
        const SizedBox(height: 16),
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
            const Text(
              'Order Items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_items.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.add_shopping_cart,
                      size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'No items added yet',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const Text('Minimum 10 items required for bulk pricing'),
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
                title: Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Qty: ${item.quantity} × Rs. ${item.price.toStringAsFixed(0)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Rs. ${item.total.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _removeItem(index),
                      icon: const Icon(Icons.delete, color: Colors.red),
                    ),
                  ],
                ),
              ),
            );
          }),
        if (_items.isNotEmpty) ...[
          const SizedBox(height: 16),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pricing Summary',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  flex: 2,
                  child: Text('Total Items: $totalItems'),
                ),
                if (totalItems >= 10)
                  Flexible(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Bulk Eligible!',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  Flexible(
                    flex: 1,
                    child: Text(
                      'Need ${10 - totalItems} more for bulk pricing',
                      style: TextStyle(color: Colors.orange.shade700),
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
                const Flexible(
                  flex: 1,
                  child: Text('Subtotal:'),
                ),
                Flexible(
                  flex: 1,
                  child: Text(
                    'Rs. ${totalAmount.toStringAsFixed(0)}',
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            if (discountPercent > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    flex: 1,
                    child: Text('Discount ($discountPercent%):'),
                  ),
                  Flexible(
                    flex: 1,
                    child: Text(
                      '- Rs. ${discountAmount.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.green),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ],
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  flex: 1,
                  child: Text(
                    'Final Amount:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Flexible(
                  flex: 1,
                  child: Text(
                    'Rs. ${finalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                    textAlign: TextAlign.end,
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
        const Text(
          'Additional Notes',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _specialInstructionsController,
          decoration: const InputDecoration(
            labelText: 'Special instructions or requirements',
            border: OutlineInputBorder(),
            hintText: 'e.g., Specific delivery time, packaging requirements...',
          ),
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final totalItems = _items.fold(0, (sum, item) => sum + item.quantity);
    final canSubmit = _items.isNotEmpty && totalItems >= 10;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: canSubmit ? _submitOrder : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          canSubmit ? 'Submit Bulk Order' : 'Add at least 10 items to proceed',
          style: const TextStyle(fontSize: 16),
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
      firstDate: DateTime.now().add(const Duration(days: 1)),
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
          paymentMethod: _paymentMethod,
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
        await apiService.createBulkOrder(bulkOrder);

        // Close loading dialog
        Navigator.pop(context);

        // Refresh the orders list immediately to show the new order
        final bulkOrderState =
            context.findAncestorStateOfType<_BulkOrderScreenState>();
        if (bulkOrderState != null) {
          await bulkOrderState._loadBulkOrders();
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
                  // Clear form and switch to order history tab
                  _clearForm();
                  // Switch to Order History tab to see the new order
                  if (mounted) {
                    final bulkOrderState = context
                        .findAncestorStateOfType<_BulkOrderScreenState>();
                    if (bulkOrderState != null) {
                      bulkOrderState._tabController.animateTo(1);
                      // Refresh the orders list after a short delay
                      Future.delayed(const Duration(milliseconds: 500), () {
                        bulkOrderState._loadBulkOrders();
                      });
                    }
                  }
                },
                child: const Text('View Orders'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  _clearForm(); // Clear form for new order
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
                    'Payment Method: ${order.paymentMethod}',
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
