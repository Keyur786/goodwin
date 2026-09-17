import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:goodwin/core/services/firestore_product_repository.dart';
import 'package:goodwin/core/services/firestore_user_repository.dart';
import 'package:goodwin/core/utils/image_upload_helper.dart';
import 'package:goodwin/models/product_model.dart';
import 'package:goodwin/shared/widgets/photo_option_button.dart';
import 'package:goodwin/shared/widgets/product_image_widget.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class VariantEditItem {
  final String id;
  final TextEditingController nameController;
  final TextEditingController skuController;
  final TextEditingController priceController;
  final TextEditingController stockController;
  final List<String> images;

  VariantEditItem({
    required this.id,
    required String name,
    String sku = '',
    required double price,
    required int stock,
    List<String>? images,
  })  : nameController = TextEditingController(text: name),
        skuController = TextEditingController(text: sku),
        priceController = TextEditingController(
          text: price > 0 ? price.toStringAsFixed(0) : '',
        ),
        stockController = TextEditingController(text: stock.toString()),
        images = images != null ? List<String>.from(images) : [];

  void dispose() {
    nameController.dispose();
    skuController.dispose();
    priceController.dispose();
    stockController.dispose();
  }

  ProductVariantModel toModel() {
    final priceVal = double.tryParse(priceController.text.trim()) ?? 0.0;
    final stockVal = int.tryParse(stockController.text.trim()) ?? 50;
    return ProductVariantModel(
      id: id,
      name: nameController.text.trim().isNotEmpty
          ? nameController.text.trim()
          : 'Standard',
      sku: skuController.text.trim().toUpperCase(),
      wholesalePrice: priceVal,
      mrp: priceVal,
      availableQty: stockVal,
      images: images.where((s) => s.trim().isNotEmpty).toList(),
    );
  }
}

typedef _VariantEditItem = VariantEditItem;

/// Dialog to Add a New Product or Edit an Existing Product
class AddEditProductDialog extends StatefulWidget {
  final ProductModel? product;

  const AddEditProductDialog({super.key, this.product});

  @override
  State<AddEditProductDialog> createState() => _AddEditProductDialogState();
}

