import 'package:flutter/material.dart';
import 'package:goodwin/core/services/demo_repository.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final products = appRepositoryProvider.getProducts();

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: products.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final product = products[index];
          return Card(
            child: ListTile(
              title: Text(product.name),
              subtitle: Text('Low stock: ${product.lowStockThreshold}'),
              trailing: Text('${product.availableQty} left'),
            ),
          );
        },
      ),
    );
  }
}
