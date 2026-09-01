import 'package:goodwin/models/product_model.dart';

class DemoProduct {
  const DemoProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.image,
    this.images = const [],
    required this.price,
    required this.originalPrice,
    required this.subtitle,
    required this.description,
    required this.tags,
    this.availableQty = 0,
    this.variants = const [],
  });

  final String id;
  final String name;
  final String category;
  final String image;
  final List<String> images;
  final double price;
  final double originalPrice;
  final String subtitle;
  final String description;
  final List<String> tags;
  final int availableQty;
  final List<ProductVariantModel> variants;

  bool get hasVariants => variants.isNotEmpty;

  /// Returns the total available quantity across all variants, or availableQty if no variants.
  int get totalAvailableQty {
    if (variants.isNotEmpty) {
      return variants.fold<int>(
        0,
        (sum, v) => sum + (v.availableQty > 0 ? v.availableQty : 0),
      );
    }
    return availableQty > 0 ? availableQty : 0;
  }

  factory DemoProduct.fromProductModel(
    ProductModel p, [
    String categoryName = '',
  ]) {
    final firstImg = p.images.isNotEmpty
        ? p.images.first
        : 'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?auto=format&fit=crop&w=900&q=80';
    return DemoProduct(
      id: p.id,
      name: p.name,
      category: categoryName.isNotEmpty
          ? categoryName
          : (p.categoryId.startsWith('cat_')
                ? p.categoryId.replaceAll('cat_', '').toUpperCase()
                : p.categoryId),
      image: firstImg,
      images: p.images.isNotEmpty ? p.images : [firstImg],
      price: p.wholesalePrice,
      originalPrice: p.mrp > 0 ? p.mrp : p.wholesalePrice * 1.5,
      subtitle: p.description.isNotEmpty ? p.description : p.name,
      description: p.description.isNotEmpty
          ? p.description
          : 'Quality wholesale product for shops, resellers, and daily trade.',
      tags: p.tags.isNotEmpty ? p.tags : ['Wholesale', 'Best seller'],
      availableQty: p.availableQty,
      variants: p.variants,
    );
  }
}
