import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goodwin/features/admin/pickup/providers/pickup_verification_provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class PickupScannerScreen extends ConsumerStatefulWidget {
  const PickupScannerScreen({super.key});

  @override
  ConsumerState<PickupScannerScreen> createState() => _PickupScannerScreenState();
}

class _PickupScannerScreenState extends ConsumerState<PickupScannerScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pickupVerificationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pickup Scanner')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(LucideIcons.circleAlert, color: Colors.red),
                        const SizedBox(height: 8),
                        Text(state.error ?? '', style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ),
              ),
            const Text(
              'Enter pickup code',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Pickup Code',
                prefixIcon: Icon(LucideIcons.qrCode),
                hintText: 'e.g., 123456',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: state.isLoading
                  ? null
                  : () {
                      ref.read(pickupVerificationProvider.notifier).verifyPickupCode(
                            _codeController.text,
                            'katargam',
                          );
                    },
              icon: const Icon(LucideIcons.search),
              label: state.isLoading ? const Text('Searching...') : const Text('Verify Pickup Code'),
            ),
            if (state.order != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Order Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Text('Order: ${state.order!.orderNumber}'),
                      Text('Customer: ${state.order!.customerName}'),
                      Text('Total: ₹${state.order!.totalAmount.toStringAsFixed(0)}'),
                      Text('Status: ${state.order!.orderStatus.name}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!state.isPickedUp) ...[
                FilledButton.icon(
                  onPressed: state.isLoading
                      ? null
                      : () {
                          ref.read(pickupVerificationProvider.notifier).confirmPickup(
                                orderId: state.order!.id,
                                pickupCode: _codeController.text,
                              );
                        },
                  icon: const Icon(LucideIcons.checkCircle),
                  label: const Text('Confirm Pickup'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: state.isLoading
                      ? null
                      : () {
                          ref.read(pickupVerificationProvider.notifier).recordPayment(
                                orderId: state.order!.id,
                                amount: state.order!.totalAmount,
                              );
                        },
                  icon: const Icon(LucideIcons.banknote),
                  label: const Text('Confirm Payment & Complete'),
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(LucideIcons.checkCircle, color: Colors.green, size: 48),
                      SizedBox(height: 8),
                      Text('Pickup complete', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.green)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
