import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/search_history.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();
  List<Product> _searchResults = [];
  List<Category> _categories = [];
  List<SearchHistory> _searchHistory = [];
  bool _isLoading = false;
  String _selectedCategory = 'All';
  RangeValues _currentRangeValues = const RangeValues(0, 1000);
  String _sortBy = 'name';

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadSearchHistory();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _apiService.getCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      _showError('Failed to load categories');
    }
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('search_history') ?? [];
    setState(() {
      _searchHistory = history
          .map((item) => SearchHistory.fromJson(json.decode(item)))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  Future<void> _saveSearchHistory(String query) async {
    if (query.trim().isEmpty) return;

    final searchItem = SearchHistory(
      query: query,
      timestamp: DateTime.now(),
    );

    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('search_history') ?? [];

    // Remove if exists and add to front
    history.removeWhere(
        (item) => SearchHistory.fromJson(json.decode(item)).query == query);
    history.insert(0, json.encode(searchItem.toJson()));

    // Keep only last 10 searches
    if (history.length > 10) {
      history = history.sublist(0, 10);
    }

    await prefs.setStringList('search_history', history);
    await _loadSearchHistory();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _saveSearchHistory(query);
      final results = await _apiService.searchProducts(
        query: query,
        category: _selectedCategory == 'All' ? null : _selectedCategory,
        minPrice: _currentRangeValues.start,
        maxPrice: _currentRangeValues.end,
        sortBy: _sortBy,
      );

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Search failed. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search products...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchResults.clear();
              });
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        onSubmitted: (_) => _performSearch(),
      ),
    );
  }

  Widget _buildFilters() {
    return ExpansionTile(
      title: const Text('Filters & Sort'),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Filter
              DropdownButton<String>(
                isExpanded: true,
                value: _selectedCategory,
                items: ['All', ..._categories.map((c) => c.name)]
                    .map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                    _performSearch();
                  }
                },
              ),

              const SizedBox(height: 16),

              // Price Range Filter
              const Text('Price Range'),
              RangeSlider(
                values: _currentRangeValues,
                min: 0,
                max: 1000,
                divisions: 20,
                labels: RangeLabels(
                  _currentRangeValues.start.round().toString(),
                  _currentRangeValues.end.round().toString(),
                ),
                onChanged: (RangeValues values) {
                  setState(() {
                    _currentRangeValues = values;
                  });
                },
                onChangeEnd: (_) => _performSearch(),
              ),

              const SizedBox(height: 16),

              // Sort Options
              DropdownButton<String>(
                isExpanded: true,
                value: _sortBy,
                items: const [
                  DropdownMenuItem(value: 'name', child: Text('Name (A-Z)')),
                  DropdownMenuItem(
                      value: 'price_asc', child: Text('Price: Low to High')),
                  DropdownMenuItem(
                      value: 'price_desc', child: Text('Price: High to Low')),
                  DropdownMenuItem(
                      value: 'newest', child: Text('Newest First')),
                ],
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _sortBy = newValue;
                    });
                    _performSearch();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchHistory() {
    if (_searchHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Searches',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('search_history');
                  await _loadSearchHistory();
                },
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _searchHistory.length,
          itemBuilder: (context, index) {
            final history = _searchHistory[index];
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text(history.query),
              subtitle: Text(
                '${DateTime.now().difference(history.timestamp).inMinutes} minutes ago',
              ),
              onTap: () {
                _searchController.text = history.query;
                _performSearch();
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Text('No results found'),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final product = _searchResults[index];
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () async {
              // Navigate to product detail
              final result = await Navigator.pushNamed(
                context,
                '/product-detail',
                arguments: product,
              );
              // No need to handle result here as this screen will pop back to home
            },
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
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
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
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Search'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildSearchBar(),
            _buildFilters(),
            if (_searchController.text.isEmpty) _buildSearchHistory(),
            if (_searchController.text.isNotEmpty) _buildSearchResults(),
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
