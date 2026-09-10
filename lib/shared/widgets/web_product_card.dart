import 'package:flutter/material.dart';
import 'package:goodwin/core/utils/quantity_dialog.dart';
import 'package:goodwin/core/utils/stock_formatter.dart';
import 'package:goodwin/models/demo_product.dart';
import 'package:goodwin/shared/widgets/product_image_widget.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// A modern e-commerce product card designed for multi-column website grids on desktop and tablet
class WebProductCard extends StatefulWidget {
  const WebProductCard({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.quantity,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onSetQuantity,
    required this.onAddToCart,
    this.isAdmin = false,
  });

  final DemoProduct product;
  final bool isFavorite;
  final int quantity;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final ValueChanged<int> onSetQuantity;
  final VoidCallback onAddToCart;
  final bool isAdmin;

  @override
  State<WebProductCard> createState() => _WebProductCardState();
}

class _WebProductCardState extends State<WebProductCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final margin = product.originalPrice > product.price
        ? (((product.originalPrice - product.price) / product.originalPrice) * 100).round()
        : 0;
    final totalStock = product.totalAvailableQty;
    final isOutOfStock = totalStock <= 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            width: _isHovered ? 1.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? const Color(0xFF2563EB).withAlpha(35)
                  : Colors.black.withAlpha(8),
              blurRadius: _isHovered ? 16 : 8,
              offset: Offset(0, _isHovered ? 6 : 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Product Image with overlay badges
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      color: const Color(0xFFF8FAFC),
                      child: ProductImageWidget(
                        imageSrc: product.image,
                        fit: BoxFit.cover,
                        height: 180,
                        width: double.infinity,
                      ),
                    ),
                  ),

                  // Wholesale Discount Margin Badge (Top Left)
                  if (margin > 0)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(30),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          '$margin% Margin',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),

                  // Favorite Button (Top Right)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.white.withAlpha(235),
                      shape: const CircleBorder(),
                      elevation: 1,
                      child: InkWell(
                        onTap: widget.onToggleFavorite,
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Icon(
                            widget.isFavorite ? LucideIcons.heart : LucideIcons.heart,
                            size: 16,
                            color: widget.isFavorite
                                ? const Color(0xFFE11D48)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Stock Status Badge (Bottom Right of Image)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? const Color(0xFFFEF2F2)
                            : (totalStock < 20
                                ? const Color(0xFFFFFBEB)
                                : const Color(0xFFF0FDF4)),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isOutOfStock
                              ? const Color(0xFFFCA5A5)
                              : (totalStock < 20
                                  ? const Color(0xFFFDE68A)
                                  : const Color(0xFFBBF7D0)),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        isOutOfStock
                            ? 'Out of Stock'
                            : (totalStock < 20
                                ? 'Low Stock ($totalStock)'
                                : 'Stock: ${formatStockCount(totalStock, isAdmin: widget.isAdmin)}'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isOutOfStock
                              ? const Color(0xFFDC2626)
                              : (totalStock < 20
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF15803D)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // 2. Product Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Tag
                      if (product.category.isNotEmpty)
                        Text(
                          product.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: Color(0xFF2563EB),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 3),

                      // Title
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const Spacer(),

                      // Price Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '₹${product.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (product.originalPrice > product.price) ...[
                            Text(
                              '₹${product.originalPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF94A3B8),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'MRP',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Quantity Stepper + Add Button
                      if (isOutOfStock)
                        Container(
                          width: double.infinity,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Currently Unavailable',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            // Quantity Controls
                            Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: widget.quantity > 1
                                        ? () => widget.onSetQuantity(widget.quantity - 1)
                                        : null,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      child: Icon(
                                        LucideIcons.minus,
                                        size: 15,
                                        color: widget.quantity > 1
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () async {
                                      final newQty = await showQuantityInputDialog(
                                        context: context,
                                        initialQuantity: widget.quantity,
                                        productName: product.name,
                                        maxQuantity: totalStock,
                                      );
                                      if (newQty != null) {
                                        widget.onSetQuantity(newQty);
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Text(
                                        '${widget.quantity}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13.5,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: widget.quantity < totalStock
                                        ? () => widget.onSetQuantity(widget.quantity + 1)
                                        : null,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      child: Icon(
                                        LucideIcons.plus,
                                        size: 15,
                                        color: widget.quantity < totalStock
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Add to cart button
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: widget.onAddToCart,
                                icon: const Icon(LucideIcons.shoppingBag, size: 14),
                                label: const Text(
                                  'Add',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  minimumSize: const Size(0, 36),
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
