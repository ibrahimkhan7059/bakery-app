import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'payment_screen.dart';
import '../services/api_service.dart';
import 'auth/signin_screen.dart';
import 'home_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final double totalAmount;

  const CheckoutScreen({
    Key? key,
    required this.cartItems,
    required this.totalAmount,
  }) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isProcessingOrder = false;
  String _selectedDeliveryType = 'home_delivery';
  double _deliveryCharges = 50.0;
  String _selectedPaymentMode = '';
  bool _showPaymentOptions = false;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  bool? _isUserLoggedIn;

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');

      print('Loading user data...');
      print('Auth token exists: ${token != null}');

      setState(() {
        _isUserLoggedIn = token != null;
      });

      if (token != null) {
        // User is logged in, try to fetch latest profile data
        try {
          print('Fetching user profile from API...');
          final userData = await _apiService.getUserProfile();
          print('API Response: $userData');

          setState(() {
            // API response structure: { success: true, data: { user fields } }
            final data = userData['data'] ?? userData;
            _nameController.text = data['name'] ?? '';
            _emailController.text = data['email'] ?? '';
            _phoneController.text = data['phone'] ?? '';
            _addressController.text = data['address'] ?? '';
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
          _nameController.text = userName;
          _emailController.text = userEmail;
          _phoneController.text = userPhone;
          _addressController.text = userAddress;
        });
        print('Form fields filled from SharedPreferences');
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _finalAmount {
    double total = widget.totalAmount;
    if (_selectedDeliveryType == 'home_delivery') {
      total += _deliveryCharges;
    }
    return total;
  }

  Widget _buildOrderSummary() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 12),
            ...widget.cartItems
                .map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item['quantity']}x ${item['name']}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Text(
                            'Rs. ${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ))
                .toList(),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal:'),
                Text('Rs. ${widget.totalAmount.toStringAsFixed(2)}'),
              ],
            ),
            if (_selectedDeliveryType == 'home_delivery') ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Delivery Charges:'),
                  Text('Rs. ${_deliveryCharges.toStringAsFixed(2)}'),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Rs. ${_finalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryOptions() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 12),
            RadioListTile<String>(
              title: const Text('Home Delivery'),
              subtitle: Text(
                  'Delivery charges: Rs. ${_deliveryCharges.toStringAsFixed(2)}'),
              value: 'home_delivery',
              groupValue: _selectedDeliveryType,
              onChanged: (value) {
                setState(() {
                  _selectedDeliveryType = value!;
                });
              },
            ),
            RadioListTile<String>(
              title: const Text('Self Pickup'),
              subtitle: const Text('Free - Pickup from our bakery'),
              value: 'self_pickup',
              groupValue: _selectedDeliveryType,
              onChanged: (value) {
                setState(() {
                  _selectedDeliveryType = value!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(
              Icons.account_circle,
              size: 60,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            const Text(
              'Login Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please login to continue with checkout and auto-fill your information.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _isUserLoggedIn = false;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange),
                    ),
                    child: const Text(
                      'Continue as Guest',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignInScreen(),
                        ),
                      );
                      if (result == true) {
                        // User logged in successfully, reload data
                        await _loadUserData();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Login'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedPaymentDisplay() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _selectedPaymentMode == 'cash_on_delivery'
                  ? Icons.local_shipping
                  : Icons.credit_card,
              color: Colors.orange,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selected Payment Method',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedPaymentMode == 'cash_on_delivery'
                        ? 'Cash on Delivery'
                        : 'Online Payment',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                _showPaymentModeBottomSheet();
              },
              child: const Text(
                'Change',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerForm() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Customer Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const Spacer(),
                  if (_isUserLoggedIn == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Logged In',
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                  hintText: '03001234567',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (value.length < 11) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),
              if (_selectedDeliveryType == 'home_delivery') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Delivery Address *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                    hintText: 'House#, Street, Area',
                  ),
                  validator: (value) {
                    if (_selectedDeliveryType == 'home_delivery' &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Please enter delivery address';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Special Instructions (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                  hintText: 'Any special requirements or notes...',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getButtonText() {
    if (!_showPaymentOptions) {
      return 'Select Payment Mode';
    }

    if (_selectedPaymentMode.isEmpty) {
      return 'Select Payment Mode';
    }

    if (_selectedPaymentMode == 'cash_on_delivery') {
      return 'Place Order - Rs. ${_finalAmount.toStringAsFixed(2)}';
    }

    return 'Pay Now - Rs. ${_finalAmount.toStringAsFixed(2)}';
  }

  void _handlePaymentAction() {
    if (!_showPaymentOptions) {
      // First click - show payment options with animation
      if (!_formKey.currentState!.validate()) {
        return;
      }
      _showPaymentModeBottomSheet();
      return;
    }

    if (_selectedPaymentMode.isEmpty) {
      _showErrorDialog('Please select a payment mode');
      return;
    }

    // Proceed based on selected payment mode
    if (_selectedPaymentMode == 'cash_on_delivery') {
      _processCashOnDeliveryOrder();
    } else {
      _proceedToOnlinePayment();
    }
  }

  void _showPaymentModeBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Payment Mode',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 20),
              // Cash on Delivery Option
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedPaymentMode == 'cash_on_delivery'
                        ? Colors.orange
                        : Colors.grey[300]!,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: RadioListTile<String>(
                  title: const Text(
                    'Cash on Delivery',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text('Pay when your order arrives'),
                  secondary: const Icon(
                    Icons.local_shipping,
                    color: Colors.orange,
                  ),
                  value: 'cash_on_delivery',
                  groupValue: _selectedPaymentMode,
                  onChanged: (value) {
                    setState(() {
                      _selectedPaymentMode = value!;
                    });
                    Navigator.pop(context);
                    setState(() {
                      _showPaymentOptions = true;
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              // Online Payment Option
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedPaymentMode == 'online_payment'
                        ? Colors.orange
                        : Colors.grey[300]!,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: RadioListTile<String>(
                  title: const Text(
                    'Online Payment',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text('Pay now using PayFast gateway'),
                  secondary: const Icon(
                    Icons.credit_card,
                    color: Colors.orange,
                  ),
                  value: 'online_payment',
                  groupValue: _selectedPaymentMode,
                  onChanged: (value) {
                    setState(() {
                      _selectedPaymentMode = value!;
                    });
                    Navigator.pop(context);
                    setState(() {
                      _showPaymentOptions = true;
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),
              // Cancel button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processCashOnDeliveryOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isProcessingOrder = true;
    });

    try {
      // Create order in backend for cash on delivery
      final orderData = {
        'customer_name': _nameController.text.trim(),
        'customer_email': _emailController.text.trim(),
        'customer_phone': _phoneController.text.trim(),
        'delivery_type': _selectedDeliveryType,
        'delivery_address': _selectedDeliveryType == 'home_delivery'
            ? _addressController.text.trim()
            : null,
        'special_notes': _notesController.text.trim(),
        'items': widget.cartItems,
        'subtotal': widget.totalAmount,
        'delivery_charges':
            _selectedDeliveryType == 'home_delivery' ? _deliveryCharges : 0,
        'total_amount': _finalAmount,
        'payment_method': 'cash_on_delivery',
        'payment_status': 'pending',
      };

      final orderResponse = await _apiService.createOrder(orderData);

      if (orderResponse['success'] == true) {
        final orderId = orderResponse['order_id'].toString();
        _showOrderSuccessDialog(orderId);
      } else {
        _showErrorDialog(orderResponse['message'] ?? 'Failed to create order');
      }
    } catch (e) {
      _showErrorDialog('Error creating order: $e');
    } finally {
      setState(() {
        _isProcessingOrder = false;
      });
    }
  }

  Future<void> _proceedToOnlinePayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isProcessingOrder = true;
    });

    try {
      // Create order in backend first
      final orderData = {
        'customer_name': _nameController.text.trim(),
        'customer_email': _emailController.text.trim(),
        'customer_phone': _phoneController.text.trim(),
        'delivery_type': _selectedDeliveryType,
        'delivery_address': _selectedDeliveryType == 'home_delivery'
            ? _addressController.text.trim()
            : null,
        'special_notes': _notesController.text.trim(),
        'items': widget.cartItems,
        'subtotal': widget.totalAmount,
        'delivery_charges':
            _selectedDeliveryType == 'home_delivery' ? _deliveryCharges : 0,
        'total_amount': _finalAmount,
        'payment_method': 'online_payment',
        'payment_status': 'pending',
      };

      final orderResponse = await _apiService.createOrder(orderData);

      if (orderResponse['success'] == true) {
        final orderId = orderResponse['order_id'].toString();

        // Navigate to payment screen for online payment
        final paymentResult = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentScreen(
              amount: _finalAmount,
              orderId: orderId,
              customerName: _nameController.text.trim(),
              customerEmail: _emailController.text.trim(),
              customerMobile: _phoneController.text.trim(),
              description: 'BakeHub Order #$orderId',
            ),
          ),
        );

        if (paymentResult == true) {
          _showOrderSuccessDialog(orderId);
        }
      } else {
        _showErrorDialog(orderResponse['message'] ?? 'Failed to create order');
      }
    } catch (e) {
      _showErrorDialog('Error creating order: $e');
    } finally {
      setState(() {
        _isProcessingOrder = false;
      });
    }
  }

  Future<void> _clearCartDirectly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cart_items');
      print('Cart cleared directly from SharedPreferences');
    } catch (e) {
      print('Error clearing cart directly: $e');
    }
  }

  void _showOrderSuccessDialog(String orderId) {
    final isCashOnDelivery = _selectedPaymentMode == 'cash_on_delivery';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Order Placed Successfully!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text('Your order #$orderId has been placed successfully!'),
            const SizedBox(height: 8),
            if (isCashOnDelivery) ...[
              const Text(
                'Payment Method: Cash on Delivery',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                'Total Amount: Rs. ${_finalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange),
              ),
              const SizedBox(height: 8),
            ],
            const Text(
              'You will receive a confirmation email shortly.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              print('Order success dialog - Continue Shopping clicked');

              // Clear cart directly as backup
              await _clearCartDirectly();

              Navigator.of(context).pop(); // Close dialog
              print('Navigating to home screen');

              // Navigate to home screen and clear all previous routes
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (Route<dynamic> route) => false,
              );
            },
            child: const Text('Continue Shopping'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildOrderSummary(),
            _buildDeliveryOptions(),
            if (_isUserLoggedIn == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: Colors.orange),
                ),
              )
            else if (_isUserLoggedIn == true)
              Column(
                children: [
                  _buildCustomerForm(),
                  if (_showPaymentOptions) _buildSelectedPaymentDisplay(),
                ],
              )
            else
              Column(
                children: [
                  _buildLoginPrompt(),
                  _buildCustomerForm(),
                  if (_showPaymentOptions) _buildSelectedPaymentDisplay(),
                ],
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isProcessingOrder ? null : _handlePaymentAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isProcessingOrder
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Processing Order...'),
                      ],
                    )
                  : Text(
                      _getButtonText(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
