enum OrderStatus {
  pending,
  confirmed,
  preparing,
  readyForPickup,
  inDelivery,
  pickedUp,
  completed,
  cancelled,
}

enum PaymentStatus { unpaid, pending, paid, refunded }

class OrderItemModel {
  const OrderItemModel({
    required this.productId,
    required this.productName,
    this.sku = '',
    this.variant,
    required this.unitPrice,
    required this.quantity,
  });

  final String productId;
  final String productName;
  final String sku;
  final String? variant;
  final double unitPrice;
  final int quantity;

  double get totalPrice => unitPrice * quantity;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'sku': sku,
        'variant': variant,
        'unitPrice': unitPrice,
        'quantity': quantity,
      };
}

class OrderModel {
  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.warehouseId,
    required this.items,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.orderStatus,
    required this.pickupCode,
    this.pickedUpAt,
    required this.createdAt,
    this.pickupDate,
    this.pickupTimeSlot,
    this.isPaid = false,
    this.deliveryType = 'warehouse_pickup',
    this.deliveryAddress,
    this.paymentId,
    this.customerTier = 'Silver',
    this.customerTotalSpend = 0.0,
  });

  final String id;
  final String orderNumber;
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String warehouseId;
  final List<OrderItemModel> items;
  final double totalAmount;
  final String paymentMethod;
  final PaymentStatus paymentStatus;
  final OrderStatus orderStatus;
  final String pickupCode;
  final DateTime? pickedUpAt;
  final DateTime createdAt;
  final DateTime? pickupDate;
  final String? pickupTimeSlot;
  final bool isPaid;
  final String deliveryType;
  final String? deliveryAddress;
  final String? paymentId;
  final String customerTier;
  final double customerTotalSpend;

  bool get isOnlineOrder {
    final dt = deliveryType.toLowerCase().trim();
    final pm = paymentMethod.toLowerCase().trim();
    return dt == 'prepaid_delivery' ||
        dt == 'online_delivery' ||
        dt == 'delivery' ||
        dt == 'prepaid' ||
        pm.contains('razorpay') ||
        pm.contains('prepaid') ||
        (paymentId != null && paymentId!.trim().isNotEmpty) ||
        (deliveryAddress != null &&
            deliveryAddress!.trim().isNotEmpty &&
            dt != 'warehouse_pickup');
  }

  bool get isWarehouseOrder => !isOnlineOrder;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      customerPhone: json['customerPhone']?.toString(),
      warehouseId: json['warehouseId']?.toString() ?? '',
      items: (json['items'] as List? ?? const [])
          .map((item) {
            final map = item is Map<String, dynamic>
                ? item
                : (item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{});
            return OrderItemModel(
              productId: map['productId']?.toString() ?? '',
              productName: map['productName']?.toString() ?? 'Product',
              sku: map['sku']?.toString() ?? '',
              variant: map['variant']?.toString(),
              unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
              quantity: (map['quantity'] as num?)?.toInt() ?? 1,
            );
          })
          .toList(),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod']?.toString() ?? 'Cash at Warehouse',
      paymentStatus: PaymentStatus.values.firstWhere(
        (value) => value.name == (json['paymentStatus'] ?? 'unpaid'),
        orElse: () => PaymentStatus.unpaid,
      ),
      orderStatus: OrderStatus.values.firstWhere(
        (value) => value.name == (json['orderStatus'] ?? 'pending'),
        orElse: () => OrderStatus.pending,
      ),
      pickupCode: json['pickupCode']?.toString() ?? '',
      pickedUpAt: json['pickedUpAt'] == null
          ? null
          : DateTime.tryParse(json['pickedUpAt'].toString()),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      pickupDate: json['pickupDate'] == null
          ? null
          : DateTime.tryParse(json['pickupDate'].toString()),
      pickupTimeSlot: json['pickupTimeSlot']?.toString(),
      isPaid: json['isPaid'] as bool? ?? false,
      deliveryType: json['deliveryType']?.toString() ?? 'warehouse_pickup',
      deliveryAddress: json['deliveryAddress']?.toString(),
      paymentId: json['paymentId']?.toString(),
      customerTier: json['customerTier']?.toString() ?? 'Silver',
      customerTotalSpend: (json['customerTotalSpend'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderNumber': orderNumber,
        'customerId': customerId,
        'customerName': customerName,
        if (customerPhone != null) 'customerPhone': customerPhone,
        'warehouseId': warehouseId,
        'items': items.map((item) => item.toJson()).toList(),
        'totalAmount': totalAmount,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus.name,
        'orderStatus': orderStatus.name,
        'pickupCode': pickupCode,
        'pickedUpAt': pickedUpAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'pickupDate': pickupDate?.toIso8601String(),
        'pickupTimeSlot': pickupTimeSlot,
        'isPaid': isPaid,
        'deliveryType': deliveryType,
        if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
        if (paymentId != null) 'paymentId': paymentId,
        'customerTier': customerTier,
        'customerTotalSpend': customerTotalSpend,
      };
}
