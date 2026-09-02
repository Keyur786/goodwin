import 'package:flutter/material.dart';
import 'package:goodwin/core/services/firestore_product_repository.dart';
import 'package:goodwin/features/admin/dialogs/add_edit_product_dialog.dart';
import 'package:goodwin/features/admin/dialogs/admin_pin_dialog.dart';
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
  int _currentTab = 0; // 0 = Active Products, 1 = Recycle Bin
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
                  color: const Color(0xFF2563EB),
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
        stream: _productRepo.streamAllProductsForAdmin(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allProducts = snapshot.data ?? [];
          final activeProductsList =
              allProducts.where((p) => !p.isDeleted).toList();
          final recycledProductsList =
              allProducts.where((p) => p.isDeleted).toList();

          final dynamicCategories = <String>[
            'All',
            ..._categories.where((c) => c != 'All'),
          ];
          for (final p in activeProductsList) {
            final cat = p.categoryId.trim();
            if (cat.isNotEmpty &&
                !dynamicCategories.any(
                  (c) => c.toLowerCase() == cat.toLowerCase(),
                )) {
              dynamicCategories.add(cat);
            }
          }

          var products = List<ProductModel>.from(
            _currentTab == 0 ? activeProductsList : recycledProductsList,
          );

          // Filter by search query and category
          if (_selectedCategory != 'All' && _currentTab == 0) {
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

          if (_currentTab == 0) {
            if (_stockFilter == 'In Stock (>10)') {
              products = products.where((p) => p.availableQty > 10).toList();
            } else if (_stockFilter == 'Low Stock (≤10)') {
              products = products
                  .where((p) => p.availableQty > 0 && p.availableQty <= 10)
                  .toList();
            } else if (_stockFilter == 'Out of Stock (0)') {
              products = products.where((p) => p.availableQty <= 0).toList();
            }
          }

          if (_searchQuery.trim().isNotEmpty) {
            final tokens = _searchQuery
                .trim()
                .toLowerCase()
                .split(RegExp(r'\s+'))
                .where((t) => t.isNotEmpty)
                .toList();
            products = products.where((p) {
              return tokens.every((token) {
                final inName = p.name.toLowerCase().contains(token);
                final inSku = p.sku.toLowerCase().contains(token);
                final inCategory = p.categoryId.toLowerCase().contains(token);
                final inTags = p.tags.any(
                  (t) => t.toLowerCase().contains(token),
                );
                final inVariants = p.variants.any(
                  (v) =>
                      v.name.toLowerCase().contains(token) ||
                      v.sku.toLowerCase().contains(token),
                );
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
              // Top Segmented Tab Header (Active vs Recycle Bin)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _currentTab = 0),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _currentTab == 0
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _currentTab == 0
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(12),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 16,
                                  color: _currentTab == 0
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Active (${activeProductsList.length})',
                                  style: TextStyle(
                                    fontWeight: _currentTab == 0
                                        ? FontWeight.w900
                                        : FontWeight.w600,
                                    fontSize: 13,
                                    color: _currentTab == 0
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _currentTab = 1),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _currentTab == 1
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _currentTab == 1
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(12),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: _currentTab == 1
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Recycle Bin (${recycledProductsList.length})',
                                  style: TextStyle(
                                    fontWeight: _currentTab == 1
                                        ? FontWeight.w900
                                        : FontWeight.w600,
                                    fontSize: 13,
                                    color: _currentTab == 1
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Search & Filter Header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (v) =>
                          setState(() => _searchQuery = v.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: _currentTab == 0
                            ? 'Search active products by name, SKU, tags...'
                            : 'Search deleted listings in recycle bin...',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF2563EB),
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
                    if (_currentTab == 0) ...[
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
                              itemBuilder: (ctx) => [
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
                                          color: Color(0xFF2563EB),
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
                                              ? const Color(0xFF2563EB)
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
                                      ? const Color(0xFFDBEAFE)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _adminSort != 'Default'
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.sort_rounded,
                                      size: 16,
                                      color: _adminSort != 'Default'
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _adminSort == 'Default'
                                          ? 'Sort'
                                          : _adminSort,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _adminSort != 'Default'
                                            ? const Color(0xFF2563EB)
                                            : const Color(0xFF334155),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_drop_down_rounded,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Stock Filter Dropdown Button
                            PopupMenuButton<String>(
                              initialValue: _stockFilter,
                              onSelected: (val) =>
                                  setState(() => _stockFilter = val),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              itemBuilder: (ctx) => [
                                'All',
                                'In Stock (>10)',
                                'Low Stock (≤10)',
                                'Out of Stock (0)',
                              ].map((opt) {
                                return PopupMenuItem(
                                  value: opt,
                                  child: Row(
                                    children: [
                                      if (_stockFilter == opt)
                                        const Icon(
                                          Icons.check_rounded,
                                          size: 16,
                                          color: Color(0xFF2563EB),
                                        )
                                      else
                                        const SizedBox(width: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        opt,
                                        style: TextStyle(
                                          fontWeight: _stockFilter == opt
                                              ? FontWeight.w800
                                              : FontWeight.w500,
                                          color: _stockFilter == opt
                                              ? const Color(0xFF2563EB)
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
                                  color: _stockFilter != 'All'
                                      ? const Color(0xFFFEF3C7)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _stockFilter != 'All'
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 16,
                                      color: _stockFilter != 'All'
                                          ? const Color(0xFFB45309)
                                          : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _stockFilter == 'All'
                                          ? 'Stock Filter'
                                          : _stockFilter,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _stockFilter != 'All'
                                            ? const Color(0xFFB45309)
                                            : const Color(0xFF334155),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_drop_down_rounded,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Category Horizontal List
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: dynamicCategories.map((category) {
                            final isSelected = _selectedCategory == category;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(category),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedCategory = category;
                                  });
                                },
                                selectedColor: const Color(0xFF2563EB),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF475569),
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                backgroundColor: const Color(0xFFF1F5F9),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: isSelected
                                        ? const Color(0xFF2563EB)
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Product List or Recycle Bin List
              Expanded(
                child: products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _currentTab == 0
                                    ? Icons.inventory_2_outlined
                                    : Icons.delete_sweep_outlined,
                                size: 44,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _currentTab == 0
                                  ? 'No products found'
                                  : 'Recycle Bin is empty',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentTab == 0
                                  ? 'Try adjusting your search or filters.'
                                  : 'Deleted listings will appear here and can be recovered anytime.',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: products.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final prod = products[index];
                          final isRecycled = prod.isDeleted;
                          final imageUrl = prod.images.isNotEmpty
                              ? prod.images.first
                              : '';

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isRecycled
                                    ? const Color(0xFFFECACA)
                                    : const Color(0xFFE2E8F0),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(5),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ProductImageWidget(
                                  imageSrc: imageUrl,
                                  width: 68,
                                  height: 68,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (isRecycled) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          margin:
                                              const EdgeInsets.only(bottom: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF2F2),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: const Color(0xFFFCA5A5),
                                            ),
                                          ),
                                          child: const Text(
                                            'In Recycle Bin',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFFDC2626),
                                            ),
                                          ),
                                        ),
                                      ],
                                      Text(
                                        prod.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                          color: isRecycled
                                              ? const Color(0xFF64748B)
                                              : const Color(0xFF0F172A),
                                          decoration: isRecycled
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'SKU: ${prod.sku.isNotEmpty ? prod.sku : "N/A"} • ${prod.categoryId}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Text(
                                            '₹${prod.wholesalePrice.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15,
                                              color: Color(0xFF2563EB),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: prod.availableQty > 10
                                                  ? const Color(0xFFDCFCE7)
                                                  : prod.availableQty > 0
                                                      ? const Color(0xFFFEF3C7)
                                                      : const Color(0xFFFEE2E2),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Qty: ${prod.availableQty}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: prod.availableQty > 10
                                                    ? const Color(0xFF16A34A)
                                                    : prod.availableQty > 0
                                                        ? const Color(0xFFB45309)
                                                        : const Color(0xFFDC2626),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (isRecycled) ...[
                                  Column(
                                    children: [
                                      IconButton.filledTonal(
                                        tooltip: 'Restore to Active Catalog',
                                        icon: const Icon(
                                          Icons.restore_from_trash_rounded,
                                          size: 18,
                                          color: Color(0xFF2563EB),
                                        ),
                                        style: IconButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFEFF6FF),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: () =>
                                            _restoreProduct(context, prod),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete Permanently',
                                        icon: Icon(
                                          Icons.delete_forever_rounded,
                                          size: 18,
                                          color: Colors.red.shade700,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () =>
                                            _permanentDeleteProduct(
                                              context,
                                              prod,
                                            ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Edit Product',
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 20,
                                          color: Color(0xFF2563EB),
                                        ),
                                        onPressed: () =>
                                            _openAddEditProductModal(
                                              context,
                                              product: prod,
                                            ),
                                      ),
                                      IconButton(
                                        tooltip: 'Move to Recycle Bin',
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
                              ],
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

    // Step 1: Confirmation Warning Modal
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 10),
            Text('Move to Recycle Bin?'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "${product.name}" from active listings? It will be moved to the Recycle Bin and can be restored anytime.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue to PIN'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Step 2: 4-Digit Security PIN Authorization Modal
    if (!context.mounted) return;
    final pinVerified = await showAdminPinDialog(
      context,
      actionTitle: 'Authorization Required',
      reason: 'move "${product.name}" to the Recycle Bin',
    );

    if (pinVerified == true) {
      try {
        await _productRepo.moveToBin(product.id);
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Moved "${product.name}" to Recycle Bin'),
              action: SnackBarAction(
                label: 'Undo',
                textColor: const Color(0xFFBFDBFE),
                onPressed: () => _productRepo.restoreFromBin(product.id),
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Error moving to bin: $e')),
          );
        }
      }
    }
  }

  Future<void> _restoreProduct(
    BuildContext context,
    ProductModel product,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _productRepo.restoreFromBin(product.id);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Restored "${product.name}" to active catalog'),
            backgroundColor: const Color(0xFF2563EB),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error restoring product: $e')),
        );
      }
    }
  }

  Future<void> _permanentDeleteProduct(
    BuildContext context,
    ProductModel product,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    // Step 1: Warning
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 10),
            Text('Permanently Delete?'),
          ],
        ),
        content: Text(
          'This action is irreversible. Are you sure you want to permanently erase "${product.name}" from the database?',
          style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue to PIN'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Step 2: PIN
    if (!context.mounted) return;
    final pinVerified = await showAdminPinDialog(
      context,
      actionTitle: 'Permanent Purge',
      reason: 'permanently delete "${product.name}"',
    );

    if (pinVerified == true) {
      try {
        await _productRepo.permanentDeleteProduct(product.id);
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Permanently deleted "${product.name}"'),
              backgroundColor: Colors.red.shade800,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Error permanently deleting product: $e')),
          );
        }
      }
    }
  }
}
