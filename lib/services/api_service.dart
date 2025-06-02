import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/category.dart';
import '../models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // For Android Emulator, use 10.0.2.2 to access your host machine's localhost
  // For physical device or iOS simulator, use your computer's local network IP (e.g., http://192.168.1.X:8000)
  final String _baseUrl =
      'http:// 127.0.0.1:8000/api'; // Updated to use your network IP address

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
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/v1/categories'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> categoriesJson = jsonDecode(response.body);
        return categoriesJson.map((json) => Category.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      print('Categories fetch error: $e');
      throw Exception(
          'Failed to fetch categories. Please check your connection.');
    }
  }

  // Fetch All Products
  Future<List<Product>> getProducts() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/v1/products'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> productsJson = jsonDecode(response.body);
        return productsJson.map((json) => Product.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      print('Products fetch error: $e');
      throw Exception(
          'Failed to fetch products. Please check your connection.');
    }
  }

  // Fetch Products by Category
  Future<List<Product>> getProductsByCategory(int categoryId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/v1/products/category/$categoryId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> productsJson = jsonDecode(response.body);
        return productsJson.map((json) => Product.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to load category products: ${response.statusCode}');
      }
    } catch (e) {
      print('Category products fetch error: $e');
      throw Exception(
          'Failed to fetch category products. Please check your connection.');
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
}
