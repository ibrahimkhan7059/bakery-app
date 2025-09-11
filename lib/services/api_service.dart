import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/category.dart';
import '../models/product.dart';
import '../models/bulk_order.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io'; // Added for File

class ApiService {
  // For Android Emulator, use 10.0.2.2 to access your host machine's localhost
  // For physical device or iOS simulator, use your computer's local network IP (e.g., http://192.168.1.X:8000)
  final String _baseUrl =
      'http://192.168.100.81:8000/api'; // Updated IP address

  // Common headers
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Get authorization headers with token
  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    final headers = Map<String, String>.from(_headers);
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Fetch Categories
  Future<List<Category>> getCategories() async {
    try {
      print('Fetching categories from: $_baseUrl/v1/categories'); // Debug log
      final response = await http.get(
        Uri.parse('$_baseUrl/v1/categories'),
        headers: _headers, // Use basic headers without auth
      );

      print('Categories response status: ${response.statusCode}'); // Debug log
      print('Categories response body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final List<dynamic> categoriesJson = jsonDecode(response.body);
        return categoriesJson.map((json) => Category.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to load categories: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Categories fetch error: $e'); // Detailed error log
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw Exception(
            'Could not connect to the server. Please check if the server is running and your internet connection.');
      }
      throw Exception('Failed to fetch categories. ${e.toString()}');
    }
  }

  // Fetch All Products
  Future<List<Product>> getProducts() async {
    try {
      print('Fetching products from: $_baseUrl/v1/products'); // Debug log
      final response = await http.get(
        Uri.parse('$_baseUrl/v1/products'),
        headers: _headers, // Use basic headers without auth
      );

      print('Products response status: ${response.statusCode}'); // Debug log
      print('Products response body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final List<dynamic> productsJson = jsonDecode(response.body);
        return productsJson.map((json) => Product.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to load products: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Products fetch error: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw Exception(
            'Could not connect to the server. Please check if the server is running and your internet connection.');
      }
      throw Exception('Failed to fetch products. ${e.toString()}');
    }
  }

  // Fetch Products by Category
  Future<List<Product>> getProductsByCategory(int categoryId) async {
    try {
      print('Fetching products for category: $categoryId'); // Debug log
      final response = await http.get(
        Uri.parse('$_baseUrl/v1/products/category/$categoryId'),
        headers: _headers, // Use basic headers without auth
      );

      print(
          'Category products response status: ${response.statusCode}'); // Debug log
      print('Category products response body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final List<dynamic> productsJson = jsonDecode(response.body);
        return productsJson.map((json) => Product.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to load category products: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Category products fetch error: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw Exception(
            'Could not connect to the server. Please check if the server is running and your internet connection.');
      }
      throw Exception('Failed to fetch category products. ${e.toString()}');
    }
  }

  // Fetch Single Product with Details (including allergens and alternative product)
  Future<Product> getProductDetails(int productId) async {
    try {
      print('Fetching product details for ID: $productId'); // Debug log
      final response = await http.get(
        Uri.parse('$_baseUrl/v1/products/$productId'),
        headers: _headers, // Use basic headers without auth
      );

      print(
          'Product details response status: ${response.statusCode}'); // Debug log
      print('Product details response body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final Map<String, dynamic> productJson = jsonDecode(response.body);
        return Product.fromJson(productJson);
      } else {
        throw Exception(
            'Failed to load product details: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Product details fetch error: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw Exception(
            'Could not connect to the server. Please check if the server is running and your internet connection.');
      }
      throw Exception('Failed to fetch product details. ${e.toString()}');
    }
  }

  // Register User
  Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String email,
    required String address,
    required String password, // Added password
  }) async {
    try {
      // Format phone number: if starts with 0, replace with +92
      String formattedPhone = phone;
      if (phone.startsWith('0')) {
        formattedPhone = '+92${phone.substring(1)}';
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/register'), // Corrected endpoint
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'phone': formattedPhone, // Send formatted phone
          'email': email,
          'address': address,
          'password': password,
          'password_confirmation':
              password, // Assuming password_confirmation is same as password
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      // It's good practice to print the error or log it for debugging
      print('Registration Error: $e');
      print(
          'Response body: ${e is http.Response ? e.body : 'N/A'}'); // If possible, log response body for server errors
      throw Exception(
          'Failed to register. Please check your connection and input.');
    }
  }

  // Login User
  Future<Map<String, dynamic>> login({
    required String email, // Changed from phone to email
    required String password, // Added password
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'), // Corrected endpoint
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('Login Error: $e');
      print('Response body: ${e is http.Response ? e.body : 'N/A'}');
      throw Exception(
          'Failed to login. Please check your credentials and connection.');
    }
  }

  // verifyOtp method is removed as OTP flow is no longer used.

  // Search Products
  Future<List<Product>> searchProducts({
    required String query,
    String? category,
    double? minPrice,
    double? maxPrice,
    String? sortBy,
  }) async {
    try {
      final queryParameters = {
        'query': query,
        if (category != null && category != 'All') 'category': category,
        if (minPrice != null) 'min_price': minPrice.toString(),
        if (maxPrice != null) 'max_price': maxPrice.toString(),
        if (sortBy != null) 'sort_by': sortBy,
      };

      final uri = Uri.parse('$_baseUrl/v1/products/search').replace(
        queryParameters: queryParameters,
      );

      print('Search URL: $uri'); // Debug log

      final response = await http.get(
        uri,
        headers: _headers, // Use basic headers without auth
      );

      print('Search response status: ${response.statusCode}'); // Debug log
      print('Search response body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('Found ${data.length} products'); // Debug log
        return data.map((json) => Product.fromJson(json)).toList();
      }
      throw Exception(
          'Failed to search products - Status: ${response.statusCode} - ${response.body}');
    } catch (e) {
      print('Search error: $e'); // Debug log
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw Exception(
            'Could not connect to the server. Please check if the server is running and your internet connection.');
      }
      throw Exception('Failed to search products: ${e.toString()}');
    }
  }

  // Bulk Orders
  Future<List<BulkOrder>> getBulkOrders() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/v1/bulk-orders'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => BulkOrder.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Please login to view bulk orders');
      }
      throw Exception(
          'Failed to fetch bulk orders: ${response.statusCode} - ${response.body}');
    } catch (e) {
      print('Bulk orders fetch error: $e'); // Debug log
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw Exception(
            'Could not connect to the server. Please check if the server is running and your internet connection.');
      }
      throw Exception(e.toString());
    }
  }

  Future<BulkOrder> createBulkOrder(BulkOrder order) async {
    try {
      final orderJson = order.toCreateJson();
      // Use basic headers instead of auth headers for now
      final headers = Map<String, String>.from(_headers);

      print('=== BULK ORDER DEBUG INFO ===');
      print('URL: $_baseUrl/v1/bulk-orders');
      print('Headers: $headers');
      print('Order JSON: ${jsonEncode(orderJson)}');
      print('Total Amount in JSON: ${orderJson['total_amount']}');
      print('Total Amount Type: ${orderJson['total_amount'].runtimeType}');
      print('==============================');

      final response = await http.post(
        Uri.parse('$_baseUrl/v1/bulk-orders'),
        headers: headers,
        body: jsonEncode(orderJson),
      );

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData.containsKey('order')) {
          return BulkOrder.fromJson(responseData['order']);
        } else {
          return BulkOrder.fromJson(responseData);
        }
      } else if (response.statusCode == 401) {
        throw Exception('Please login to create bulk orders');
      }
      throw Exception(
          'Failed to create bulk order: ${response.statusCode} - ${response.body}');
    } catch (e) {
      print('Create bulk order error: $e'); // Debug log
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw Exception(
            'Could not connect to the server. Please check if the server is running and your internet connection.');
      }
      throw Exception(e.toString());
    }
  }

  Future<BulkOrder> getBulkOrder(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/v1/bulk-orders/$id'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return BulkOrder.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 401) {
        throw Exception('Please login to view bulk order details');
      }
      throw Exception(
          'Failed to fetch bulk order: ${response.statusCode} - ${response.body}');
    } catch (e) {
      print('Get bulk order error: $e'); // Debug log
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw Exception(
            'Could not connect to the server. Please check if the server is running and your internet connection.');
      }
      throw Exception(e.toString());
    }
  }

  // Fetch Cake Config (sizes and option groups)
  Future<Map<String, dynamic>> getCakeConfig() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/v1/cake-config'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Failed to load cake config: ${response.statusCode}');
    } catch (e) {
      print('Cake config fetch error: $e');
      throw Exception('Failed to fetch cake config. ${e.toString()}');
    }
  }

  // Custom Cake Orders
  Future<Map<String, dynamic>> createCustomCakeOrder({
    required String cakeSize,
    required String cakeFlavor,
    required String cakeFilling,
    required String cakeFrosting,
    String? specialInstructions,
    String? deliveryDate,
    String? deliveryAddress,
    File? referenceImage,
  }) async {
    try {
      // Create multipart request for image upload
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/v1/custom-cake-orders'),
      );

      // Add headers
      final authHeaders = await _getAuthHeaders();
      request.headers.addAll(authHeaders);
      request.headers.remove('Content-Type'); // Remove for multipart

      // Add text fields
      request.fields['cake_size'] = cakeSize;
      request.fields['cake_flavor'] = cakeFlavor;
      request.fields['cake_filling'] = cakeFilling;
      request.fields['cake_frosting'] = cakeFrosting;
      if (specialInstructions != null) {
        request.fields['special_instructions'] = specialInstructions;
      }
      if (deliveryDate != null) {
        request.fields['delivery_date'] = deliveryDate;
      }
      if (deliveryAddress != null) {
        request.fields['delivery_address'] = deliveryAddress;
      }

      // Add image file if provided
      if (referenceImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'reference_image',
            referenceImage.path,
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': 'Custom cake order placed successfully!',
          'order': jsonDecode(response.body)['order'],
        };
      } else if (response.statusCode == 401) {
        throw Exception('Please login to place custom cake orders');
      } else if (response.statusCode == 422) {
        final errors = jsonDecode(response.body)['errors'];
        throw Exception('Validation errors: ${errors.toString()}');
      }
      throw Exception(
          'Failed to place custom cake order: ${response.statusCode} - ${response.body}');
    } catch (e) {
      print('Create custom cake order error: $e'); // Debug log
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw Exception(
            'Could not connect to the server. Please check if the server is running and your internet connection.');
      }
      throw Exception(e.toString());
    }
  }

  Future<List<Map<String, dynamic>>> getCustomCakeOrders() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/v1/custom-cake-orders'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 401) {
        throw Exception('Please login to view custom cake orders');
      }
      throw Exception(
          'Failed to fetch custom cake orders: ${response.statusCode} - ${response.body}');
    } catch (e) {
      print('Get custom cake orders error: $e'); // Debug log
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw Exception(
            'Could not connect to the server. Please check if the server is running and your internet connection.');
      }
      throw Exception(e.toString());
    }
  }

  Future<Map<String, dynamic>> getCustomCakeOrder(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/v1/custom-cake-orders/$id'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Please login to view custom cake order details');
      }
      throw Exception(
          'Failed to fetch custom cake order: ${response.statusCode} - ${response.body}');
    } catch (e) {
      print('Get custom cake order error: $e'); // Debug log
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw Exception(
            'Could not connect to the server. Please check if the server is running and your internet connection.');
      }
      throw Exception(e.toString());
    }
  }

  Future<Map<String, dynamic>> updateCustomCakeOrder({
    required int id,
    required String cakeSize,
    required String cakeFlavor,
    required String cakeFilling,
    required String cakeFrosting,
    String? specialInstructions,
    String? deliveryDate,
    String? deliveryAddress,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/v1/custom-cake-orders/$id'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'cake_size': cakeSize,
          'cake_flavor': cakeFlavor,
          'cake_filling': cakeFilling,
          'cake_frosting': cakeFrosting,
          'special_instructions': specialInstructions,
          'delivery_date': deliveryDate,
          'delivery_address': deliveryAddress,
        }),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Custom cake order updated successfully!',
          'order': jsonDecode(response.body)['order'],
        };
      } else if (response.statusCode == 401) {
        throw Exception('Please login to update custom cake orders');
      } else if (response.statusCode == 422) {
        final errors = jsonDecode(response.body)['errors'];
        throw Exception('Validation errors: ${errors.toString()}');
      }
      throw Exception(
          'Failed to update custom cake order: ${response.statusCode} - ${response.body}');
    } catch (e) {
      print('Update custom cake order error: $e'); // Debug log
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw Exception(
            'Could not connect to the server. Please check if the server is running and your internet connection.');
      }
      throw Exception(e.toString());
    }
  }

  Future<Map<String, dynamic>> deleteCustomCakeOrder(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/v1/custom-cake-orders/$id'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Custom cake order deleted successfully!',
        };
      } else if (response.statusCode == 401) {
        throw Exception('Please login to delete custom cake orders');
      }
      throw Exception(
          'Failed to delete custom cake order: ${response.statusCode} - ${response.body}');
    } catch (e) {
      print('Delete custom cake order error: $e'); // Debug log
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw Exception(
            'Could not connect to the server. Please check if the server is running and your internet connection.');
      }
      throw Exception(e.toString());
    }
  }
}
