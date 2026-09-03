import 'package:goodwin/core/data/demo_data.dart';
import 'package:goodwin/models/order_model.dart';

/// Helper to reliably resolve a product's image for any order item,
/// using the item's stored imageUrl or catalog fallback.
String resolveOrderItemImage(OrderItemModel item) {
  if (item.imageUrl != null && item.imageUrl!.trim().isNotEmpty) {
    return item.imageUrl!.trim();
  }

  // Fallback match from demo products catalog
  for (final p in DemoData.products) {
    if (p.id == item.productId ||
        p.name.trim().toLowerCase() == item.productName.trim().toLowerCase()) {
      if (p.images.isNotEmpty) return p.images.first;
    }
  }

  return '';
}
