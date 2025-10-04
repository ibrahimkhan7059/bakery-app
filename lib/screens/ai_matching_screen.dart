import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AIMatchingScreen extends StatefulWidget {
  const AIMatchingScreen({Key? key}) : super(key: key);

  @override
  State<AIMatchingScreen> createState() => _AIMatchingScreenState();
}

class _AIMatchingScreenState extends State<AIMatchingScreen> {
  File? _selectedImage;
  bool _isLoading = false;
  Map<String, dynamic>? _predictionResult;
  List<dynamic>? _matchingCakes;
  String? _errorMessage;

  // API URL - Laravel Backend (Port 8000)
  final String apiUrl = 'http://192.168.100.4:8080/api/v1/ai-cake';

  final ImagePicker _picker = ImagePicker();

  // Helper method to group cakes by category
  Map<String, List<dynamic>> _groupCakesByCategory() {
    if (_matchingCakes == null) return {};

    final Map<String, List<dynamic>> grouped = {};

    for (var cake in _matchingCakes!) {
      // Use the category directly from the backend
      final category = cake['category'] ?? 'Other Cakes';

      // Add to groups based on category from backend
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }

      // Store the cake in its category group
      grouped[category]!.add(cake);
    }

    // Debug info
    print("GROUPED CAKES BY CATEGORY:");
    grouped.forEach((category, cakes) {
      print("$category: ${cakes.length} cakes");
    });

