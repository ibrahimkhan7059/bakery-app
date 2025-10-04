import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for SystemChrome
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../widgets/global_app_bar.dart';

class CakeCustomizationScreen extends StatefulWidget {
  const CakeCustomizationScreen({super.key});

  @override
  State<CakeCustomizationScreen> createState() =>
      _CakeCustomizationScreenState();
}

class _CakeCustomizationScreenState extends State<CakeCustomizationScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  String selectedSize = '1 Pound';
  String selectedFlavor = 'Vanilla';
  String selectedFilling = 'Chocolate';
  String selectedFrosting = 'Buttercream';
  late TabController _tabController;
  final TextEditingController _specialInstructionsController =
      TextEditingController();
  final TextEditingController _deliveryAddressController =
      TextEditingController();
  DateTime? selectedDeliveryDate;
  File? _referenceImage;
  final ImagePicker _picker = ImagePicker();
  Timer? _configRefreshTimer;

  // Collapsible section states
  bool _isSpecialInstructionsExpanded = false;
  bool _isDeliveryExpanded = false;

  // Dynamic config
  Map<String, double> sizePrices = {};
  List<String> cakeSizes = [];
  List<String> cakeFlavors = [];
  List<String> cakeFillings = [];
  List<String> cakeFrostings = [];
  Map<String, double> flavorPrices = {};
  Map<String, double> fillingPrices = {};
  Map<String, double> frostingPrices = {};
  bool _loadingConfig = true;
  String? _configError;

  // Tag color palette and resolver (deterministic by tag name)
  final List<Color> _tagPalette = [
    Colors.amber.shade50,
    Colors.orange.shade50,
    Colors.deepOrange.shade50,
    Colors.red.shade50,
    Colors.pink.shade50,
    Colors.purple.shade50,
    Colors.deepPurple.shade50,
    Colors.indigo.shade50,
    Colors.blue.shade50,
    Colors.lightBlue.shade50,
    Colors.cyan.shade50,
    Colors.teal.shade50,
    Colors.green.shade50,
    Colors.lightGreen.shade50,
    Colors.lime.shade50,
    Colors.yellow.shade50,
    Colors.brown.shade50,
    Colors.grey.shade200,
  ];

  Color _getTagColor(String name) {
    final idx = (name.hashCode & 0x7fffffff) % _tagPalette.length;
    return _tagPalette[idx];
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addObserver(this);

    _loadCakeConfig();
    // Reduced frequency and added error handling for connection stability
    _configRefreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (!mounted) return;
      _loadCakeConfig(silent: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Add small delay before refreshing when app resumes
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _loadCakeConfig(silent: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _configRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _specialInstructionsController.dispose();
    _deliveryAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadCakeConfig({bool silent = false}) async {
    try {
      if (!silent) {
        setState(() {
          _loadingConfig = true;
        });
      }
      final prevSize = selectedSize;
      final prevFlavor = selectedFlavor;
      final prevFilling = selectedFilling;
      final prevFrosting = selectedFrosting;

      // Add timeout and retry logic
      final data = await ApiService().getCakeConfig().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception(
              'Connection timeout - please check your internet connection');
        },
      );
      final List sizes = (data['sizes'] as List?) ?? [];
      final List groups = (data['groups'] as List?) ?? [];

      double asDouble(dynamic v) {
        if (v == null) return 0.0;
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v) ?? 0.0;
        return 0.0;
      }

      final Map<String, double> newSizePrices = {};
      final List<String> newSizes = [];
      for (final s in sizes) {
        final name =
            (s is Map && s['name'] != null) ? s['name'].toString() : '';
        final price = (s is Map) ? asDouble(s['base_price']) : 0.0;
        if (name.isNotEmpty) {
          newSizes.add(name);
          newSizePrices[name] = price;
        }
      }

      final Map<String, double> newFlavorPrices = {};
      final Map<String, double> newFillingPrices = {};
      final Map<String, double> newFrostingPrices = {};
      final List<String> newFlavors = [];
      final List<String> newFillings = [];
      final List<String> newFrostings = [];

      for (final g in groups) {
        if (g is! Map) continue;
        final key = (g['key'] ?? '').toString();
        final opts = (g['options'] as List?) ?? [];
        for (final o in opts) {
          if (o is! Map) continue;
          final name = (o['name'] ?? '').toString();
          final price = asDouble(o['price']);
          if (name.isEmpty) continue;
          if (key == 'flavor') {
            newFlavors.add(name);
            newFlavorPrices[name] = price;
          } else if (key == 'filling') {
            newFillings.add(name);
            newFillingPrices[name] = price;
          } else if (key == 'frosting') {
            newFrostings.add(name);
            newFrostingPrices[name] = price;
          }
        }
      }

      setState(() {
        sizePrices = newSizePrices;
        cakeSizes = newSizes;
        cakeFlavors = newFlavors;
        cakeFillings = newFillings;
        cakeFrostings = newFrostings;
        selectedSize = newSizes.contains(prevSize)
            ? prevSize
            : (newSizes.isNotEmpty ? newSizes.first : prevSize);
        selectedFlavor = newFlavors.contains(prevFlavor)
            ? prevFlavor
            : (newFlavors.isNotEmpty ? newFlavors.first : prevFlavor);
        selectedFilling = newFillings.contains(prevFilling)
            ? prevFilling
            : (newFillings.isNotEmpty ? newFillings.first : prevFilling);
        selectedFrosting = newFrostings.contains(prevFrosting)
            ? prevFrosting
            : (newFrostings.isNotEmpty ? newFrostings.first : prevFrosting);
        flavorPrices = newFlavorPrices;
        fillingPrices = newFillingPrices;
        frostingPrices = newFrostingPrices;
        if (!silent) _loadingConfig = false;
        _configError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          if (!silent) _loadingConfig = false;
          _configError = e.toString();
        });

        // Show error only if not silent and mounted
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load cake options: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  double get calculatePrice {
    double total = 0.0;
    total += sizePrices[selectedSize] ?? 0.0;
    total += flavorPrices[selectedFlavor] ?? 0.0;
    total += fillingPrices[selectedFilling] ?? 0.0;
    total += frostingPrices[selectedFrosting] ?? 0.0;
    return total;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        selectedDeliveryDate = picked;
      });
    }
  }

  Future<void> _placeOrder() async {
    if (selectedDeliveryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery date')),
      );
      return;
    }
    if (selectedFlavor.isEmpty ||
        selectedFilling.isEmpty ||
        selectedFrosting.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select flavor, filling, and frosting')),
      );
      return;
    }
    if (_deliveryAddressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a delivery address')),
      );
      return;
    }

    try {
      // Format the date as YYYY-MM-DD
      String formattedDate =
          "${selectedDeliveryDate!.year}-${selectedDeliveryDate!.month.toString().padLeft(2, '0')}-${selectedDeliveryDate!.day.toString().padLeft(2, '0')}";

      final result = await ApiService().createCustomCakeOrder(
        cakeSize: selectedSize,
        cakeFlavor: selectedFlavor,
        cakeFilling: selectedFilling,
        cakeFrosting: selectedFrosting,
        specialInstructions: _specialInstructionsController.text,
        deliveryDate: formattedDate,
        deliveryAddress: _deliveryAddressController.text.trim(),
        referenceImage: _referenceImage, // Add reference image
      );

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to place order. Please try again.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Widget _buildOptionChip(String option, String selectedValue, Color bgColor) {
    final isSelected = option == selectedValue;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (cakeFlavors.contains(option)) {
            selectedFlavor = isSelected ? '' : option;
          }
          if (cakeFillings.contains(option)) {
            selectedFilling = isSelected ? '' : option;
          }
          if (cakeFrostings.contains(option)) {
            selectedFrosting = isSelected ? '' : option;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : bgColor,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : bgColor,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          option,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTab(IconData icon, String label) {
    return Tab(
      height: 64,
      child: Container(
        width: 90, // Increased width from 85 to 90 to fit Frosting
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                height: 1.2,
                letterSpacing: -0.2, // Added slight letter spacing adjustment
              ),
              textAlign: TextAlign.center,
              maxLines: 1, // Force single line
              softWrap: false, // Prevent wrapping
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Set status bar immediately and smoothly
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

    if (_loadingConfig) {
      return const Scaffold(
        appBar: GlobalAppBar(
            title: '    Design a Cake', showBackButton: true, actions: []),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_configError != null) {
      return Scaffold(
        appBar: const GlobalAppBar(
            title: 'Design a Cake', showBackButton: true, actions: []),
        body:
            Center(child: Text('Failed to load cake options.\n$_configError')),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: const GlobalAppBar(
        title: 'Design a Cake',
        showBackButton: true,
        actions: [],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicatorPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          labelColor: Colors.white,
                          unselectedLabelColor: theme.primaryColor,
                          indicator: BoxDecoration(
                            color: theme.primaryColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          dividerColor: Colors.transparent,
                          labelStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          padding: const EdgeInsets.all(8),
                          isScrollable:
                              false, // Prevent scrolling to show all tabs
                          tabs: [
                            _buildTab(Icons.cake_outlined, 'Size'),
                            _buildTab(Icons.palette_outlined, 'Flavor'),
                            _buildTab(Icons.layers_outlined, 'Filling'),
                            _buildTab(Icons.brush_outlined, 'Frosting'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: MediaQuery.of(context).size.height *
                          0.4, // Reduced from 0.45 to 0.4
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildSizeSection(),
                          _buildFlavorSection(),
                          _buildFillingSection(),
                          _buildFrostingSection(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildOrderSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Cake Size',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          Center(
            // Added Center widget
            child: Wrap(
              alignment: WrapAlignment.center, // Center alignment for Wrap
              spacing: 16, // Horizontal spacing between boxes
              runSpacing: 16, // Vertical spacing between rows
              children: cakeSizes.map((size) {
                final isSelected = size == selectedSize;
                final price = sizePrices[size]?.toStringAsFixed(0) ?? '0';

                return Container(
                  width: 130, // Reduced from 150 to 130
                  padding:
                      const EdgeInsets.all(12), // Reduced padding from 16 to 12
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.white,
                    borderRadius:
                        BorderRadius.circular(10), // Slightly reduced radius
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade300,
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : null,
                  ),
                  child: InkWell(
                    onTap: () => setState(() => selectedSize = size),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cake_outlined,
                          size: 32, // Reduced from 40 to 32
                          color:
                              isSelected ? Colors.white : Colors.grey.shade700,
                        ),
                        const SizedBox(height: 8), // Reduced from 12 to 8
                        Text(
                          size,
                          style: TextStyle(
                            fontSize: 14, // Reduced from 16 to 14
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4), // Reduced from 8 to 4
                        Text(
                          'PKR $price',
                          style: TextStyle(
                            fontSize: 12, // Reduced from 14 to 12
                            color: isSelected
                                ? Colors.white70
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
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

  Widget _buildFlavorSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Your Flavor',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 12,
            children: cakeFlavors
                .map((f) => _buildOptionChip(
                      f,
                      selectedFlavor,
                      _getTagColor(f),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFillingSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Filling',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 12,
            children: cakeFillings
                .map((f) => _buildOptionChip(
                      f,
                      selectedFilling,
                      _getTagColor(f),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFrostingSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Frosting',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 12,
            children: cakeFrostings
                .map((f) => _buildOptionChip(
                      f,
                      selectedFrosting,
                      _getTagColor(f),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8, // Reduced from 16 to 8
            bottom: (MediaQuery.of(context).viewInsets.bottom > 0
                    ? MediaQuery.of(context).viewInsets.bottom
                    : MediaQuery.of(context).padding.bottom) +
                8, // Reduced from 16 to 8
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height < 600
                  ? MediaQuery.of(context).size.height *
                      0.4 // Small screens (phones in portrait)
                  : MediaQuery.of(context).size.height < 800
                      ? MediaQuery.of(context).size.height *
                          0.3 // Medium screens (phones in landscape/small tablets)
                      : MediaQuery.of(context).size.height *
                          0.25, // Large screens (tablets/large phones)
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Combined Special Instructions and Reference Image Section
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isSpecialInstructionsExpanded =
                                  !_isSpecialInstructionsExpanded;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.settings,
                                      color: Theme.of(context).primaryColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Additional Options',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  _isSpecialInstructionsExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_isSpecialInstructionsExpanded)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Special Instructions',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _specialInstructionsController,
                                  decoration: InputDecoration(
                                    labelText: 'Special Instructions',
                                    hintText: 'Any special requests?',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Reference Image',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Reference Image',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: _showImagePickerDialog,
                                      icon:
                                          const Icon(Icons.add_photo_alternate),
                                      label: const Text('Add Image'),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TextButton.icon(
                                      onPressed: _pickImageFallback,
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text(
                                          'Troubleshoot Image Picker'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.orange,
                                        textStyle:
                                            const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_referenceImage != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    height: 120,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Stack(
                                        children: [
                                          Image.file(
                                            _referenceImage!,
                                            width: double.infinity,
                                            height: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _referenceImage = null;
                                                });
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 80,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                        style: BorderStyle.solid,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.image,
                                            color: Colors.grey,
                                            size: 32,
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'No image selected',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8), // Reduced from 12 to 8
                  // Delivery Details Section
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isDeliveryExpanded = !_isDeliveryExpanded;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.local_shipping,
                                      color: Theme.of(context).primaryColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Delivery Details',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  _isDeliveryExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_isDeliveryExpanded)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  title: const Text('Delivery Date'),
                                  subtitle: Text(
                                    selectedDeliveryDate != null
                                        ? '${selectedDeliveryDate!.day}/${selectedDeliveryDate!.month}/${selectedDeliveryDate!.year}'
                                        : 'Select a date',
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.calendar_today),
                                    onPressed: () => _selectDate(context),
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _deliveryAddressController,
                                  decoration: InputDecoration(
                                    labelText: 'Delivery Address',
                                    hintText: 'House #, Street, Area, City',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                  maxLines: 2,
                                  textInputAction: TextInputAction.newline,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8), // Reduced from 12 to 8
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Price',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              'PKR ${calculatePrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _placeOrder,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Place Order',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getFlavorColor(String flavor) {
    switch (flavor) {
      case 'Vanilla':
        return Colors.amber;
      case 'Chocolate':
        return Colors.brown;
      case 'Red Velvet':
        return Colors.red;
      case 'Strawberry':
        return Colors.pink;
      default:
        return Theme.of(context).primaryColor;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Check if the plugin is available
      if (!mounted) return;

      // Add a small delay to ensure plugin is ready
      await Future.delayed(const Duration(milliseconds: 200));

      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80, // Reduce image quality for better performance
        maxWidth: 1024, // Limit image size
        maxHeight: 1024,
      );

      if (image != null && mounted) {
        setState(() {
          _referenceImage = File(image.path);
        });
      }
    } catch (e) {
      print('Image picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showImagePickerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Reference Image'),
          content: const Text('Choose how you want to add a reference image'),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // Fallback method for image picking
  Future<void> _pickImageFallback() async {
    try {
      // Try to use a simpler approach
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
      );

      if (image != null && mounted) {
        setState(() {
          _referenceImage = File(image.path);
        });
      }
    } catch (e) {
      print('Fallback image picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Please try again or restart the app. Error: ${e.toString()}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
