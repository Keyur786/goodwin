import 'package:flutter/material.dart';
import 'package:goodwin/core/services/demo_repository.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final customers = appRepositoryProvider.getCustomers();

    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: customers.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final customer = customers[index];
          return Card(
            child: ListTile(
              title: Text(customer.shopName ?? customer.name),
              subtitle: Text('${customer.name} • ${customer.phone}'),
              trailing: const Icon(LucideIcons.chevronRight),
            ),
          );
        },
      ),
    );
  }
}
