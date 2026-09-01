class ProductVariantModel {
  const ProductVariantModel({
    required this.id,
    required this.name,
    this.sku = '',
    required this.wholesalePrice,
    required this.mrp,
    required this.availableQty,
    this.images = const [],
  });

  final String id;
  final String name;
  final String sku;
  final double wholesalePrice;
  final double mrp;
  final int availableQty;
  final List<String> images;

  bool get isOutOfStock => availableQty <= 0;

  factory ProductVariantModel.fromJson(Map<String, dynamic> json) {
    return ProductVariantModel(
      id: json['id']?.toString() ?? 'var_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name']?.toString() ?? 'Standard',
      sku: json['sku']?.toString() ?? '',
      wholesalePrice: (json['wholesalePrice'] as num?)?.toDouble() ?? 0.0,
      mrp: (json['mrp'] as num?)?.toDouble() ?? 0.0,
      availableQty: (json['availableQty'] as num?)?.toInt() ?? 0,
      images: List<String>.from(json['images'] as List? ?? const []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'wholesalePrice': wholesalePrice,
      'mrp': mrp,
      'availableQty': availableQty,
      'images': images,
    };
  }
}

class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    required this.sku,
    required this.categoryId,
    required this.description,
    required this.wholesalePrice,
    required this.mrp,
    required this.minimumOrderQty,
    required this.availableQty,
    required this.lowStockThreshold,
    required this.images,
    required this.isActive,
    required this.isFeatured,
    required this.isBestSeller,
    required this.createdAt,
    this.gstRate,
    this.variantName,
    this.tags = const [],
    this.variants = const [],
  });

  final String id;
  final String name;
  final String sku;
  final String categoryId;
  final String description;
  final double wholesalePrice;
  final double mrp;
  final int minimumOrderQty;
  final int availableQty;
  final int lowStockThreshold;
  final List<String> images;
  final bool isActive;
  final bool isFeatured;
  final bool isBestSeller;
  final DateTime createdAt;
  final double? gstRate;
  final String? variantName;
  final List<String> tags;
  final List<ProductVariantModel> variants;

  bool get hasVariants => variants.isNotEmpty;
  bool get isLowStock => availableQty <= lowStockThreshold;
  bool get isOutOfStock => availableQty <= 0;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final rawVariants = json['variants'] as List? ?? const [];
    final parsedVariants = rawVariants.map((item) {
      final map = item is Map<String, dynamic>
          ? item
          : (item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{});
      return ProductVariantModel.fromJson(map);
    }).toList();

    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      sku: json['sku'] as String,
      categoryId: json['categoryId'] as String,
      description: json['description'] as String? ?? '',
      wholesalePrice: (json['wholesalePrice'] as num?)?.toDouble() ?? 0,
      mrp: (json['mrp'] as num?)?.toDouble() ?? 0,
      minimumOrderQty: (json['minimumOrderQty'] as num?)?.toInt() ?? 1,
      availableQty: (json['availableQty'] as num?)?.toInt() ?? 0,
      lowStockThreshold: (json['lowStockThreshold'] as num?)?.toInt() ?? 5,
      images: List<String>.from(json['images'] as List? ?? const []),
      isActive: json['isActive'] as bool? ?? true,
      isFeatured: json['isFeatured'] as bool? ?? false,
      isBestSeller: json['isBestSeller'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      gstRate: (json['gstRate'] as num?)?.toDouble(),
      variantName: json['variantName'] as String?,
      tags: List<String>.from(json['tags'] as List? ?? const []),
      variants: parsedVariants,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'categoryId': categoryId,
      'description': description,
      'wholesalePrice': wholesalePrice,
      'mrp': mrp,
      'minimumOrderQty': minimumOrderQty,
      'availableQty': availableQty,
      'lowStockThreshold': lowStockThreshold,
      'images': images,
      'isActive': isActive,
      'isFeatured': isFeatured,
      'isBestSeller': isBestSeller,
      'createdAt': createdAt.toIso8601String(),
      'gstRate': gstRate,
      'variantName': variantName,
      'tags': tags,
      'variants': variants.map((v) => v.toJson()).toList(),
    };
  }
}
