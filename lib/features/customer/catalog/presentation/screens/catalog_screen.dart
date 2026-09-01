import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goodwin/features/customer/cart/providers/cart_provider.dart';
import 'package:goodwin/features/customer/catalog/providers/catalog_provider.dart';
import 'package:goodwin/models/product_model.dart';

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(catalogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Products'),
        actions: [
          IconButton(
            onPressed: () => context.push('/cart'),
            icon: ref.watch(cartItemCountProvider) > 0
                ? Badge.count(
                    count: ref.watch(cartItemCountProvider),
                    backgroundColor: const Color(0xFF0F766E),
                    textColor: Colors.white,
                    child: const Icon(Icons.shopping_bag_rounded),
                  )
                : const Icon(Icons.shopping_bag_outlined),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: products.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final product = products[index];
          return ProductCard(product: product);
        },
      ),
    );
  }
}

class ProductCard extends ConsumerWidget {
  const ProductCard({super.key, required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoriteProductIdsProvider).contains(product.id);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                product.images.first,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  width: 100,
                  height: 100,
                  child: Center(child: Icon(Icons.image_not_supported_outlined)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        key: ValueKey('favorite-toggle-${product.id}'),
                        onPressed: () => ref.read(favoriteProductIdsProvider.notifier).toggle(product.id),
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('SKU: ${product.sku}', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('₹${product.wholesalePrice}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
                  const SizedBox(height: 8),
                  Text(
                    product.availableQty > 0
                        ? 'In Stock: ${product.availableQty > 100 ? "100+" : product.availableQty}'
                        : 'Out of stock',
                    style: TextStyle(
                      color: product.availableQty > 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: product.availableQty > 0
                            ? () {
                                ref.read(cartProvider.notifier).addProduct(product);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${product.name} added to cart')),
                                );
                              }
                            : null,
                        child: Text(product.availableQty > 0 ? 'Add' : 'Out of Stock'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => context.push('/product', extra: product),
                        child: const Text('Details'),
                      ),
                    ],
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
