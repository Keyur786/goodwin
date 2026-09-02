import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goodwin/features/customer/orders/providers/orders_provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(customerOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.circleAlert, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading orders: $error'),
            ],
          ),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No orders yet'),
                  SizedBox(height: 8),
                  Text('Start by browsing our catalog', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                child: ListTile(
                  title: Text(order.orderNumber),
                  subtitle: Text('${order.orderStatus.name} • ${order.paymentMethod}'),
                  trailing: Text('₹${order.totalAmount.toStringAsFixed(0)}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
