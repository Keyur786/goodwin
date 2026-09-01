import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goodwin/core/services/demo_repository.dart';
import 'package:goodwin/models/product_model.dart';

class FavoriteProductIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void toggle(String productId) {
    final updated = {...state};
    if (updated.contains(productId)) {
      updated.remove(productId);
    } else {
      updated.add(productId);
    }
    state = updated;
  }

  bool isFavorite(String productId) => state.contains(productId);
}

final favoriteProductIdsProvider = NotifierProvider<FavoriteProductIdsNotifier, Set<String>>(
  () => FavoriteProductIdsNotifier(),
);

final catalogProvider = Provider<List<ProductModel>>((ref) {
  return appRepositoryProvider.getProducts().where((product) => product.isActive).toList();
});

final featuredProductsProvider = Provider<List<ProductModel>>((ref) {
  return appRepositoryProvider
      .getProducts()
      .where((product) => product.isFeatured && product.isActive)
      .toList();
});

final bestSellerProductsProvider = Provider<List<ProductModel>>((ref) {
  return appRepositoryProvider
      .getProducts()
      .where((product) => product.isBestSeller && product.isActive)
      .toList();
});
