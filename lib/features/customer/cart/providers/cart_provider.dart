import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goodwin/models/cart_item_model.dart';
import 'package:goodwin/models/product_model.dart';

class CartNotifier extends Notifier<List<CartItemModel>> {
  @override
  List<CartItemModel> build() {
    return const [];
  }

  void addProduct(ProductModel product, {int quantity = 1, String? variant}) {
    final existing = state.where((item) => item.product.id == product.id).toList();
    if (existing.isNotEmpty) {
      state = [
        for (final item in state)
          if (item.product.id == product.id)
            item.copyWith(quantity: item.quantity + quantity)
          else
            item,
      ];
      return;
    }

    state = [
      ...state,
      CartItemModel(product: product, quantity: quantity, variant: variant),
    ];
  }

  void updateQuantity(String productId, int newQuantity) {
    if (newQuantity <= 0) {
      removeProduct(productId);
      return;
    }

    state = [
      for (final item in state)
        if (item.product.id == productId)
          item.copyWith(quantity: newQuantity)
        else
          item,
    ];
  }

  void removeProduct(String productId) {
    state = state.where((item) => item.product.id != productId).toList();
  }

  void clear() {
    state = const [];
  }
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItemModel>>(() => CartNotifier());

final cartTotalProvider = Provider<double>((ref) {
  final items = ref.watch(cartProvider);
  return items.fold(0.0, (sum, item) => sum + item.totalPrice);
});

final cartItemCountProvider = Provider<int>((ref) {
  final items = ref.watch(cartProvider);
  return items.fold(0, (sum, item) => sum + item.quantity);
});

