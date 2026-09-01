import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goodwin/core/services/demo_repository.dart';
import 'package:goodwin/features/auth/providers/auth_provider.dart';
import 'package:goodwin/models/order_model.dart';

/// Provider to fetch customer's orders from Firestore
final customerOrdersProvider = FutureProvider<List<OrderModel>>((ref) async {
  final user = ref.watch(authProvider);
  if (user == null) return [];

  final orderRepository = ref.read(firestoreOrderRepositoryProvider);
  return orderRepository.getOrdersByCustomer(user.id);
});

/// Provider to fetch all warehouse orders (admin)
final warehouseOrdersProvider = FutureProvider.family<List<OrderModel>, String>((ref, warehouseId) async {
  final orderRepository = ref.read(firestoreOrderRepositoryProvider);
  return orderRepository.getOrdersByWarehouse(warehouseId);
});

/// Provider to fetch ready-for-pickup orders (admin)
final readyForPickupProvider = FutureProvider.family<List<OrderModel>, String>((ref, warehouseId) async {
  final orderRepository = ref.read(firestoreOrderRepositoryProvider);
  return orderRepository.getReadyForPickup(warehouseId);
});

/// Provider to fetch orders by status (admin)
final ordersByStatusProvider = FutureProvider.family<List<OrderModel>, ({String warehouseId, OrderStatus status})>(
  (ref, params) async {
    final orderRepository = ref.read(firestoreOrderRepositoryProvider);
    return orderRepository.getOrdersByStatus(
      warehouseId: params.warehouseId,
      status: params.status,
    );
  },
);
