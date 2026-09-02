import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum ProductSortOption {
  featured('Featured', LucideIcons.sparkles),
  categoryAZ('Category: A to Z', LucideIcons.layoutGrid),
  priceLowHigh('Price: Low to High', LucideIcons.arrowUp),
  priceHighLow('Price: High to Low', LucideIcons.arrowDown),
  discountHighLow('Highest Savings', LucideIcons.percent),
  nameAZ('Name: A to Z', LucideIcons.arrowDownAZ),
  nameZA('Name: Z to A', LucideIcons.arrowUpAZ);

  final String label;
  final IconData icon;
  const ProductSortOption(this.label, this.icon);
}

class ProductFilterCriteria {
  final double? minPrice;
  final double? maxPrice;
  final bool inStockOnly;
  final bool featuredOnly;
  final bool bestSellerOnly;

  const ProductFilterCriteria({
    this.minPrice,
    this.maxPrice,
    this.inStockOnly = false,
    this.featuredOnly = false,
    this.bestSellerOnly = false,
  });

  bool get isDefault =>
      minPrice == null &&
      maxPrice == null &&
      !inStockOnly &&
      !featuredOnly &&
      !bestSellerOnly;

  int get activeFiltersCount {
    int count = 0;
    if (minPrice != null || maxPrice != null) count++;
    if (inStockOnly) count++;
    if (featuredOnly) count++;
    if (bestSellerOnly) count++;
    return count;
  }
}
