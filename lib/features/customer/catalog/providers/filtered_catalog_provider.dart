import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goodwin/core/services/demo_repository.dart';
import 'package:goodwin/models/product_model.dart';

final filteredCatalogProvider = Provider<List<ProductModel>>((ref) {
  final products = appRepositoryProvider.getProducts();
  return products.where((product) => product.isActive).toList();
});
