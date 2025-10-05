import 'package:flutter/material.dart';
import '../widgets/global_app_bar.dart';

class OrderDetailScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlobalAppBar(
        title: 'Order #${order['id'] ?? 'N/A'}',
        showBackButton: true,
        actions: const [],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Status Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(order['status'] ?? 'pending')
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            order['status']?.toString().toUpperCase() ??
                                'PENDING',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color:
                                  _getStatusColor(order['status'] ?? 'pending'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Order ID', '#${order['id'] ?? 'N/A'}'),
                    _buildInfoRow(
                        'Order Date', _formatDate(order['created_at'])),
                    _buildInfoRow('Delivery Type',
                        _formatDeliveryType(order['delivery_type'])),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Customer Information Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Name', order['customer_name'] ?? 'N/A'),
                    _buildInfoRow('Email', order['customer_email'] ?? 'N/A'),
                    _buildInfoRow('Phone', order['customer_phone'] ?? 'N/A'),
                    if (order['delivery_address'] != null &&
                        order['delivery_address'].isNotEmpty)
                      _buildInfoRow('Address', order['delivery_address']),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Order Items Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Items',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildOrderItems(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Payment Summary Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPaymentRow('Subtotal', order['subtotal']),
                    _buildPaymentRow(
                        'Delivery Charges', order['delivery_charges']),
                    const Divider(),
                    _buildPaymentRow('Total Amount', order['total_amount'],
                        isTotal: true),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Special Notes Card (if any)
            if (order['special_notes'] != null &&
                order['special_notes'].isNotEmpty)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Special Notes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        order['special_notes'],
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, dynamic amount,
      {bool isTotal = false}) {
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                fontSize: isTotal ? 16 : 14,
                color: isTotal ? Colors.black : Colors.grey.shade700,
              ),
            ),
            Text(
              'PKR ${amount ?? '0'}',
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                fontSize: isTotal ? 16 : 14,
                color: isTotal ? Theme.of(context).primaryColor : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItems() {
    final items = order['items'];

    // If no items array, try to show single product info
    if (items == null || (items is List && items.isEmpty)) {
      // Fallback to single product display
      if (order['product_name'] != null || order['cake_name'] != null) {
        return _buildSingleProductTile();
      }
      return const Text(
        'No items found',
        style: TextStyle(color: Colors.grey),
      );
    }

    if (items is List) {
      return Column(
        children: items.map((item) => _buildItemTile(item)).toList(),
      );
    } else {
      return _buildItemTile(items);
    }
  }

  Widget _buildSingleProductTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order['product_name'] ??
                      order['cake_name'] ??
                      'Unknown Product',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Qty: ${order['quantity'] ?? 1} × PKR ${order['price'] ?? order['total_amount'] ?? '0'}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'PKR ${order['total_amount'] ?? '0'}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(dynamic item) {
    final itemMap = item is Map<String, dynamic> ? item : <String, dynamic>{};

    // Get item name from various possible fields
    final itemName = itemMap['product_name'] ??
        itemMap['cake_name'] ??
        itemMap['name'] ??
        'Unknown Item';

    // Get quantity and price
    final quantity = int.tryParse('${itemMap['quantity'] ?? 1}') ?? 1;
    final price =
        double.tryParse('${itemMap['price'] ?? itemMap['unit_price'] ?? 0}') ??
            0.0;
    final subtotal =
        double.tryParse('${itemMap['subtotal'] ?? itemMap['total'] ?? 0}') ??
            (price * quantity);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Qty: $quantity × PKR ${price.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                // Show additional item details if available
                if (itemMap['size'] != null)
                  Text(
                    'Size: ${itemMap['size']}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                if (itemMap['flavor'] != null)
                  Text(
                    'Flavor: ${itemMap['flavor']}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                if (itemMap['special_instructions'] != null &&
                    itemMap['special_instructions'].isNotEmpty)
                  Text(
                    'Note: ${itemMap['special_instructions']}',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            'PKR ${subtotal.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
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

  String _formatDate(dynamic dateTime) {
    if (dateTime == null) return 'N/A';

    try {
      DateTime date;
      if (dateTime is String) {
        date = DateTime.parse(dateTime);
      } else if (dateTime is DateTime) {
        date = dateTime;
      } else {
        return dateTime.toString();
      }

      return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime.toString();
    }
  }

  String _formatDeliveryType(dynamic deliveryType) {
    if (deliveryType == null) return 'N/A';

    switch (deliveryType.toString().toLowerCase()) {
      case 'home_delivery':
        return 'Home Delivery';
      case 'self_pickup':
        return 'Self Pickup';
      default:
        return deliveryType.toString();
    }
  }
}
