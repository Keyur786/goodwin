import 'package:flutter/material.dart';
import 'package:goodwin/core/services/firestore_product_repository.dart';
import 'package:goodwin/features/admin/dialogs/add_edit_product_dialog.dart';
import 'package:goodwin/models/product_model.dart';
import 'package:goodwin/shared/widgets/product_image_widget.dart';

class AdminProductManagerScreen extends StatefulWidget {
  const AdminProductManagerScreen({super.key});

  @override
  State<AdminProductManagerScreen> createState() =>
      _AdminProductManagerScreenState();
}

class _AdminProductManagerScreenState extends State<AdminProductManagerScreen> {
  final _productRepo = FirestoreProductRepository();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _stockFilter = 'All';
  String _adminSort = 'Default';

  final List<String> _categories = [
    'All',
    'Dry Fruits',
    'Spices',
    'Tea & Coffee',
    'Pulses & Grains',
    'Edible Oils',
    'Personal Care',
    'Snacks & Foods',
    'Household',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Product Manager',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => _openAddEditProductModal(context),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<ProductModel>>(
        stream: _productRepo.streamProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allProducts = snapshot.data ?? [];
          final dynamicCategories = <String>[
            'All',
            ..._categories.where((c) => c != 'All'),
          ];
          for (final p in allProducts) {
            final cat = p.categoryId.trim();
            if (cat.isNotEmpty &&
                !dynamicCategories.any(
                  (c) => c.toLowerCase() == cat.toLowerCase(),
                )) {
              dynamicCategories.add(cat);
            }
          }

          var products = List<ProductModel>.from(allProducts);

          // Filter by search query and category
          if (_selectedCategory != 'All') {
            products = products
                .where(
                  (p) =>
                      p.categoryId.toLowerCase() ==
                          _selectedCategory.toLowerCase() ||
                      p.tags.any(
                        (t) =>
                            t.toLowerCase() == _selectedCategory.toLowerCase(),
                      ),
                )
                .toList();
          }

          if (_stockFilter == 'In Stock (>10)') {
            products = products.where((p) => p.availableQty > 10).toList();
          } else if (_stockFilter == 'Low Stock (≤10)') {
            products = products
                .where((p) => p.availableQty > 0 && p.availableQty <= 10)
                .toList();
          } else if (_stockFilter == 'Out of Stock (0)') {
            products = products.where((p) => p.availableQty <= 0).toList();
          }

          if (_searchQuery.trim().isNotEmpty) {
            final tokens = _searchQuery.trim().toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
            products = products.where((p) {
              return tokens.every((token) {
                final inName = p.name.toLowerCase().contains(token);
                final inSku = p.sku.toLowerCase().contains(token);
                final inCategory = p.categoryId.toLowerCase().contains(token);
                final inTags = p.tags.any((t) => t.toLowerCase().contains(token));
                final inVariants = p.variants.any((v) =>
                    v.name.toLowerCase().contains(token) ||
                    v.sku.toLowerCase().contains(token));
                return inName || inSku || inCategory || inTags || inVariants;
              });
            }).toList();
          }

          // Apply Admin Sorting
          switch (_adminSort) {
            case 'Stock: Low to High':
              products.sort((a, b) => a.availableQty.compareTo(b.availableQty));
              break;
            case 'Stock: High to Low':
              products.sort((a, b) => b.availableQty.compareTo(a.availableQty));
              break;
            case 'Price: Low to High':
              products.sort(
                (a, b) => a.wholesalePrice.compareTo(b.wholesalePrice),
              );
              break;
            case 'Price: High to Low':
              products.sort(
                (a, b) => b.wholesalePrice.compareTo(a.wholesalePrice),
              );
              break;
            case 'Name: A-Z':
              products.sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );
              break;
            case 'Default':
            default:
              break;
          }

