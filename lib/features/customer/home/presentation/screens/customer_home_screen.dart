import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goodwin/features/customer/catalog/providers/catalog_provider.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(featuredProductsProvider);
    final bestSellers = ref.watch(bestSellerProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goodwin'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Wholesale marketplace', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search in thousands of products',
            ),
          ),
          const SizedBox(height: 20),
          const Text('Featured products', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: featured.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final product = featured[index];
                final isFavorite = ref.watch(favoriteProductIdsProvider).contains(product.id);
                return SizedBox(
                  width: 150,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const SizedBox(),
                              IconButton(
                                key: ValueKey('favorite-toggle-${product.id}'),
                                onPressed: () => ref.read(favoriteProductIdsProvider.notifier).toggle(product.id),
                                icon: Icon(
                                  isFavorite ? Icons.favorite : Icons.favorite_border,
                                  color: isFavorite ? Colors.red : null,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              product.images.first,
                              height: 70,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const SizedBox(height: 70, child: Center(child: Icon(Icons.image_not_supported_outlined, size: 24))),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('₹${product.wholesalePrice}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          const Text('Best sellers', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...bestSellers.map((product) {
            final isFavorite = ref.watch(favoriteProductIdsProvider).contains(product.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Image.network(
                  product.images.first,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported_outlined),
                ),
                title: Text(product.name),
                subtitle: Text('SKU: ${product.sku}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('₹${product.wholesalePrice}'),
                    const SizedBox(width: 8),
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
              ),
            );
          }),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.category_outlined), label: 'Categories'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), label: 'Cart'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
        onDestinationSelected: (index) {
          switch (index) {
            case 1:
              context.push('/catalog');
              break;
            case 2:
              context.push('/orders');
              break;
            case 3:
              context.push('/cart');
              break;
            case 4:
              context.push('/profile');
              break;
            default:
              break;
          }
        },
      ),
    );
  }
}
