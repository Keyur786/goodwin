import 'package:flutter/material.dart';
import 'package:goodwin/core/utils/quantity_dialog.dart';
import 'package:goodwin/core/utils/stock_formatter.dart';
import 'package:goodwin/models/demo_product.dart';
import 'package:goodwin/shared/widgets/product_image_widget.dart';

class QuantityAddControls extends StatelessWidget {
  const QuantityAddControls({
    super.key,
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
    required this.onAdd,
    this.onSetQuantity,
    this.productName = '',
  });

  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onAdd;
  final ValueChanged<int>? onSetQuantity;
  final String productName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: onDecrease,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(
                    Icons.remove_rounded,
                    size: 16,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              InkWell(
                onTap: () async {
                  if (onSetQuantity != null) {
                    final newQty = await showQuantityInputDialog(
                      context: context,
                      initialQuantity: quantity,
                      productName: productName,
                    );
                    if (newQty != null) {
                      onSetQuantity!(newQty);
                    }
                  }
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 32),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFCBD5E1),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '$quantity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                ),
              ),
              InkWell(
                onTap: onIncrease,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 14),
            label: const Text(
              'Add',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
              minimumSize: const Size(0, 36),
              backgroundColor: const Color(0xFF0F766E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ModernProductCard extends StatelessWidget {
  const ModernProductCard({
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
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ProductImageWidget(
                  imageSrc: product.image,
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  product.category.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                product.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                  height: 1.25,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: onToggleFavorite,
                          icon: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFavorite
                                ? Colors.red.shade600
                                : const Color(0xFF94A3B8),
                            size: 22,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${product.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: product.availableQty > 0
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: product.availableQty > 0
                                  ? const Color(0xFF86EFAC)
                                  : const Color(0xFFFCA5A5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            product.availableQty > 0
                                ? 'Qty: ${formatStockCount(product.availableQty, isAdmin: isAdmin)}'
                                : 'Out of stock',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: product.availableQty > 0
                                  ? const Color(0xFF16A34A)
                                  : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    QuantityAddControls(
                      quantity: quantity <= 0 ? 1 : quantity,
                      onDecrease: () => onSetQuantity(quantity - 1),
                      onIncrease: () =>
                          onSetQuantity((quantity <= 0 ? 1 : quantity) + 1),
                      onSetQuantity: onSetQuantity,
                      productName: product.name,
                      onAdd: onAddToCart,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

