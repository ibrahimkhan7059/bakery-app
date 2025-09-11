class BulkOrder {
  final int id;
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final String deliveryAddress;
  final DateTime deliveryDate;
  final String? deliveryTime;
  final String orderType; // 'birthday', 'party', 'corporate', 'other'
  final String? eventDetails;
  final double totalAmount;
  final String
      status; // 'pending', 'confirmed', 'processing', 'completed', 'cancelled'
  final String paymentStatus; // 'pending', 'partial', 'paid'
  final String paymentMethod; // 'cash', 'gcash', 'bank_transfer'
  final double advancePayment;
  final String? specialInstructions;
  final String? cancellationReason;
  final int userId;
  final List<BulkOrderItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  BulkOrder({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    required this.deliveryAddress,
    required this.deliveryDate,
    this.deliveryTime,
    required this.orderType,
    this.eventDetails,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.advancePayment,
    this.specialInstructions,
    this.cancellationReason,
    required this.userId,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BulkOrder.fromJson(Map<String, dynamic> json) {
    return BulkOrder(
      id: json['id'] ?? 0,
      orderNumber: json['order_number'] ?? '',
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      customerEmail: json['customer_email'],
      deliveryAddress: json['delivery_address'] ?? '',
      deliveryDate: json['delivery_date'] != null
          ? DateTime.parse(json['delivery_date'])
          : DateTime.now(),
      deliveryTime: json['delivery_time'],
      orderType: json['order_type'] ?? 'other',
      eventDetails: json['event_details'],
      totalAmount:
          double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      status: json['status'] ?? 'pending',
      paymentStatus: json['payment_status'] ?? 'pending',
      paymentMethod: json['payment_method'] ?? 'cash',
      advancePayment:
          double.tryParse(json['advance_payment']?.toString() ?? '0') ?? 0.0,
      specialInstructions: json['special_instructions'],
      cancellationReason: json['cancellation_reason'],
      userId: json['user_id'] ?? 1,
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => BulkOrderItem.fromJson(item))
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'delivery_address': deliveryAddress,
      'delivery_date': deliveryDate.toIso8601String().split('T')[0],
      'delivery_time': deliveryTime,
      'order_type': orderType,
      'event_details': eventDetails,
      'total_amount': totalAmount,
      'status': status,
      'payment_status': paymentStatus,
      'payment_method': paymentMethod,
      'advance_payment': advancePayment,
      'special_instructions': specialInstructions,
      'cancellation_reason': cancellationReason,
      'user_id': userId,
      'items': items.map((item) => item.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Method specifically for creating new bulk orders (excludes auto-generated fields)
  Map<String, dynamic> toCreateJson() {
    final json = <String, dynamic>{
      'customer_name': customerName.trim(),
      'customer_phone': customerPhone.trim(),
      'delivery_address': deliveryAddress.trim(),
      'delivery_date': deliveryDate.toIso8601String().split('T')[0],
      'payment_method': paymentMethod,
      'advance_payment': advancePayment,
      'total_amount': totalAmount,
      'items': items.map((item) => item.toCreateJson()).toList(),
    };

    // Only include optional fields if they have values
    if (customerEmail != null && customerEmail!.trim().isNotEmpty) {
      json['customer_email'] = customerEmail!.trim();
    }
    if (deliveryTime != null && deliveryTime!.trim().isNotEmpty) {
      json['delivery_time'] = deliveryTime!.trim();
    }
    if (orderType.isNotEmpty) {
      json['order_type'] = orderType;
    }
    if (eventDetails != null && eventDetails!.trim().isNotEmpty) {
      json['event_details'] = eventDetails!.trim();
    }
    if (specialInstructions != null && specialInstructions!.trim().isNotEmpty) {
      json['special_instructions'] = specialInstructions!.trim();
    }
    if (status.isNotEmpty) {
      json['status'] = status;
    }
    if (paymentStatus.isNotEmpty) {
      json['payment_status'] = paymentStatus;
    }

    return json;
  }

  // Helper methods
  double get remainingPayment => totalAmount - advancePayment;
  String get formattedStatus => status[0].toUpperCase() + status.substring(1);
  String get formattedPaymentStatus =>
      paymentStatus[0].toUpperCase() + paymentStatus.substring(1);
  String get formattedOrderType =>
      orderType[0].toUpperCase() + orderType.substring(1);
}

class BulkOrderItem {
  final int id;
  final int bulkOrderId;
  final int productId;
  final String productName;
  final int quantity;
  final double price;
  final double discount; // Percentage as decimal (0.10 = 10%)
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  BulkOrderItem({
    required this.id,
    required this.bulkOrderId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.discount,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  // Calculated properties
  double get subtotal => price * quantity;
  double get discountAmount => subtotal * discount;
  double get total => subtotal - discountAmount;

  factory BulkOrderItem.fromJson(Map<String, dynamic> json) {
    return BulkOrderItem(
      id: json['id'] ?? 0,
      bulkOrderId: json['bulk_order_id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productName: json['product_name'] ?? '',
      quantity: json['quantity'] ?? 0,
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      discount: double.tryParse(json['discount']?.toString() ?? '0') ?? 0.0,
      notes: json['notes'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bulk_order_id': bulkOrderId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price': price,
      'discount': discount,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Method for creating new bulk order items (excludes auto-generated fields)
  Map<String, dynamic> toCreateJson() {
    final json = <String, dynamic>{
      'product_id': productId,
      'product_name': productName.trim(),
      'quantity': quantity,
      'price': price,
      'discount': discount,
    };

    // Only include notes if they have values
    if (notes != null && notes!.trim().isNotEmpty) {
      json['notes'] = notes!.trim();
    }

    return json;
  }
}
