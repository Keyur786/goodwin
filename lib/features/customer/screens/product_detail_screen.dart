import 'package:flutter/material.dart';
import 'package:goodwin/core/utils/quantity_dialog.dart';
import 'package:goodwin/core/utils/stock_formatter.dart';
import 'package:goodwin/models/demo_product.dart';
import 'package:goodwin/models/product_model.dart';
import 'package:goodwin/shared/widgets/full_screen_image_viewer.dart';
import 'package:goodwin/shared/widgets/product_image_widget.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.onToggleFavorite,
    required this.isFavorite,
    required this.onAddToCart,
    this.cartItemCount = 0,
    this.isAdmin = false,
    this.onOpenCart,
  });

  final DemoProduct product;
  final void Function(String) onToggleFavorite;
  final bool isFavorite;
  final void Function(
    DemoProduct, {
    int quantity,
    ProductVariantModel? variant,
  })
  onAddToCart;
  final int cartItemCount;
  final bool isAdmin;
  final VoidCallback? onOpenCart;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  int _currentImageIndex = 0;
  ProductVariantModel? _selectedVariant;
  late final PageController _imagePageController;
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.isFavorite;
    _imagePageController = PageController();
    if (widget.product.hasVariants) {
      _selectedVariant = widget.product.variants.firstWhere(
        (v) => v.availableQty > 0,
        orElse: () => widget.product.variants.first,
      );
    }
  }

  @override
  void didUpdateWidget(covariant ProductDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorite != widget.isFavorite) {
      _isFavorite = widget.isFavorite;
    }
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final activePrice = _selectedVariant?.wholesalePrice ?? product.price;
    final activeStock = _selectedVariant != null
        ? _selectedVariant!.availableQty
        : product.totalAvailableQty;

    // Use variant-specific images if available; otherwise fall back to product main images
    final variantImages = _selectedVariant?.images.where((s) => s.trim().isNotEmpty).toList() ?? [];
    final displayImages = variantImages.isNotEmpty
        ? variantImages
        : (product.images.isNotEmpty
            ? product.images
            : (product.image.isNotEmpty ? [product.image] : <String>[]));

    final isWideScreen = MediaQuery.of(context).size.width >= 700;
    final double mainImageHeight = isWideScreen ? 380.0 : 300.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isFavorite = !_isFavorite;
              });
              widget.onToggleFavorite(product.id);
            },
            icon: Icon(
              _isFavorite ? Icons.favorite : LucideIcons.heart,
              color: _isFavorite
                  ? Colors.red.shade600
                  : const Color(0xFF475569),
            ),
          ),
          if (widget.onOpenCart != null)
            IconButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onOpenCart!();
              },
              icon: widget.cartItemCount > 0
                  ? Badge.count(
                      count: widget.cartItemCount,
                      backgroundColor: const Color(0xFF2563EB),
                      textColor: Colors.white,
                      child: const Icon(
                        LucideIcons.shoppingBag,
                        color: Color(0xFF2563EB),
                      ),
                    )
                  : const Icon(
                      LucideIcons.shoppingBag,
                      color: Color(0xFF475569),
                    ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // Main Outer Card Container with clean border
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Showcase (Multi-Image Carousel or Single Frame)
                  if (displayImages.length > 1) ...[
                    Container(
                      height: mainImageHeight,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: () => _openFullScreenImageViewer(
                                context,
                                displayImages,
                                initialIndex: _currentImageIndex,
                                productName: product.name,
                              ),
                              child: PageView.builder(
                                controller: _imagePageController,
                                itemCount: displayImages.length,
                                onPageChanged: (idx) {
                                  setState(() => _currentImageIndex = idx);
                                },
                                itemBuilder: (ctx, i) {
                                  return Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Center(
                                      child: ProductImageWidget(
                                        imageSrc: displayImages[i],
                                        height: double.infinity,
                                        width: double.infinity,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          // Left arrow (Flipkart / Amazon style)
                          if (_currentImageIndex > 0)
                            Positioned(
                              left: 10,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: Material(
                                  color: Colors.white.withAlpha(235),
                                  shape: const CircleBorder(),
                                  elevation: 2,
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () {
                                      _imagePageController.previousPage(
                                        duration: const Duration(milliseconds: 250),
                                        curve: Curves.easeInOut,
                                      );
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(
                                        LucideIcons.chevronLeft,
                                        color: Color(0xFF1E293B),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Right arrow (Flipkart / Amazon style)
                          if (_currentImageIndex < displayImages.length - 1)
                            Positioned(
                              right: 10,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: Material(
                                  color: Colors.white.withAlpha(235),
                                  shape: const CircleBorder(),
                                  elevation: 2,
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () {
                                      _imagePageController.nextPage(
                                        duration: const Duration(milliseconds: 250),
                                        curve: Curves.easeInOut,
                                      );
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(
                                        LucideIcons.chevronRight,
                                        color: Color(0xFF1E293B),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Zoom / Tap to view button badge on top right
                          Positioned(
                            top: 10,
                            right: 12,
                            child: GestureDetector(
                              onTap: () => _openFullScreenImageViewer(
                                context,
                                displayImages,
                                initialIndex: _currentImageIndex,
                                productName: product.name,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(165),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      LucideIcons.maximize2,
                                      color: Colors.white,
                                      size: 13,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Full view',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Photo counter on bottom right
                          Positioned(
                            bottom: 10,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(165),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_currentImageIndex + 1} / ${displayImages.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Thumbnail row (Amazon / Flipkart style gallery)
                    SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: displayImages.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (ctx, i) {
                          final isSelected = _currentImageIndex == i;
                          return GestureDetector(
                            onTap: () {
                              _imagePageController.animateToPage(
                                i,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 64,
                              height: 64,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFFE2E8F0),
                                  width: isSelected ? 2.5 : 1.2,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF2563EB).withAlpha(45),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Center(
                                child: ProductImageWidget(
                                  imageSrc: displayImages[i],
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    GestureDetector(
                      onTap: () => _openFullScreenImageViewer(
                        context,
                        displayImages.isNotEmpty
                            ? displayImages
                            : [product.image],
                        initialIndex: 0,
                        productName: product.name,
                      ),
                      child: Container(
                        height: mainImageHeight,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Center(
                                child: ProductImageWidget(
                                  imageSrc: displayImages.isNotEmpty
                                      ? displayImages.first
                                      : product.image,
                                  height: double.infinity,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 10,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(165),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      LucideIcons.maximize2,
                                      color: Colors.white,
                                      size: 13,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Full view',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Category & Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Text(
                          'Wholesale Grade',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Variations Section (if available)
                  if (product.hasVariants) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Select Variation / Pack Size',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        if (_selectedVariant != null)
                          Flexible(
                            child: Text(
                              _selectedVariant!.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: product.variants.map((v) {
                          final isSelected = _selectedVariant?.id == v.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedVariant = v;
                                  _currentImageIndex = 0;
                                  if (_quantity > v.availableQty && v.availableQty > 0) {
                                    _quantity = v.availableQty;
                                  }
                                  if (_imagePageController.hasClients) {
                                    _imagePageController.jumpToPage(0);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFEFF6FF)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFFE2E8F0),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (v.images.isNotEmpty) ...[
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: ProductImageWidget(
                                          imageSrc: v.images.first,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          v.name,
                                          style: TextStyle(
                                            fontWeight: isSelected
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            fontSize: 13,
                                            color: isSelected
                                                ? const Color(0xFF2563EB)
                                                : const Color(0xFF1E293B),
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              '₹${v.wholesalePrice.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                                color: isSelected
                                                    ? const Color(0xFF2563EB)
                                                    : const Color(0xFF64748B),
                                              ),
                                            ),
                                            if (v.availableQty <= 0) ...[
                                              const SizedBox(width: 4),
                                              const Text(
                                                '• Out of stock',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFFDC2626),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Price Box with Accent Border
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFBFDBFE),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Wholesale Price',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${activePrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: activeStock > 0 ? Colors.white : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: activeStock > 0
                                  ? const Color(0xFFBFDBFE)
                                  : const Color(0xFFFCA5A5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                activeStock > 0
                                    ? LucideIcons.checkCircle
                                    : LucideIcons.circleX,
                                size: 16,
                                color: activeStock > 0
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFDC2626),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                activeStock > 0
                                    ? '${formatStockCount(activeStock, isAdmin: widget.isAdmin)} in stock'
                                    : 'Out of stock',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: activeStock > 0
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Specifications Box with Border
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Product Specifications',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Available Quantity',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                activeStock > 0
                                    ? '${formatStockCount(activeStock, isAdmin: widget.isAdmin)} units in stock'
                                    : 'Out of stock',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: activeStock > 0
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'Packaging',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              'Wholesale Sealed Pack',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'Direct Dispatch',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              'Katargam Warehouse',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description Box with Border
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Description & Quality',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product.description,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tags with Borders
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: product.tags
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '#$tag',
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 20),

                  // Quantity Selector with Direct Type Input
                  if (activeStock <= 0) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.ban,
                            size: 18,
                            color: Color(0xFFDC2626),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Currently Out of Stock',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(LucideIcons.shoppingBag, size: 18),
                      label: const Text(
                        'Out of Stock',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        disabledBackgroundColor: const Color(0xFFE2E8F0),
                        disabledForegroundColor: const Color(0xFF94A3B8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Select Quantity:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                'Max $activeStock available',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton.filledTonal(
                                onPressed: _quantity > 1
                                    ? () => setState(() => _quantity--)
                                    : null,
                                icon: const Icon(LucideIcons.minus, size: 20),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF2563EB),
                                  padding: const EdgeInsets.all(8),
                                  visualDensity: VisualDensity.standard,
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () async {
                                  final newQty = await showQuantityInputDialog(
                                    context: context,
                                    initialQuantity: _quantity,
                                    productName: product.name,
                                    maxQuantity: activeStock,
                                  );
                                  if (newQty != null) {
                                    setState(
                                      () => _quantity = newQty.clamp(1, activeStock),
                                    );
                                  }
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  constraints: const BoxConstraints(minWidth: 50),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFCBD5E1),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Text(
                                    '$_quantity',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                onPressed: _quantity < activeStock
                                    ? () => setState(() => _quantity++)
                                    : null,
                                icon: const Icon(LucideIcons.plus, size: 20),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF2563EB),
                                  padding: const EdgeInsets.all(8),
                                  visualDensity: VisualDensity.standard,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Add to Cart Button with dynamic quantity & total price
                    FilledButton.icon(
                      onPressed: () {
                        final clampedQty = _quantity.clamp(1, activeStock);
                        widget.onAddToCart(
                          product,
                          quantity: clampedQty,
                          variant: _selectedVariant,
                        );
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(LucideIcons.shoppingBag, size: 16),
                      label: Text(
                        'Add $_quantity ${_quantity == 1 ? "unit" : "units"} to Cart • ₹${(_quantity * activePrice).toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }
}

void _openFullScreenImageViewer(
  BuildContext context,
  List<String> images, {
  int initialIndex = 0,
  String productName = '',
}) {
  if (images.isEmpty) return;
  showDialog<void>(
    context: context,
    useSafeArea: false,
    barrierColor: Colors.black.withValues(alpha: 0.94),
    builder: (ctx) => FullScreenImageViewerDialog(
      images: images,
      initialIndex: initialIndex,
      productName: productName,
    ),
  );
}

/// Full-screen zoomable photo gallery dialog

