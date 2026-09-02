import 'package:flutter/material.dart';
import 'package:goodwin/core/services/firestore_order_repository.dart';
import 'package:goodwin/core/services/firestore_product_repository.dart';
import 'package:goodwin/core/utils/quantity_dialog.dart';
import 'package:goodwin/models/order_model.dart';
import 'package:goodwin/models/product_model.dart';
import 'package:goodwin/shared/widgets/product_image_widget.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class EditOrderDialog extends StatefulWidget {
  final OrderModel order;
  final VoidCallback onOrderUpdated;

  const EditOrderDialog({
    super.key,
    required this.order,
    required this.onOrderUpdated,
  });

  @override
  State<EditOrderDialog> createState() => _EditOrderDialogState();
}

class _EditOrderDialogState extends State<EditOrderDialog> {
  late List<OrderItemModel> _items;
  bool _isSaving = false;
  final _productRepo = FirestoreProductRepository();
  List<ProductModel> _catalogProducts = [];

  @override
  void initState() {
    super.initState();
    _items = widget.order.items
        .map(
          (i) => OrderItemModel(
            productId: i.productId,
            productName: i.productName,
            sku: i.sku,
            variant: i.variant,
            unitPrice: i.unitPrice,
            quantity: i.quantity,
          ),
        )
        .toList();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final prods = await _productRepo.getProducts();
      if (mounted) {
        setState(() {
          _catalogProducts = prods;
        });
      }
    } catch (_) {}
  }

  double get _totalAmount {
    return _items.fold(0, (sum, item) => sum + item.totalPrice);
  }

  void _updateQuantity(int index, int newQty) {
    setState(() {
      if (newQty <= 0) {
        _items.removeAt(index);
      } else {
        _items[index] = _items[index].copyWith(quantity: newQty);
      }
    });
  }

  void _addProductToOrder(ProductModel product) {
    setState(() {
      final existingIndex = _items.indexWhere(
        (item) => item.productId == product.id,
      );
      if (existingIndex != -1) {
        _items[existingIndex] = _items[existingIndex].copyWith(
          quantity: _items[existingIndex].quantity + 1,
        );
      } else {
        _items.add(
          OrderItemModel(
            productId: product.id,
            productName: product.name,
            sku: product.sku,
            unitPrice: product.wholesalePrice,
            quantity: 1,
          ),
        );
      }
    });
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;

    if (_items.isEmpty) {
      final confirmDelete = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Delete Order?'),
          content: const Text(
            'You have removed all items. This will cancel and permanently delete this order.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Editing'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete Order'),
            ),
          ],
        ),
      );

      if (confirmDelete != true) return;

      setState(() => _isSaving = true);
      try {
        await FirestoreOrderRepository().deleteOrder(widget.order.id);
        if (mounted) {
          Navigator.pop(context);
          widget.onOrderUpdated();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order #${widget.order.orderNumber} cancelled.'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete order: $e')));
        }
      }
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirestoreOrderRepository().updateOrder(
        orderId: widget.order.id,
        items: _items,
        totalAmount: _totalAmount,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onOrderUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order #${widget.order.orderNumber} updated successfully.',
            ),
            backgroundColor: const Color(0xFF2563EB),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update order: $e')));
      }
    }
  }

  Future<void> _deleteOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.trash2,
                color: Colors.red.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Delete Order?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete order #${widget.order.orderNumber}? This will remove the order permanently.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Order'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Order'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      try {
        await FirestoreOrderRepository().deleteOrder(widget.order.id);
        if (mounted) {
          Navigator.pop(context);
          widget.onOrderUpdated();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Order #${widget.order.orderNumber} deleted successfully.',
              ),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete order: $e')));
        }
      }
    }
  }

  void _showAddProductPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String searchQuery = '';
        final searchController = TextEditingController();

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final filteredProducts = _catalogProducts.where((p) {
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              return p.name.toLowerCase().contains(q) ||
                  p.sku.toLowerCase().contains(q) ||
                  p.categoryId.toLowerCase().contains(q) ||
                  p.tags.any((t) => t.toLowerCase().contains(q));
            }).toList();

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Add Products to Order',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(LucideIcons.x),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: TextField(
                        controller: searchController,
                        onChanged: (val) {
                          setSheetState(() {
                            searchQuery = val.trim();
                          });
                        },
                        decoration: InputDecoration(
                          hintText:
                              'Search by product name, SKU, or category...',
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                          prefixIcon: const Icon(
                            LucideIcons.search,
                            color: Color(0xFF2563EB),
                            size: 22,
                          ),
                          suffixIcon: searchQuery.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    searchController.clear();
                                    setSheetState(() {
                                      searchQuery = '';
                                    });
                                  },
                                  icon: const Icon(
                                    LucideIcons.x,
                                    size: 18,
                                  ),
                                ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF2563EB),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 12),
                    Expanded(
                      child: filteredProducts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    LucideIcons.searchX,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    searchQuery.isEmpty
                                        ? 'No products available'
                                        : 'No products match "$searchQuery"',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredProducts.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 12),
                              itemBuilder: (_, idx) {
                                final prod = filteredProducts[idx];
                                final imageUrl = prod.images.isNotEmpty
                                    ? prod.images.first
                                    : '';
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: ProductImageWidget(
                                    imageSrc: imageUrl,
                                    width: 48,
                                    height: 48,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  title: Text(
                                    prod.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '₹${prod.wholesalePrice.toStringAsFixed(0)} • Stock: ${prod.availableQty}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  trailing: FilledButton.tonalIcon(
                                    onPressed: () {
                                      _addProductToOrder(prod);
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Added ${prod.name} to order',
                                          ),
                                          duration: const Duration(seconds: 1),
                                          backgroundColor: const Color(
                                            0xFF2563EB,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(LucideIcons.plus, size: 16),
                                    label: const Text('Add'),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 620, maxWidth: 500),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Edit Order',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      widget.order.orderNumber,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.info, size: 16, color: Color(0xFF2563EB)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'You can edit item quantities until order is delivered / picked up.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            LucideIcons.shoppingBag,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No items in order',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Add items or save to cancel order.',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const Divider(height: 16),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${item.unitPrice.toStringAsFixed(0)} each • Total: ₹${item.totalPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => _updateQuantity(
                                      index,
                                      item.quantity - 1,
                                    ),
                                    icon: Icon(
                                      item.quantity == 1
                                          ? LucideIcons.trash2
                                          : LucideIcons.minus,
                                      size: 18,
                                      color: item.quantity == 1
                                          ? Colors.red
                                          : const Color(0xFF2563EB),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () async {
                                      final newQty =
                                          await showQuantityInputDialog(
                                            context: context,
                                            initialQuantity: item.quantity,
                                            productName: item.productName,
                                          );
                                      if (newQty != null) {
                                        _updateQuantity(index, newQty);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
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
                                        '${item.quantity}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _updateQuantity(
                                      index,
                                      item.quantity + 1,
                                    ),
                                    icon: const Icon(
                                      LucideIcons.plus,
                                      size: 18,
                                      color: Color(0xFF2563EB),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _showAddProductPicker,
              icon: const Icon(LucideIcons.circlePlus, size: 18),
              label: const Text('Add More Products'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 42),
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFF2563EB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Updated Total:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '₹${_totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  tooltip: 'Delete Order',
                  onPressed: _isSaving ? null : _deleteOrder,
                  icon: Icon(
                    LucideIcons.trash2,
                    color: Colors.red.shade700,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    padding: const EdgeInsets.all(10),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _saveChanges,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


