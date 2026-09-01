import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goodwin/features/customer/cart/providers/cart_provider.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);

    if (items.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 80),
              SizedBox(height: 16),
              Text('Your cart is empty', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Cart')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: Color(0xFFF1F5F9), width: 1.2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              item.product.images.isNotEmpty
                                  ? item.product.images.first
                                  : '',
                              width: 68,
                              height: 68,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const SizedBox(
                                width: 68,
                                height: 68,
                                child: Center(child: Icon(Icons.image_not_supported_outlined)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${item.unitPrice.toStringAsFixed(0)} / unit',
                                  style: const TextStyle(
                                    color: Color(0xFF0F766E),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 3,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () async {
                                          if (item.quantity > 1) {
                                            ref.read(cartProvider.notifier).updateQuantity(item.product.id, item.quantity - 1);
                                          } else {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (dialogCtx) => AlertDialog(
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                title: const Text('Remove from Cart?'),
                                                content: Text('Are you sure you want to remove "${item.product.name}" from your cart?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(dialogCtx, false),
                                                    child: const Text('Keep in Cart'),
                                                  ),
                                                  FilledButton(
                                                    onPressed: () => Navigator.pop(dialogCtx, true),
                                                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                                                    child: const Text('Remove'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              ref.read(cartProvider.notifier).removeProduct(item.product.id);
                                            }
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.all(5),
                                          child: Icon(
                                            item.quantity > 1 ? Icons.remove_rounded : Icons.delete_outline_rounded,
                                            size: 19,
                                            color: item.quantity > 1 ? const Color(0xFF334155) : const Color(0xFFDC2626),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Container(
                                        constraints: const BoxConstraints(minWidth: 34),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                                        ),
                                        child: Text(
                                          '${item.quantity}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: Color(0xFF0F766E),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      InkWell(
                                        onTap: () {
                                          ref.read(cartProvider.notifier).updateQuantity(item.product.id, item.quantity + 1);
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: const Padding(
                                          padding: EdgeInsets.all(5),
                                          child: Icon(
                                            Icons.add_rounded,
                                            size: 19,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${item.totalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                              const SizedBox(height: 8),
                              IconButton(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogCtx) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      title: const Text('Remove from Cart?'),
                                      content: Text('Are you sure you want to remove "${item.product.name}" from your cart?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(dialogCtx, false),
                                          child: const Text('Keep in Cart'),
                                        ),
                                        FilledButton(
                                          onPressed: () => Navigator.pop(dialogCtx, true),
                                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                                          child: const Text('Remove'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    ref.read(cartProvider.notifier).removeProduct(item.product.id);
                                  }
                                },
                                icon: const Icon(Icons.delete_outline_rounded, size: 22),
                                color: const Color(0xFFDC2626),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Remove item',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal'),
                        Text('₹${total.toStringAsFixed(0)}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Payment'),
                        Text('Cash at Warehouse'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => context.push('/checkout'),
                      child: const Text('Proceed to Checkout'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
