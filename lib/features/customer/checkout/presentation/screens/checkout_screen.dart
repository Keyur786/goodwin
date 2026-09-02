import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goodwin/core/services/order_service.dart';
import 'package:goodwin/features/customer/cart/providers/cart_provider.dart';
import 'package:goodwin/features/customer/checkout/providers/order_submission_provider.dart';
import 'package:goodwin/models/order_model.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  late final String _pickupCode;

  @override
  void initState() {
    super.initState();
    // This is the code that will be saved with the order after confirmation.
    _pickupCode = OrderService.generatePickupCode();
  }

  Future<void> _placeOrder() async {
    final items = ref.read(cartProvider);
    await ref
        .read(orderSubmissionProvider.notifier)
        .submitOrder(items, pickupCode: _pickupCode);
    final result = ref.read(orderSubmissionProvider).value;

    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to place the order. Please try again.'),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _OrderConfirmationDialog(order: result),
    );
    if (!mounted) return;
    ref.read(cartProvider.notifier).clear();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final total = ref.watch(cartTotalProvider);
    final items = ref.watch(cartProvider);
    final orderState = ref.watch(orderSubmissionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Order Summary',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        for (final item in items)
                          ListTile(
                            title: Text(item.product.name),
                            subtitle: Text(
                              'SKU: ${item.product.sku} • Qty: ${item.quantity}',
                            ),
                            trailing: Text(
                              '₹${item.totalPrice.toStringAsFixed(0)}',
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Payment Code',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: ListTile(
                      leading: const Icon(LucideIcons.ticket),
                      title: const Text('Show this code at the warehouse'),
                      subtitle: Text(
                        _pickupCode,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Customer Information',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const ListTile(
                    title: Text('Riya Traders'),
                    subtitle: Text('+91 9876543210'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pickup Information',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const ListTile(
                    title: Text('Warehouse location'),
                    subtitle: Text('Katargam Branch'),
                  ),
                  const SizedBox(height: 8),
                  const ListTile(
                    leading: Icon(LucideIcons.banknote),
                    title: Text('Cash at Warehouse'),
                    subtitle: Text(
                      'Payment is due when you collect the order.',
                    ),
                  ),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total amount to pay',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: items.isEmpty || orderState.isLoading
                      ? null
                      : _placeOrder,
                  child: orderState.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Confirm Order • ₹${total.toStringAsFixed(0)}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderConfirmationDialog extends StatelessWidget {
  const _OrderConfirmationDialog({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Order confirmed'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order: ${order.orderNumber}'),
          const SizedBox(height: 12),
          const Text('Payment code'),
          Text(
            order.pickupCode,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 12),
          const Text('Products'),
          ...order.items.map(
            (item) => Text('${item.productName} × ${item.quantity}'),
          ),
          const SizedBox(height: 12),
          Text(
            'Amount due: ₹${order.totalAmount.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text('Pay cash at the warehouse when collecting your order.'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
