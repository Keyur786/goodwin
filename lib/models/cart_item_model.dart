import 'package:goodwin/models/product_model.dart';

class CartItemModel {
  const CartItemModel({
    required this.product,
    required this.quantity,
    this.variant,
  });

  final ProductModel product;
  final int quantity;
  final String? variant;

  double get unitPrice => product.wholesalePrice;
  double get totalPrice => unitPrice * quantity;

  CartItemModel copyWith({ProductModel? product, int? quantity, String? variant}) {
    return CartItemModel(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      variant: variant ?? this.variant,
    );
  }
}
