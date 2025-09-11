import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ApiService _apiService = ApiService();
  List<Product> relatedProducts = [];
  bool isLoading = false;
  bool isLoadingDetails = false;
  int quantity = 1;
  int currentImageIndex = 0;
  Product?
      detailedProduct; // Store the detailed product with allergens/alternative

  // Define coral color to match theme
  static const Color coralColor = Color(0xFFFF6F61);

  // Get the current product (detailed if available, otherwise widget.product)
  Product get currentProduct => detailedProduct ?? widget.product;

  // For demo, using single image but structured for multiple
  List<String> get productImages {
    if (currentProduct.imageUrl.isNotEmpty) {
      return [currentProduct.imageUrl];
    }
    return ['https://via.placeholder.com/400x400?text=No+Image'];
  }

  @override
  void initState() {
    super.initState();
    _loadProductDetails();
    _loadRelatedProducts();
  }

  Future<void> _loadProductDetails() async {
    setState(() => isLoadingDetails = true);
    try {
      final product = await _apiService.getProductDetails(widget.product.id);
      setState(() {
        detailedProduct = product;
      });
    } catch (e) {
      print('Error loading product details: $e');
      // If failed to load details, use the original product
    } finally {
      setState(() => isLoadingDetails = false);
    }
  }

  Future<void> _loadRelatedProducts() async {
    setState(() => isLoading = true);
    try {
      final products =
          await _apiService.getProductsByCategory(widget.product.categoryId);
      setState(() {
        relatedProducts =
            products.where((p) => p.id != widget.product.id).take(4).toList();
      });
    } catch (e) {
      print('Error loading related products: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _addToCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> cartItems = prefs.getStringList('cart_items') ?? [];

      // Create cart item
      Map<String, dynamic> cartItem = {
        'product_id': currentProduct.id,
        'name': currentProduct.name,
        'price': currentProduct.price,
        'image': currentProduct.imageUrl,
        'quantity': quantity,
        'total': currentProduct.price * quantity,
      };

      // Check if product already in cart
      int existingIndex = cartItems.indexWhere((item) {
        Map<String, dynamic> decoded = jsonDecode(item);
        return decoded['product_id'] == currentProduct.id;
      });

      if (existingIndex != -1) {
        // Update existing item quantity
        Map<String, dynamic> existing = jsonDecode(cartItems[existingIndex]);
        existing['quantity'] += quantity;
        existing['total'] = existing['price'] * existing['quantity'];
        cartItems[existingIndex] = jsonEncode(existing);
      } else {
        // Add new item
        cartItems.add(jsonEncode(cartItem));
      }

      await prefs.setStringList('cart_items', cartItems);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${currentProduct.name} added to cart!'),
            backgroundColor: coralColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding to cart: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildImageGallery() {
    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: productImages.length,
            onPageChanged: (index) {
              setState(() => currentImageIndex = index);
            },
            itemBuilder: (context, index) {
              return Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    productImages[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 80,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          // Image indicators
          if (productImages.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: productImages.asMap().entries.map((entry) {
                  return GestureDetector(
                    onTap: () => setState(() => currentImageIndex = entry.key),
                    child: Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: currentImageIndex == entry.key
                            ? coralColor
                            : Colors.white.withOpacity(0.5),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: coralColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: quantity > 1 ? () => setState(() => quantity--) : null,
            icon: const Icon(Icons.remove),
            color: coralColor,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              quantity.toString(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: quantity < currentProduct.stock
                ? () => setState(() => quantity++)
                : null,
            icon: const Icon(Icons.add),
            color: coralColor,
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedProducts() {
    if (relatedProducts.isEmpty && !isLoading) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Related Products',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: relatedProducts.length,
              itemBuilder: (context, index) {
                final product = relatedProducts[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProductDetailScreen(product: product),
                      ),
                    );
                  },
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              child: Image.network(
                                product.imageUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.image),
                                  );
                                },
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  product.formattedPrice,
                                  style: const TextStyle(
                                    color: coralColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: coralColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(
              context, true), // Return a result to trigger refresh
        ),
        title: Text(
          currentProduct.name,
          style: const TextStyle(color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Gallery
            SizedBox(
              height: 300,
              child: PageView.builder(
                itemCount: productImages.length,
                onPageChanged: (index) {
                  setState(() => currentImageIndex = index);
                },
                itemBuilder: (context, index) {
                  return Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        productImages[index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 80,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Product Name & Category
            Text(
              currentProduct.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (currentProduct.categoryName != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: coralColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  currentProduct.categoryName!,
                  style: const TextStyle(
                    color: coralColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Price & Stock
            Row(
              children: [
                Text(
                  currentProduct.formattedPrice,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: coralColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: currentProduct.stock > 0 ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    currentProduct.stock > 0
                        ? 'In Stock (${currentProduct.stock})'
                        : 'Out of Stock',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Description
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              currentProduct.description.isNotEmpty
                  ? currentProduct.description
                  : 'No description available for this product.',
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),

            // Allergens
            if (currentProduct.allergens != null &&
                currentProduct.allergens!.isNotEmpty) ...[
              const Text(
                'Allergens',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: currentProduct.allergens!
                    .map((allergen) => Chip(
                          label: Text(allergen),
                          backgroundColor: Colors.red.shade100,
                          labelStyle: const TextStyle(
                              color: Colors.red, fontWeight: FontWeight.w600),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Alternative Product
            if (currentProduct.alternativeProduct != null) ...[
              const Text(
                'Alternative Product',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.green.shade50,
                child: ListTile(
                  leading: currentProduct
                          .alternativeProduct!.imageUrl.isNotEmpty
                      ? Image.network(
                          currentProduct.alternativeProduct!.imageUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover)
                      : const Icon(Icons.image, size: 48, color: Colors.grey),
                  title: Text(currentProduct.alternativeProduct!.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle:
                      Text(currentProduct.alternativeProduct!.formattedPrice),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailScreen(
                            product: currentProduct.alternativeProduct!),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Quantity Selector & Add to Cart
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quantity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildQuantitySelector(),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: ElevatedButton(
                    onPressed: currentProduct.stock > 0 ? _addToCart : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: coralColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined),
                        SizedBox(width: 8),
                        Text(
                          'Add to Cart',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Related Products
            _buildRelatedProducts(),
          ],
        ),
      ),
    );
  }
}