    return grouped;
  }

  // Helper method to build the category grouped list UI
  Widget _buildCategoryGroupedList() {
    if (_matchingCakes == null || _matchingCakes!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No matching cakes found.',
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Simply show all cakes one by one without grouping
    List<Widget> allCakeWidgets = [];

    for (var cake in _matchingCakes!) {
      allCakeWidgets.add(
        GestureDetector(
          onTap: () {
            _showCakeDetailsDialog(context, cake);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: _getCategoryColor(
                        cake['category'] ?? 'Other', cake['category_color'])
                    .withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Cake image
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(
                            cake['category'] ?? 'Other', cake['category_color'])
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: cake['image_url'] != null &&
                          cake['image_url'].toString().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            cake['image_url'],
                            fit: BoxFit.cover,
                            width: 80,
                            height: 80,
                            errorBuilder: (context, error, stackTrace) {
                              print('Error loading image: $error');
                              return Center(
                                child: Icon(
                                  Icons.cake,
                                  size: 40,
                                  color: _getCategoryColor(
                                      cake['category'] ?? 'Other',
                                      cake['category_color']),
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  color: _getCategoryColor(
                                      cake['category'] ?? 'Other',
                                      cake['category_color']),
                                ),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Icon(
                            _getCategoryIcon(cake['category'] ?? 'Other'),
                            size: 40,
                            color: _getCategoryColor(
                                cake['category'] ?? 'Other',
                                cake['category_color']),
                          ),
                        ),
                ),

                const SizedBox(width: 15),

                // Cake details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cake['name'] ?? 'Cake Name',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getCategoryColor(cake['category'] ?? 'Other',
                              cake['category_color']),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Category tag inside the card
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(cake['category'] ?? 'Other',
                                  cake['category_color'])
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _getCategoryColor(
                                    cake['category'] ?? 'Other',
                                    cake['category_color'])
                                .withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          cake['category'] ?? 'Other',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getCategoryColor(
                                cake['category'] ?? 'Other',
                                cake['category_color']),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cake['description'] ?? 'Delicious cake',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            flex: 3,
                            child: Text(
                              cake['price_formatted'] ??
                                  'Rs. ${(cake['price'] ?? 0).toString()}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE91E63),
                              ),
                            ),
                          ),
                          Flexible(
                            flex: 1,
                            child: IconButton(
                              onPressed: () => _addToCart(cake),
                              icon:
                                  const Icon(Icons.add_shopping_cart, size: 20),
                              color: _getCategoryColor(
                                  cake['category'] ?? 'Other',
                                  cake['category_color']),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: allCakeWidgets,
    );
  }

  @override
  void initState() {
    super.initState();
    // Set status bar to white
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
  }

  // Helper method to get color for cake category
  Color _getCategoryColor(String category, dynamic colorHex) {
    // If we have a color from backend, use it
    if (colorHex is String && colorHex.startsWith('#')) {
      try {
        return Color(
            int.parse(colorHex.substring(1, 7), radix: 16) + 0xFF000000);
      } catch (e) {
        // Fall through to default colors if parsing fails
      }
    }

    // Generate a color based on the category name for consistency
    // This ensures the same category always gets the same color
    final int hashCode = category.toLowerCase().hashCode;
    final List<Color> categoryColors = [
      const Color(0xFF795548), // Brown
      const Color(0xFFFF5722), // Deep Orange
      const Color(0xFF2196F3), // Blue
      const Color(0xFF4CAF50), // Green
      const Color(0xFFE91E63), // Pink
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF009688), // Teal
      const Color(0xFFFF9800), // Orange
      const Color(0xFF607D8B), // Blue Grey
    ];

    return categoryColors[hashCode.abs() % categoryColors.length];
  }

  // Helper method to get icon for cake category
  IconData _getCategoryIcon(String category) {
    // Generate an icon based on the category name for consistency
    final int hashCode = category.toLowerCase().hashCode;
    final List<IconData> categoryIcons = [
      Icons.cake, // General cake
      Icons.bakery_dining, // Bakery
      Icons.celebration, // Celebration
      Icons.diversity_3, // Mix/variety
      Icons.star, // Special
      Icons.favorite, // Favorite
      Icons.category, // Generic category
    ];

    return categoryIcons[hashCode.abs() % categoryIcons.length];
  }

  @override
  void dispose() {
    // Reset status bar when leaving the screen
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _predictionResult = null;
          _matchingCakes = null;
        });
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e');
    }
  }

  Future<void> _predictCake() async {
    if (_selectedImage == null) {
      _showSnackBar('Please select an image first');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Skip health check - direct upload to Laravel
      // Laravel will handle AI server connectivity

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiUrl/predict'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('image', _selectedImage!.path),
      );

      var response = await request.send().timeout(const Duration(seconds: 30));

      // Check HTTP status code
      if (response.statusCode != 200) {
        var errorData = await response.stream.bytesToString();
        print('HTTP Error ${response.statusCode}: $errorData');
        _showSnackBar('❌ Server error: ${response.statusCode}');
        return;
      }

      var responseData = await response.stream.bytesToString();

      // Check if response is valid JSON
      Map<String, dynamic> jsonData;
      try {
        jsonData = json.decode(responseData);
      } catch (e) {
        print('JSON Decode Error: $e');
        _showSnackBar('❌ Invalid response from server: $e');
        return;
      }

      // Validate response structure
      if (!jsonData.containsKey('success')) {
        _showSnackBar('❌ Invalid response: missing success field');
        return;
      }

      if (jsonData['success'] == true) {
        // Validate required fields
        if (!jsonData.containsKey('prediction') ||
            !jsonData.containsKey('matching_cakes')) {
          _showSnackBar(
              '❌ Invalid response: missing prediction or matching_cakes');
          return;
        }

        // Check if it's a non-cake image
        bool isCake =
            jsonData.containsKey('is_cake') ? jsonData['is_cake'] : true;

        if (!isCake) {
          // Non-cake image detected
          setState(() {
            _predictionResult = jsonData['prediction'];
            _matchingCakes = [];
          });

          _showSnackBar(
              '❌ ${jsonData['message']}\n💡 Please upload a cake image only');
          return;
        }

        setState(() {
          _predictionResult = jsonData['prediction'];
          // Simply take the first 4 cakes from the response, regardless of category
          List<dynamic> allCakes = jsonData['matching_cakes'];

          // Take up to 4 cakes
          _matchingCakes = allCakes.take(4).toList();
        });
      } else {
        // Handle specific error types
        if (jsonData.containsKey('error') && jsonData['error'] == 'not_cake') {
          _showSnackBar(
              '❌ ${jsonData['message']}\n💡 ${jsonData['suggestion'] ?? "Please upload a cake image only"}');
        } else {
          _showSnackBar('Error: ${jsonData['message']}');
        }
      }
    } on http.ClientException {
      _showSnackBar(
          'Network Error: Please check your WiFi connection and make sure the API server is running on $apiUrl');
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _addToCart(Map<String, dynamic> cake) {
    // TODO: Implement add to cart functionality
    _showSnackBar('Added ${cake['name']} to cart!');
  }

  Future<void> _testConnection() async {
    try {
      setState(() {
        _isLoading = true;
      });

      var response = await http.get(
        Uri.parse('$apiUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSnackBar('✅ Connection successful! API is running on $apiUrl');
      } else {
        _showSnackBar('❌ API responded with status: ${response.statusCode}');
      }
    } on http.ClientException {
      _showSnackBar(
          '❌ Network Error: Cannot connect to $apiUrl. Make sure:\n1. API server is running\n2. Phone and computer are on same WiFi\n3. Firewall allows connection');
    } catch (e) {
      _showSnackBar('❌ Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showCakeDetailsDialog(BuildContext context, Map<String, dynamic> cake) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 500),
            padding: const EdgeInsets.all(0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with cake image
                Stack(
                  children: [
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                        color: const Color(0xFF9C27B0).withOpacity(0.1),
                      ),
                      child: cake['image_url'] != null &&
                              cake['image_url'].toString().isNotEmpty
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20)),
                              child: Image.network(
                                cake['image_url'],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 200,
                                errorBuilder: (context, error, stackTrace) {
                                  print('Error loading detail image: $error');
                                  return const Center(
                                    child: Icon(
                                      Icons.cake,
                                      size: 80,
                                      color: Color(0xFF9C27B0),
                                    ),
                                  );
                                },
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                      color: const Color(0xFF9C27B0),
                                    ),
                                  );
                                },
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.cake,
                                size: 80,
                                color: Color(0xFF9C27B0),
                              ),
                            ),
                    ),
                    // Close button
                    Positioned(
                      top: 10,
                      right: 10,
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 18,
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          color: Colors.black,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ],
                ),

                // Cake details
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and Price Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              cake['name'] ?? 'Cake Name',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF9C27B0),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Text(
                            cake['price_formatted'] ??
                                'Rs. ${(cake['price'] ?? 0).toString()}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE91E63),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Category with enhanced styling
                      if (cake['category'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(
                                    cake['category'], cake['category_color'])
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _getCategoryColor(
                                      cake['category'], cake['category_color'])
                                  .withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getCategoryIcon(cake['category']),
                                size: 16,
                                color: _getCategoryColor(
                                    cake['category'], cake['category_color']),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                cake['category'],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _getCategoryColor(
                                      cake['category'], cake['category_color']),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 15),

                      // Description
                      Text(
                        'Description:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        cake['description'] ?? 'No description available.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Availability
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: cake['is_available'] == true
                                ? Colors.green
                                : Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            cake['is_available'] == true
                                ? 'Available (${cake['available_quantity'] ?? 'In Stock'})'
                                : 'Out of Stock',
                            style: TextStyle(
                              fontSize: 14,
                              color: cake['is_available'] == true
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Order button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            // Here you would add code to add the cake to cart
                            _showSnackBar('Added ${cake['name']} to cart!');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9C27B0),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text('Add to Cart'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar color to match app bar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF9C27B0),
        statusBarIconBrightness: Brightness.light,
      ));
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Cake Matching',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF9C27B0),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF9C27B0),
              Color(0xFFE1BEE7),
              Color(0xFFF3E5F5),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                const Text(
                  '🍰 AI Cake Finder',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(2, 2),
                        blurRadius: 4,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Upload a cake image and let AI find similar cakes for you!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),

                // Image Selection Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Select Cake Image',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9C27B0),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Image preview
                      if (_selectedImage != null) ...[
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: const Color(0xFF9C27B0),
                              width: 3,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Image picker buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9C27B0),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9C27B0),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Disclaimer about cake images only
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.amber[300]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.amber[700],
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Please upload only cake images for accurate AI matching results.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.amber[800],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Predict button
                      if (_selectedImage != null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _predictCake,
                            icon: _isLoading
                                ? Container(
                                    width: 24,
                                    height: 24,
                                    padding: const EdgeInsets.all(2.0),
                                    child: const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Icon(Icons.auto_fix_high),
                            label: Text(_isLoading
                                ? 'Processing...'
                                : 'Match This Cake'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9C27B0),
                              disabledBackgroundColor:
                                  const Color(0xFF9C27B0).withOpacity(0.5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 15,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Results Section (only show when we have results)
                if (_predictionResult != null) ...[
                  const SizedBox(height: 30),

                  // Results Container
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '🍰 Top Similar Cakes from Different Categories',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF9C27B0),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 15),
                        _matchingCakes!.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Text(
                                  'No matching cakes found.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : _buildCategoryGroupedList(),
                      ],
                    ),
                  ),
                ],

                // Error Display Section
                if (_errorMessage != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.red[300]!,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red[700],
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Error',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.red[700],
                          ),
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _errorMessage = null;
                              });
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('Dismiss'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[400],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
