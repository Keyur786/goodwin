import 'package:flutter/material.dart';

enum ProductSortOption {
  featured('Featured', Icons.auto_awesome_rounded),
  priceLowHigh('Price: Low to High', Icons.arrow_upward_rounded),
  priceHighLow('Price: High to Low', Icons.arrow_downward_rounded),
  discountHighLow('Highest Savings', Icons.percent_rounded),
  nameAZ('Name: A to Z', Icons.sort_by_alpha_rounded),
  nameZA('Name: Z to A', Icons.sort_by_alpha_rounded);

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
