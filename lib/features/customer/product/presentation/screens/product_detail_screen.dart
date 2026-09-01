import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goodwin/features/customer/cart/providers/cart_provider.dart';
import 'package:goodwin/models/product_model.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, this.product});

  final ProductModel? product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItemCount = ref.watch(cartItemCountProvider);
    final currentProduct = product ?? ProductModel(
      id: 'demo',
      name: 'Pick a product',
      sku: 'N/A',
      categoryId: '',
      description: 'Product details are unavailable.',
      wholesalePrice: 0,
      mrp: 0,
      minimumOrderQty: 1,
      availableQty: 0,
      lowStockThreshold: 0,
      images: const [],
      isActive: true,
      isFeatured: false,
      isBestSeller: false,
      createdAt: DateTime.now(),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          IconButton(
            onPressed: () => context.push('/cart'),
            icon: cartItemCount > 0
                ? Badge.count(
                    count: cartItemCount,
                    backgroundColor: const Color(0xFF0F766E),
                    textColor: Colors.white,
                    child: const Icon(Icons.shopping_bag_rounded),
                  )
                : const Icon(Icons.shopping_bag_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: currentProduct.images.isNotEmpty
                        ? Image.network(
                            currentProduct.images.first,
                            height: 250,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const SizedBox(
                              height: 250,
                              child: Center(child: Icon(Icons.image_not_supported_outlined, size: 48)),
                            ),
                          )
                        : const SizedBox(
                            height: 250,
                            child: Center(
                              child: Icon(Icons.shopping_bag_outlined, size: 64),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDFA),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF99F6E4), width: 1),
                        ),
                        child: Text(
                          (currentProduct.categoryId.isNotEmpty ? currentProduct.categoryId : 'WHOLESALE').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F766E),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          'SKU: ${currentProduct.sku}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentProduct.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF99F6E4), width: 1.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Wholesale Price',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${currentProduct.wholesalePrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF99F6E4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                currentProduct.availableQty > 0 ? Icons.check_circle_rounded : Icons.cancel_outlined,
                                size: 16,
                                color: currentProduct.availableQty > 0 ? const Color(0xFF16A34A) : Colors.red,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                currentProduct.availableQty > 0
                                    ? '${currentProduct.availableQty > 100 ? "100+" : currentProduct.availableQty} in stock'
                                    : 'Out of stock',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: currentProduct.availableQty > 0 ? const Color(0xFF16A34A) : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Product Specifications',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Available Quantity', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                            Text(
                              currentProduct.availableQty > 0
                                  ? '${currentProduct.availableQty > 100 ? "100+" : currentProduct.availableQty} units in stock'
                                  : 'Out of stock',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: currentProduct.availableQty > 0
                                    ? const Color(0xFF16A34A)
                                    : Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('Direct Dispatch', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                            Text('Katargam Warehouse', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Description & Quality',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentProduct.description,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: currentProduct.availableQty <= 0
                        ? null
                        : () {
                            ref.read(cartProvider.notifier).addProduct(currentProduct);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${currentProduct.name} added to cart'),
                                backgroundColor: const Color(0xFF0F766E),
                              ),
                            );
                          },
                    icon: const Icon(Icons.shopping_cart_outlined),
                    label: const Text('Add to Cart', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: const Color(0xFF0F766E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
