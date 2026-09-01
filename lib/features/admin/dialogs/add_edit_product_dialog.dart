import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:goodwin/core/services/firestore_product_repository.dart';
import 'package:goodwin/core/services/firestore_user_repository.dart';
import 'package:goodwin/models/product_model.dart';
import 'package:goodwin/shared/widgets/photo_option_button.dart';
import 'package:goodwin/shared/widgets/product_image_widget.dart';

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
  List<String> _selectedImages = [];
  List<_VariantEditItem> _variants = [];
  bool _isUploadingPhoto = false;
  bool _isSaving = false;

  final List<String> _categoryOptions = [
    'Dry Fruits',
    'Spices',
    'Beverages',
    'Grocery',
    'Staples',
    'Snacks',
    'Confectionery',
    'Personal Care',
    'Dairy',
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
    _selectedImages = (p?.images.isNotEmpty == true)
        ? List<String>.from(p!.images)
        : [];
    _descController = TextEditingController(text: p?.description ?? '');
    _categoryController = TextEditingController(
      text: p != null && p.categoryId.trim().isNotEmpty
          ? p.categoryId.trim()
          : 'Dry Fruits',
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

  Future<void> _pickImageFromDevice(ImageSource source) async {
    final picker = ImagePicker();
    try {
      if (source == ImageSource.gallery) {
        // Multi-image selection from Gallery
        final pickedList = await picker.pickMultiImage(
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        if (pickedList.isNotEmpty) {
          setState(() => _isUploadingPhoto = true);
          for (final picked in pickedList) {
            final bytes = await picked.readAsBytes();
            try {
              final fileName =
                  'prod_${DateTime.now().microsecondsSinceEpoch}.jpg';
              final storageRef = FirebaseStorage.instance
                  .ref()
                  .child('products')
                  .child(fileName);
              final uploadTask = await storageRef.putData(
                bytes,
                SettableMetadata(contentType: 'image/jpeg'),
              );
              final downloadUrl = await uploadTask.ref.getDownloadURL();
              if (mounted) {
                setState(() {
                  _selectedImages.add(downloadUrl);
                });
              }
            } catch (_) {
              final base64String =
                  'data:image/jpeg;base64,${base64Encode(bytes)}';
              if (mounted) {
                setState(() {
                  _selectedImages.add(base64String);
                });
              }
            }
          }
          if (mounted) {
            setState(() => _isUploadingPhoto = false);
          }
        }
      } else {
        // Single image capture from Camera
        final picked = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        if (picked != null) {
          setState(() => _isUploadingPhoto = true);
          final bytes = await picked.readAsBytes();
          try {
            final fileName =
                'prod_${DateTime.now().microsecondsSinceEpoch}.jpg';
            final storageRef = FirebaseStorage.instance
                .ref()
                .child('products')
                .child(fileName);
            final uploadTask = await storageRef.putData(
              bytes,
              SettableMetadata(contentType: 'image/jpeg'),
            );
            final downloadUrl = await uploadTask.ref.getDownloadURL();
            if (mounted) {
              setState(() {
                _selectedImages.add(downloadUrl);
                _isUploadingPhoto = false;
              });
            }
          } catch (_) {
            final base64String =
                'data:image/jpeg;base64,${base64Encode(bytes)}';
            if (mounted) {
              setState(() {
                _selectedImages.add(base64String);
                _isUploadingPhoto = false;
              });
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not load image: $e')));
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
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        if (pickedList.isNotEmpty) {
          for (final picked in pickedList) {
            final bytes = await picked.readAsBytes();
            try {
              final fileName =
                  'var_${DateTime.now().microsecondsSinceEpoch}.jpg';
              final storageRef = FirebaseStorage.instance
                  .ref()
                  .child('products')
                  .child(fileName);
              final uploadTask = await storageRef.putData(
                bytes,
                SettableMetadata(contentType: 'image/jpeg'),
              );
              final downloadUrl = await uploadTask.ref.getDownloadURL();
              if (mounted) {
                setState(() => variant.images.add(downloadUrl));
              }
            } catch (_) {
              final base64String =
                  'data:image/jpeg;base64,${base64Encode(bytes)}';
              if (mounted) {
                setState(() => variant.images.add(base64String));
              }
            }
          }
        }
      } else {
        final picked = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        if (picked != null) {
          final bytes = await picked.readAsBytes();
          try {
            final fileName =
                'var_${DateTime.now().microsecondsSinceEpoch}.jpg';
            final storageRef = FirebaseStorage.instance
                .ref()
                .child('products')
                .child(fileName);
            final uploadTask = await storageRef.putData(
              bytes,
              SettableMetadata(contentType: 'image/jpeg'),
            );
            final downloadUrl = await uploadTask.ref.getDownloadURL();
            if (mounted) {
              setState(() => variant.images.add(downloadUrl));
            }
          } catch (_) {
            final base64String =
                'data:image/jpeg;base64,${base64Encode(bytes)}';
            if (mounted) {
              setState(() => variant.images.add(base64String));
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not load image: $e')));
      }
    }
  }

  Future<void> _openVariantPhotoSourcePicker(_VariantEditItem variant) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      color: const Color(0xFF0F766E),
                      onTap: () async {
                        Navigator.pop(sheetCtx);
                        await _pickVariantImage(variant, ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PhotoOptionButton(
                      icon: Icons.photo_library_rounded,
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

  Future<void> _openPhotoSourcePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
              const Text(
                'Add Product Photo(s)',
                style: TextStyle(
                  fontSize: 18,
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
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      color: const Color(0xFF0F766E),
                      onTap: () async {
                        Navigator.pop(sheetCtx);
                        await _pickImageFromDevice(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PhotoOptionButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery (Multi)',
                      color: const Color(0xFF2563EB),
                      onTap: () async {
                        Navigator.pop(sheetCtx);
                        await _pickImageFromDevice(ImageSource.gallery);
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

      final images = <String>[];
      if (_selectedImages.isNotEmpty) {
        images.addAll(_selectedImages.where((s) => s.trim().isNotEmpty));
      }
      if (images.isEmpty) {
        images.add(
          'https://images.unsplash.com/photo-1509358271058-acd22cc93898?w=800&q=80',
        );
      }

      final enteredCategory = _categoryController.text.trim().isNotEmpty
          ? _categoryController.text.trim()
          : 'Dry Fruits';

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
            backgroundColor: const Color(0xFF0F766E),
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
                    icon: const Icon(Icons.close_rounded),
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
                            if (_selectedImages.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCCFBF1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_selectedImages.length}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (_selectedImages.isNotEmpty && !_isUploadingPhoto)
                          TextButton.icon(
                            onPressed: _openPhotoSourcePicker,
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 16,
                            ),
                            label: const Text(
                              '+ Add Photo',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF0F766E),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_isUploadingPhoto)
                      Container(
                        height: 110,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Processing photo(s)...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_selectedImages.isNotEmpty) ...[
                      SizedBox(
                        height: 104,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length + 1,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: 10),
                          itemBuilder: (ctx, i) {
                            if (i == _selectedImages.length) {
                              return InkWell(
                                onTap: _openPhotoSourcePicker,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 90,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDFA),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFF99F6E4),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_rounded,
                                        size: 26,
                                        color: Color(0xFF0F766E),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Add More',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F766E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final imgUrl = _selectedImages[i];
                            final isCover = i == 0;
                            return Stack(
                              children: [
                                Container(
                                  width: 90,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isCover
                                          ? const Color(0xFF0F766E)
                                          : const Color(0xFFE2E8F0),
                                      width: isCover ? 2 : 1,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: ProductImageWidget(
                                    imageSrc: imgUrl,
                                    width: 90,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                if (isCover)
                                  Positioned(
                                    top: 4,
                                    left: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F766E),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'COVER',
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
                                  top: 3,
                                  right: 3,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedImages.removeAt(i);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 14,
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
                      const SizedBox(height: 4),
                      const Text(
                        'Tip: The first image (marked COVER) will be displayed as the main cover photo in the store catalog.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ] else
                      InkWell(
                        onTap: _openPhotoSourcePicker,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF99F6E4),
                              width: 1.5,
                            ),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_rounded,
                                size: 38,
                                color: Color(0xFF0F766E),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Upload Product Photos from Device',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Tap to choose multiple photos from Gallery or take a Camera photo',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
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
                              Icons.category_outlined,
                              size: 20,
                            ),
                            suffixIcon: _categoryController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear_rounded,
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
                                        ? const Color(0xFFCCFBF1)
                                        : const Color(0xFFF1F5F9),
                                    side: BorderSide(
                                      color: isSelected
                                          ? const Color(0xFF0F766E)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                    labelStyle: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xFF0F766E)
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
                                      Icons.style_outlined,
                                      color: Color(0xFF0F766E),
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
                                          color: const Color(0xFFCCFBF1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${_variants.length}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F766E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _addVariant,
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text(
                                  '+ Add Variation',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF0F766E),
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
                                            color: const Color(0xFF0F766E),
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
                                            Icons.delete_outline_rounded,
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
                                            Icons.add_a_photo_outlined,
                                            size: 14,
                                          ),
                                          label: const Text(
                                            '+ Add Photo',
                                            style: TextStyle(fontSize: 11.5),
                                          ),
                                          style: TextButton.styleFrom(
                                            foregroundColor: const Color(
                                              0xFF0F766E,
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
                                                      0xFFF0FDFA,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    border: Border.all(
                                                      color: const Color(
                                                        0xFF99F6E4,
                                                      ),
                                                    ),
                                                  ),
                                                  child: const Icon(
                                                    Icons
                                                        .add_photo_alternate_rounded,
                                                    size: 20,
                                                    color: Color(0xFF0F766E),
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
                                                        Icons.close_rounded,
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
                        backgroundColor: const Color(0xFF0F766E),
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
}

/// Admin Screen to View and Manage All Placed Orders Across the Platform (Warehouse & Online)