class _AddEditProductDialogState extends State<AddEditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _priceController;
  late final TextEditingController _mrpController;
  late final TextEditingController _stockController;
  late final TextEditingController _descController;
  late final TextEditingController _categoryController;
  static const int _initialSlotCount = 6;
  List<String?> _imageSlots = List.filled(_initialSlotCount, null);
  List<_VariantEditItem> _variants = [];
  bool _isUploadingPhoto = false;
  bool _isSaving = false;

  final List<String> _categoryOptions = [
    'Home and Kitchen',
    'Stationery',
    'Medical Use',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _skuController = TextEditingController(
      text:
          p?.sku ??
          'GW-${FirestoreUserRepository.generateRandomAlphabetCode(3)}-${DateTime.now().millisecond % 900 + 100}',
    );
    _priceController = TextEditingController(
      text: p != null ? p.wholesalePrice.toStringAsFixed(0) : '',
    );
    _mrpController = TextEditingController(
      text: p != null ? p.mrp.toStringAsFixed(0) : '',
    );
    _stockController = TextEditingController(
      text: p != null ? p.availableQty.toString() : '50',
    );
    final initialImages = (p?.images.isNotEmpty == true)
        ? List<String>.from(p!.images)
        : <String>[];
    final count = initialImages.length > _initialSlotCount
        ? initialImages.length
        : _initialSlotCount;
    _imageSlots = List<String?>.filled(count, null);
    for (int i = 0; i < initialImages.length; i++) {
      _imageSlots[i] = initialImages[i];
    }
    _descController = TextEditingController(text: p?.description ?? '');
    _categoryController = TextEditingController(
      text: p != null && p.categoryId.trim().isNotEmpty
          ? p.categoryId.trim()
          : 'Home and Kitchen',
    );

    if (p?.variants.isNotEmpty == true) {
      _variants = p!.variants
          .map(
            (v) => _VariantEditItem(
              id: v.id,
              name: v.name,
              sku: v.sku,
              price: v.wholesalePrice,
              stock: v.availableQty,
              images: v.images,
            ),
          )
          .toList();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _mrpController.dispose();
    _stockController.dispose();
    _descController.dispose();
    _categoryController.dispose();
    for (final v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  void _addVariant() {
    setState(() {
      final idx = _variants.length + 1;
      final defaultPrice = double.tryParse(_priceController.text.trim()) ?? 0.0;
      final defaultStock = int.tryParse(_stockController.text.trim()) ?? 50;
      _variants.add(
        _VariantEditItem(
          id: 'var_${DateTime.now().millisecondsSinceEpoch}_$idx',
          name: idx == 1 ? '500g Pack' : (idx == 2 ? '1kg Pack' : 'Size $idx'),
          sku: '${_skuController.text.trim()}-V$idx',
          price: defaultPrice,
          stock: defaultStock,
          images: [],
        ),
      );
    });
  }

  void _removeVariant(int index) {
    setState(() {
      final removed = _variants.removeAt(index);
      removed.dispose();
    });
  }

  void _moveOrSwapSlots(int fromIndex, int toIndex) {
    if (fromIndex == toIndex) return;
    if (fromIndex < 0 || fromIndex >= _imageSlots.length) return;
    if (toIndex < 0 || toIndex >= _imageSlots.length) return;
    setState(() {
      final temp = _imageSlots[fromIndex];
      _imageSlots[fromIndex] = _imageSlots[toIndex];
      _imageSlots[toIndex] = temp;
    });
  }

  void _clearSlot(int index) {
    if (index < 0 || index >= _imageSlots.length) return;
    setState(() {
      _imageSlots[index] = null;
    });
  }

  void _addExtraSlot() {
    setState(() {
      _imageSlots.add(null);
    });
  }

  int _findFirstEmptySlot({int afterIndex = -1}) {
    for (int i = afterIndex + 1; i < _imageSlots.length; i++) {
      if (_imageSlots[i] == null || _imageSlots[i]!.trim().isEmpty) {
        return i;
      }
    }
    return _imageSlots.length;
  }

  Future<void> _pickImageForSlot({
    int? specificSlot,
    required ImageSource source,
  }) async {
    final picker = ImagePicker();
    try {
      if (source == ImageSource.gallery) {
        final pickedList = await picker.pickMultiImage(
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 80,
        );
        if (pickedList.isNotEmpty) {
          setState(() => _isUploadingPhoto = true);
          int targetSlot = specificSlot ?? _findFirstEmptySlot();
          for (final picked in pickedList) {
            final bytes = await picked.readAsBytes();
            final result =
                await uploadBytesOrFallback(bytes, 'products', 'prod');
            if (mounted) {
              setState(() {
                if (targetSlot < _imageSlots.length) {
                  _imageSlots[targetSlot] = result;
                  targetSlot = _findFirstEmptySlot(afterIndex: targetSlot);
                } else {
                  _imageSlots.add(result);
                  targetSlot = _imageSlots.length;
                }
              });
            }
          }
          if (mounted) {
            setState(() => _isUploadingPhoto = false);
          }
        }
      } else {
        final picked = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 80,
        );
        if (picked != null) {
          setState(() => _isUploadingPhoto = true);
          final bytes = await picked.readAsBytes();
          final result =
              await uploadBytesOrFallback(bytes, 'products', 'prod');
          if (mounted) {
            setState(() {
              final targetSlot = specificSlot ?? _findFirstEmptySlot();
              if (targetSlot < _imageSlots.length) {
                _imageSlots[targetSlot] = result;
              } else {
                _imageSlots.add(result);
              }
              _isUploadingPhoto = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load image: $e')),
        );
      }
    }
  }

  Future<void> _pickVariantImage(
    _VariantEditItem variant,
    ImageSource source,
  ) async {
    final picker = ImagePicker();
    try {
      if (source == ImageSource.gallery) {
        final pickedList = await picker.pickMultiImage(
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 80,
        );
        if (pickedList.isNotEmpty) {
          for (final picked in pickedList) {
            final bytes = await picked.readAsBytes();
            final result =
                await uploadBytesOrFallback(bytes, 'products', 'var');
            if (mounted) {
              setState(() => variant.images.add(result));
            }
          }
        }
      } else {
        final picked = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 80,
        );
        if (picked != null) {
          final bytes = await picked.readAsBytes();
          final result =
              await uploadBytesOrFallback(bytes, 'products', 'var');
          if (mounted) {
            setState(() => variant.images.add(result));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load image: $e')),
        );
      }
    }
  }

  Future<void> _openVariantPhotoSourcePicker(_VariantEditItem variant) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 480),
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add Photo for "${variant.nameController.text.trim().isNotEmpty ? variant.nameController.text.trim() : "Variation"}"',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Upload photos from device gallery (single or multiple) or snap with camera.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: PhotoOptionButton(
                      icon: LucideIcons.camera,
                      label: 'Camera',
                      color: const Color(0xFF2563EB),
                      onTap: () async {
                        Navigator.pop(sheetCtx);
                        await _pickVariantImage(variant, ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PhotoOptionButton(
                      icon: LucideIcons.images,
                      label: 'Gallery (Multi)',
                      color: const Color(0xFF2563EB),
                      onTap: () async {
                        Navigator.pop(sheetCtx);
                        await _pickVariantImage(variant, ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPhotoSourcePicker({int? slotIndex}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 480),
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                slotIndex != null
                    ? (slotIndex == 0
                        ? 'Upload Cover Photo (Spot 1)'
                        : 'Upload Photo for Spot ${slotIndex + 1}')
                    : 'Add Product Photo(s)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Upload photos in any format (JPG, PNG, WebP, AVIF, etc.). Image will be normalized and placed into the slot.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: PhotoOptionButton(
                      icon: LucideIcons.camera,
                      label: 'Camera',
                      color: const Color(0xFF2563EB),
                      onTap: () async {
                        Navigator.pop(sheetCtx);
                        await _pickImageForSlot(
                          specificSlot: slotIndex,
                          source: ImageSource.camera,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PhotoOptionButton(
                      icon: LucideIcons.images,
                      label: 'Gallery (Multi)',
                      color: const Color(0xFF2563EB),
                      onTap: () async {
                        Navigator.pop(sheetCtx);
                        await _pickImageForSlot(
                          specificSlot: slotIndex,
                          source: ImageSource.gallery,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final isNew = widget.product == null;
      final productId = widget.product?.id.isNotEmpty == true
          ? widget.product!.id
          : 'prod_${DateTime.now().millisecondsSinceEpoch}';

      final images = _imageSlots
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .toList();
      if (images.isEmpty) {
        images.add(
          'https://images.unsplash.com/photo-1509358271058-acd22cc93898?w=800&q=80',
        );
      }

      final enteredCategory = _categoryController.text.trim().isNotEmpty
          ? _categoryController.text.trim()
          : 'Home and Kitchen';

      final savedVariants = _variants.map((v) => v.toModel()).toList();

      final product = ProductModel(
        id: productId,
        name: _nameController.text.trim(),
        sku: _skuController.text.trim().toUpperCase(),
        categoryId: enteredCategory,
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : 'Premium wholesale grade ${_nameController.text.trim()} packed for quality and freshness.',
        wholesalePrice: double.tryParse(_priceController.text.trim()) ?? 0.0,
        mrp:
            double.tryParse(_mrpController.text.trim()) ??
            ((double.tryParse(_priceController.text.trim()) ?? 0.0) * 1.25),
        minimumOrderQty: 1,
        availableQty: int.tryParse(_stockController.text.trim()) ?? 50,
        lowStockThreshold: 10,
        images: images,
        isActive: true,
        isFeatured: widget.product?.isFeatured ?? false,
        isBestSeller: widget.product?.isBestSeller ?? false,
        createdAt: widget.product?.createdAt ?? DateTime.now(),
        tags: [enteredCategory.toLowerCase(), 'wholesale', 'fresh'],
        variants: savedVariants,
      );

      await FirestoreProductRepository().saveProduct(product);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isNew
                  ? 'Product "${product.name}" added to catalog!'
                  : 'Product updated!',
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
        ).showSnackBar(SnackBar(content: Text('Failed to save product: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 740, maxWidth: 520),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Product' : 'Add New Product',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x),
                  ),
                ],
              ),
              const Divider(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    // Product Photos Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Product Photos *',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_imageSlots.whereType<String>().where((s) => s.trim().isNotEmpty).length} / ${_imageSlots.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!_isUploadingPhoto)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: _addExtraSlot,
                                icon: const Icon(LucideIcons.plus, size: 13),
                                label: const Text(
                                  '+ Slot',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF475569),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _openPhotoSourcePicker(),
                                icon: const Icon(
                                  LucideIcons.imagePlus,
                                  size: 15,
                                ),
                                label: const Text(
                                  '+ Add Photo',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF2563EB),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Drag photos to reorder or swap. Deleting leaves a spot empty so you can upload a new replacement photo.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (_isUploadingPhoto)
                      Container(
                        height: 100,
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Normalizing & uploading photo(s)...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Persistent Photo Slots Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _imageSlots.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.88,
                      ),
                      itemBuilder: (ctx, index) => _buildPhotoSlotItem(index),
                    ),
                    const SizedBox(height: 16),

                    // Product Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name *',
                        hintText: 'e.g. Royal Jumbo Cashews W240 1kg',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter product name'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    // Category Input Field (Manual Typing + Quick Suggestion Chips)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _categoryController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Category *',
                            hintText:
                                'Enter category manually (e.g. Dry Fruits, Spices, Bakery...)',
                            prefixIcon: const Icon(
                              LucideIcons.tag,
                              size: 20,
                            ),
                            suffixIcon: _categoryController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      LucideIcons.x,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () => _categoryController.clear(),
                                      );
                                    },
                                  )
                                : null,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Enter category name'
                              : null,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              const Text(
                                'Quick Suggestions:',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ..._categoryOptions.map((cat) {
                                final isSelected =
                                    _categoryController.text
                                        .trim()
                                        .toLowerCase() ==
                                    cat.toLowerCase();
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ActionChip(
                                    label: Text(cat),
                                    backgroundColor: isSelected
                                        ? const Color(0xFFDBEAFE)
                                        : const Color(0xFFF1F5F9),
                                    side: BorderSide(
                                      color: isSelected
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                    labelStyle: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFF334155),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _categoryController.text = cat;
                                      });
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Standard Pricing Row (Wholesale & Base Stock)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Base Wholesale (₹) *',
                              hintText: 'e.g. 780',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Required';
                              }
                              if (double.tryParse(v.trim()) == null) {
                                return 'Valid number';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _stockController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Base Stock *',
                              hintText: 'e.g. 100',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Required';
                              }
                              if (int.tryParse(v.trim()) == null) {
                                return 'Valid integer';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // SKU Code & MRP
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _skuController,
                            decoration: const InputDecoration(
                              labelText: 'SKU Code',
                              hintText: 'e.g. GW-CSH-001',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _mrpController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Base MRP (₹)',
                              hintText: 'e.g. 999',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Product Variations & Sizes Section
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.layers,
                                      color: Color(0xFF2563EB),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    const Flexible(
                                      child: Text(
                                        'Product Variations',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    if (_variants.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDBEAFE),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${_variants.length}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _addVariant,
                                icon: const Icon(LucideIcons.plus, size: 16),
                                label: const Text(
                                  '+ Add Variation',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF2563EB),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Add variations like different weights (500g, 1kg), pack sizes, or grades with specific prices and custom photos.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_variants.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'No variations added yet. Selling under standard single pricing.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            )
                          else
                            ..._variants.asMap().entries.map((entry) {
                              final index = entry.key;
                              final variant = entry.value;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Variation #${index + 1}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            LucideIcons.trash2,
                                            size: 18,
                                            color: Colors.red,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          tooltip: 'Remove Variation',
                                          onPressed: () =>
                                              _removeVariant(index),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: variant.nameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Variation Title *',
                                        hintText:
                                            'e.g. 500g Pack / 1kg Bag / Grade W180',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: variant.priceController,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'Wholesale Price (₹) *',
                                              hintText: 'e.g. 450',
                                              isDense: true,
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: TextFormField(
                                            controller: variant.stockController,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'Stock Quantity *',
                                              hintText: 'e.g. 50',
                                              isDense: true,
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    // Variant Photos Header & List
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Variation Photos (Optional):',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: () =>
                                              _openVariantPhotoSourcePicker(
                                                variant,
                                              ),
                                          icon: const Icon(
                                            LucideIcons.imagePlus,
                                            size: 14,
                                          ),
                                          label: const Text(
                                            '+ Add Photo',
                                            style: TextStyle(fontSize: 11.5),
                                          ),
                                          style: TextButton.styleFrom(
                                            foregroundColor: const Color(
                                              0xFF2563EB,
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    if (variant.images.isNotEmpty)
                                      SizedBox(
                                        height: 68,
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: variant.images.length + 1,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(width: 8),
                                          itemBuilder: (ctx, imgIdx) {
                                            if (imgIdx ==
                                                variant.images.length) {
                                              return InkWell(
                                                onTap: () =>
                                                    _openVariantPhotoSourcePicker(
                                                      variant,
                                                    ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: Container(
                                                  width: 60,
                                                  height: 60,
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFEFF6FF,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    border: Border.all(
                                                      color: const Color(
                                                        0xFFBFDBFE,
                                                      ),
                                                    ),
                                                  ),
                                                  child: const Icon(
                                                    LucideIcons.imagePlus,
                                                    size: 20,
                                                    color: Color(0xFF2563EB),
                                                  ),
                                                ),
                                              );
                                            }
                                            final vImg =
                                                variant.images[imgIdx];
                                            return Stack(
                                              children: [
                                                Container(
                                                  width: 60,
                                                  height: 60,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    border: Border.all(
                                                      color: const Color(
                                                        0xFFE2E8F0,
                                                      ),
                                                    ),
                                                  ),
                                                  clipBehavior: Clip.antiAlias,
                                                  child: ProductImageWidget(
                                                    imageSrc: vImg,
                                                    width: 60,
                                                    height: 60,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 2,
                                                  right: 2,
                                                  child: InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        variant.images.removeAt(
                                                          imgIdx,
                                                        );
                                                      });
                                                    },
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            2,
                                                          ),
                                                      decoration:
                                                          const BoxDecoration(
                                                            color:
                                                                Colors.black54,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                      child: const Icon(
                                                        LucideIcons.x,
                                                        size: 12,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Description
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText:
                            'Product specifications, pack size, grading...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _saveProduct,
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
                          : Text(
                              isEditing ? 'Update Product' : 'Add to Catalog',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
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
    );
  }

  Widget _buildPhotoSlotItem(int index) {
    final imageUrl = _imageSlots[index];
    final isCover = index == 0;

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) {
        _moveOrSwapSlots(details.data, index);
      },
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;
        if (imageUrl != null && imageUrl.trim().isNotEmpty) {
          return _buildFilledSlotCard(index, imageUrl, isCover, isDropTarget);
        } else {
          return _buildEmptySlotCard(index, isCover, isDropTarget);
        }
      },
    );
  }

  Widget _buildFilledSlotCard(
    int index,
    String imageUrl,
    bool isCover,
    bool isDropTarget,
  ) {
    final cardContent = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDropTarget
              ? const Color(0xFF2563EB)
              : (isCover ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
          width: isDropTarget ? 2.5 : (isCover ? 2.0 : 1.0),
        ),
        boxShadow: isDropTarget
            ? [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ProductImageWidget(
            imageSrc: imageUrl,
            fit: BoxFit.cover,
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.gripHorizontal,
                    size: 11,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    isCover ? 'COVER' : 'Spot ${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isCover)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  'MAIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: InkWell(
              onTap: () => _clearSlot(index),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(3.5),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.x,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final feedbackWidget = Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 100,
        height: 110,
        child: Opacity(
          opacity: 0.9,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2563EB), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: ProductImageWidget(
              imageSrc: imageUrl,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );

    return kIsWeb
        ? Draggable<int>(
            data: index,
            feedback: feedbackWidget,
            childWhenDragging: Opacity(
              opacity: 0.35,
              child: cardContent,
            ),
            child: cardContent,
          )
        : LongPressDraggable<int>(
            data: index,
            delay: const Duration(milliseconds: 150),
            feedback: feedbackWidget,
            childWhenDragging: Opacity(
              opacity: 0.35,
              child: cardContent,
            ),
            child: cardContent,
          );
  }

  Widget _buildEmptySlotCard(int index, bool isCover, bool isDropTarget) {
    return InkWell(
      onTap: () => _openPhotoSourcePicker(slotIndex: index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isDropTarget
              ? const Color(0xFFDBEAFE)
              : (isCover ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDropTarget
                ? const Color(0xFF2563EB)
                : (isCover ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1)),
            width: isDropTarget ? 2.5 : 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDropTarget
                    ? const Color(0xFFBFDBFE)
                    : (isCover
                        ? const Color(0xFFDBEAFE)
                        : const Color(0xFFF1F5F9)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDropTarget
                    ? LucideIcons.arrowDownToLine
                    : LucideIcons.imagePlus,
                size: 20,
                color: isDropTarget
                    ? const Color(0xFF1D4ED8)
                    : (isCover
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isCover ? 'Cover Photo' : 'Spot ${index + 1}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isDropTarget
                    ? const Color(0xFF1D4ED8)
                    : (isCover
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF334155)),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isDropTarget ? 'Drop photo here' : '+ Upload Photo',
              style: TextStyle(
                fontSize: 10,
                fontWeight: isDropTarget ? FontWeight.w700 : FontWeight.w500,
                color: isDropTarget
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Admin Screen to View and Manage All Placed Orders Across the Platform (Warehouse & Online)

