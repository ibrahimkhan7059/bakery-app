import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/global_app_bar.dart';
import 'order_detail_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Check if user is logged in using AuthService
      final AuthService authService = AuthService();
      final isLoggedIn = await authService.isLoggedIn();

      print('AuthService isLoggedIn: $isLoggedIn');

      if (!isLoggedIn) {
        // Redirect to login/home screen if not authenticated
        print('User not logged in, redirecting to home screen...');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/');
        }
        return;
      }

      // Get current user info to verify filtering
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getInt('user_id');
      final currentUserName = prefs.getString('user_name');
      final currentUserEmail = prefs.getString('user_email');
      final authToken =
          prefs.getString('authToken') ?? prefs.getString('auth_token');

      print('=== CURRENT USER DEBUG INFO ===');
      print('User ID: $currentUserId');
      print('User Name: $currentUserName');
      print('User Email: $currentUserEmail');
      print('Has Auth Token: ${authToken != null}');
      print('All prefs keys: ${prefs.getKeys()}');
      print('==============================');

      // Test authentication first
      final apiService = ApiService();
      final isAuthValid = await apiService.testAuthentication();
      print('Authentication test result: $isAuthValid');

      if (!isAuthValid) {
        throw Exception('Authentication failed. Please login again.');
      }

      print('Calling ApiService.getMySimpleOrders()...');
      final data = await apiService.getMySimpleOrders();
      print('Orders fetched successfully: ${data.length} orders');

      // Log current user info for debugging
      print('Current user info: ID=$currentUserId, Name=$currentUserName');
      print('Raw orders data length: ${data.length}');

      // Since backend already filters by authenticated user, trust the API response
      // Only do minimal safety filtering if needed
      final filteredOrders = <Map<String, dynamic>>[];

      for (int i = 0; i < data.length; i++) {
        try {
          final order = data[i];
          print(
              'Processing order $i: ID=${order['id']}, Customer=${order['customer_name']}, Email=${order['customer_email']}');

          // Trust backend filtering completely - it already filters by authenticated user
          // Backend handles both user_id and email matching
          print('Trusting backend filtering - including order ${order['id']}');

          filteredOrders.add(order);
          print('Added order ${order['id']} to filtered list');
        } catch (e) {
          print('Error processing order $i: $e');
          // On error, include the order to be safe
          filteredOrders.add(data[i]);
          continue;
        }
      }

      print('Final filtered orders: ${filteredOrders.length}');

      setState(() {
        _orders = filteredOrders;
        _loading = false;
      });
    } catch (e) {
      print('Orders fetch error: $e');

      // Check if it's an authentication error
      if (e.toString().contains('Session expired') ||
          e.toString().contains('Please login again') ||
          e.toString().contains('401') ||
          e.toString().contains('Unauthorized')) {
        print('Authentication error detected, redirecting to home...');
        if (mounted) {
          // Show a snackbar message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expired. Please login again.'),
              backgroundColor: Colors.red,
            ),
          );
          // Redirect to home/login screen
          Navigator.pushReplacementNamed(context, '/');
        }
        return;
      }

      // Check for parsing errors
      if (e.toString().contains('JSON') || e.toString().contains('parsing')) {
        setState(() {
          _error = 'Data format error. Please try again or contact support.';
          _loading = false;
        });
        return;
      }

      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlobalAppBar(
          title: 'My Orders', showBackButton: true, actions: []),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error: $_error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _fetchOrders,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/');
                            },
                            icon: const Icon(Icons.login),
                            label: const Text('Login'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : _orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No orders found',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your orders will appear here once you place them',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Try placing an order from the menu!',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _fetchOrders,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchOrders,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        itemBuilder: (context, idx) {
                          final order = _orders[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        OrderDetailScreen(order: order),
                                  ),
                                );
                              },
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.receipt_long,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              title: Text(
                                'Order #${order['id'] ?? 'N/A'}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (order['items'] != null &&
                                        order['items'] is List)
                                      Text(
                                          'Items: ${(order['items'] as List).length}')
                                    else
                                      Text(
                                          'Product: ${order['product_name'] ?? 'N/A'}'),
                                    if (order['quantity'] != null)
                                      Text('Quantity: ${order['quantity']}'),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Date: ${order['created_at']?.toString().substring(0, 10) ?? 'N/A'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(
                                                order['status'] ?? 'pending')
                                            .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        order['status']
                                                ?.toString()
                                                .toUpperCase() ??
                                            'PENDING',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _getStatusColor(
                                              order['status'] ?? 'pending'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: Text(
                                'PKR ${order['total_amount'] ?? '-'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildOrderItemsPreview(Map<String, dynamic> order) {
    final items = order['items'];

    if (items == null) {
      // Fallback to single product display
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Product: ${order['product_name'] ?? 'N/A'}'),
          if (order['cake_name'] != null) Text('Cake: ${order['cake_name']}'),
        ],
      );
    }

    if (items is List && items.isNotEmpty) {
      // Multiple items - show first item and count
      final firstItem = items[0];
      final itemName = firstItem['product_name'] ??
          firstItem['cake_name'] ??
          firstItem['name'] ??
          'Unknown Item';

      if (items.length == 1) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Item: $itemName'),
            if (firstItem['quantity'] != null)
              Text('Qty: ${firstItem['quantity']}'),
          ],
        );
      } else {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$itemName'),
            Text('+ ${items.length - 1} more items',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                )),
          ],
        );
      }
    }

    // Fallback
    return Text('Items: ${items.toString()}');
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'processing':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
