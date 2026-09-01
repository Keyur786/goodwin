import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goodwin/core/services/demo_repository.dart';
import 'package:goodwin/models/order_model.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.totalOrders,
    required this.pendingOrders,
    required this.readyForPickup,
    required this.completedOrders,
    required this.totalSales,
  });

  final int totalOrders;
  final int pendingOrders;
  final int readyForPickup;
  final int completedOrders;
  final double totalSales;
}

final dashboardProvider = FutureProvider<DashboardSummary>((ref) async {
  final orderRepository = ref.read(firestoreOrderRepositoryProvider);
  final orders = await orderRepository.getOrdersByWarehouse('katargam');

  return DashboardSummary(
    totalOrders: orders.length,
    pendingOrders: orders.where((order) => order.orderStatus == OrderStatus.pending).length,
    readyForPickup: orders.where((order) => order.orderStatus == OrderStatus.readyForPickup).length,
    completedOrders: orders.where((order) => order.orderStatus == OrderStatus.completed).length,
    totalSales: orders.fold<double>(0, (sum, order) => sum + order.totalAmount),
  );
});