          return Column(
            children: [
              // Search & Filter Header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (v) =>
                          setState(() => _searchQuery = v.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText:
                            'Search products by name, SKU, or category...',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF0F766E),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Admin Sort & Stock Filter Action Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Admin Sort Dropdown Button
                          PopupMenuButton<String>(
                            initialValue: _adminSort,
                            onSelected: (val) =>
                                setState(() => _adminSort = val),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            itemBuilder: (ctx) =>
                                [
                                  'Default',
                                  'Stock: Low to High',
                                  'Stock: High to Low',
                                  'Price: Low to High',
                                  'Price: High to Low',
                                  'Name: A-Z',
                                ].map((opt) {
                                  return PopupMenuItem(
                                    value: opt,
                                    child: Row(
                                      children: [
                                        if (_adminSort == opt)
                                          const Icon(
                                            Icons.check_rounded,
                                            size: 16,
                                            color: Color(0xFF0F766E),
                                          )
                                        else
                                          const SizedBox(width: 16),
                                        const SizedBox(width: 8),
                                        Text(
                                          opt,
                                          style: TextStyle(
                                            fontWeight: _adminSort == opt
                                                ? FontWeight.w800
                                                : FontWeight.w500,
                                            color: _adminSort == opt
                                                ? const Color(0xFF0F766E)
                                                : const Color(0xFF1E293B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _adminSort != 'Default'
                                    ? const Color(0xFFCCFBF1)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _adminSort != 'Default'
                                      ? const Color(0xFF0F766E)
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.sort_rounded,
                                    size: 14,
                                    color: _adminSort != 'Default'
                                        ? const Color(0xFF0F766E)
                                        : const Color(0xFF475569),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Sort: $_adminSort',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _adminSort != 'Default'
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: _adminSort != 'Default'
                                          ? const Color(0xFF0F766E)
                                          : const Color(0xFF334155),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_drop_down,
                                    size: 16,
                                    color: Color(0xFF64748B),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Stock Filter Chips
                          ...[
                            'All',
                            'In Stock (>10)',
                            'Low Stock (≤10)',
                            'Out of Stock (0)',
                          ].map((stockOpt) {
                            final isSelected = _stockFilter == stockOpt;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(stockOpt),
                                selected: isSelected,
                                selectedColor: const Color(0xFFCCFBF1),
                                labelStyle: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? const Color(0xFF0F766E)
                                      : const Color(0xFF475569),
                                ),
                                onSelected: (_) =>
                                    setState(() => _stockFilter = stockOpt),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Categories Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: dynamicCategories.map((cat) {
                          final isSelected =
                              _selectedCategory.toLowerCase() ==
                              cat.toLowerCase();
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(cat),
                              selected: isSelected,
                              selectedColor: const Color(0xFFCCFBF1),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? const Color(0xFF0F766E)
                                    : const Color(0xFF475569),
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: 12,
                              ),
                              onSelected: (_) =>
                                  setState(() => _selectedCategory = cat),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Product List
              Expanded(
                child: products.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No products match "$_searchQuery"'
                                    : 'No products in catalog yet',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () =>
                                    _openAddEditProductModal(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Add First Product'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F766E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemCount: products.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final prod = products[index];
                          final imageUrl = prod.images.isNotEmpty
                              ? prod.images.first
                              : '';

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ProductImageWidget(
                                    imageSrc: imageUrl,
                                    width: 60,
                                    height: 60,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          prod.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              constraints: const BoxConstraints(
                                                minWidth: 32,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                prod.sku.isNotEmpty
                                                    ? prod.sku
                                                    : 'SKU: N/A',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Stock: ${prod.availableQty}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: prod.availableQty > 5
                                                    ? const Color(0xFF16A34A)
                                                    : Colors.orange.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '₹${prod.wholesalePrice.toStringAsFixed(0)} wholesale',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF0F766E),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Edit Product',
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 20,
                                          color: Color(0xFF0F766E),
                                        ),
                                        onPressed: () =>
                                            _openAddEditProductModal(
                                              context,
                                              product: prod,
                                            ),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete Product',
                                        icon: Icon(
                                          Icons.delete_outline_rounded,
                                          size: 20,
                                          color: Colors.red.shade700,
                                        ),
                                        onPressed: () => _confirmDeleteProduct(
                                          context,
                                          prod,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openAddEditProductModal(BuildContext context, {ProductModel? product}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AddEditProductDialog(product: product),
    );
  }

  Future<void> _confirmDeleteProduct(
    BuildContext context,
    ProductModel product,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text(
          'Are you sure you want to remove "${product.name}" from the wholesale catalog?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _productRepo.deleteProduct(product.id);
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Removed ${product.name} from catalog')),
          );
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Error deleting product: $e')),
          );
        }
      }
    }
  }
}


