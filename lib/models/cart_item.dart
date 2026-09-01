import 'package:goodwin/models/demo_product.dart';
import 'package:goodwin/models/product_model.dart';

class CartItem {
  final DemoProduct product;
  int quantity;
  final ProductVariantModel? selectedVariant;

  CartItem({
    required this.product,
    required this.quantity,
    this.selectedVariant,
  });

  double get unitPrice => selectedVariant?.wholesalePrice ?? product.price;
  double get totalPrice => unitPrice * quantity;
  String get displayName => selectedVariant != null
      ? '${product.name} (${selectedVariant!.name})'
      : product.name;
  String get displayImage {
    if (selectedVariant != null && selectedVariant!.images.isNotEmpty) {
      return selectedVariant!.images.first;
    }
    return product.image;
  }
}
