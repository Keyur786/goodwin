import 'dart:math';

import 'package:goodwin/models/order_model.dart';

class OrderService {
  static String generateOrderNumber() {
    final random = Random();
    final suffix = random.nextInt(900000) + 100000;
    final year = DateTime.now().year;
    return 'WH-$year-${suffix.toString().padLeft(6, '0')}';
  }

  static String generatePickupCode() {
    final random = Random();
    final value = random.nextInt(900000) + 100000;
    return value.toString();
  }

  static OrderModel createOrder({
    required String customerId,
    required String customerName,
    required String warehouseId,
    required List<OrderItemModel> items,
    required double totalAmount,
    String? pickupCode,
  }) {
    final orderId = 'order_${DateTime.now().millisecondsSinceEpoch}';

    return OrderModel(
      id: orderId,
      orderNumber: generateOrderNumber(),
      customerId: customerId,
      customerName: customerName,
      warehouseId: warehouseId,
      items: items,
      totalAmount: totalAmount,
      paymentMethod: 'Cash at Warehouse',
      paymentStatus: PaymentStatus.unpaid,
      orderStatus: OrderStatus.pending,
      pickupCode: pickupCode ?? generatePickupCode(),
      pickedUpAt: null,
      createdAt: DateTime.now(),
      pickupDate: DateTime.now().add(const Duration(days: 1)),
      pickupTimeSlot: 'Afternoon',
      isPaid: false,
    );
  }
}
