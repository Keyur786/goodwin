import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goodwin/core/services/demo_repository.dart';
import 'package:goodwin/core/services/order_service.dart';
import 'package:goodwin/models/cart_item_model.dart';
import 'package:goodwin/models/order_model.dart';

class OrderSubmissionController extends Notifier<AsyncValue<OrderModel?>> {
  @override
  AsyncValue<OrderModel?> build() {
    return const AsyncValue.data(null);
  }

  Future<void> submitOrder(
    List<CartItemModel> cartItems, {
    required String pickupCode,
  }) async {
    state = const AsyncLoading();

    try {
      final items = cartItems
          .map(
            (item) => OrderItemModel(
              productId: item.product.id,
              productName: item.product.name,
              sku: item.product.sku,
              variant: item.variant,
              imageUrl: item.product.images.isNotEmpty ? item.product.images.first : null,
              unitPrice: item.unitPrice,
              quantity: item.quantity,
            ),
          )
          .toList();

      final total = cartItems.fold<double>(
        0,
        (sum, item) => sum + item.totalPrice,
      );

      final order = OrderService.createOrder(
        customerId: 'cust_1',
        customerName: 'Riya Traders',
        warehouseId: 'katargam',
        items: items,
        totalAmount: total,
        pickupCode: pickupCode,
      );

      // Try to persist to Firestore, fall back to local state
      final orderRepository = ref.read(firestoreOrderRepositoryProvider);
      final createdOrder = await orderRepository.createOrder(order);

      state = AsyncData(createdOrder);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}

final orderSubmissionProvider =
    NotifierProvider<OrderSubmissionController, AsyncValue<OrderModel?>>(
      () => OrderSubmissionController(),
    );
