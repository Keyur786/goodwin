import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:goodwin/core/services/firestore_product_repository.dart';
import 'package:goodwin/models/demo_product.dart';
import 'package:goodwin/models/user_model.dart';
import 'package:goodwin/shared/widgets/product_image_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

Future<void> showBulkOrderInquiryDialog({
  required BuildContext context,
  AppUser? currentUser,
  String initialProductOrCategory = '',
  List<DemoProduct>? catalogProducts,
  DemoProduct? selectedProduct,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (modalCtx) => BulkOrderInquirySheet(
      currentUser: currentUser,
      initialProductOrCategory: initialProductOrCategory,
      catalogProducts: catalogProducts,
      initialSelectedProduct: selectedProduct,
    ),
  );
}

class BulkOrderInquirySheet extends StatefulWidget {
  final AppUser? currentUser;
  final String initialProductOrCategory;
  final List<DemoProduct>? catalogProducts;
  final DemoProduct? initialSelectedProduct;

  const BulkOrderInquirySheet({
    super.key,
    this.currentUser,
    this.initialProductOrCategory = '',
    this.catalogProducts,
    this.initialSelectedProduct,
  });

  @override
  State<BulkOrderInquirySheet> createState() => _BulkOrderInquirySheetState();
}

class _BulkOrderInquirySheetState extends State<BulkOrderInquirySheet> {
  final _formKey = GlobalKey<FormState>();
  final _repo = FirestoreProductRepository();

  late final TextEditingController _nameController;
  late final TextEditingController _shopController;
  late final TextEditingController _phoneController;
  late final TextEditingController _productController;
  late final TextEditingController _quantityController;
  late final TextEditingController _notesController;

  DemoProduct? _selectedProduct;
  bool _isCustomProduct = false;
  List<DemoProduct> _availableProducts = [];
  bool _isLoadingProducts = false;

  String? _photoUrl;
  bool _isUploadingPhoto = false;
  bool _isSubmitting = false;
  bool _submittedSuccess = false;
  bool _showPhotoSection = false;

  final List<String> _quickQuantityChips = [
    '100',
    '250',
    '500',
    '1,000',
    '2,500',
    '5,000+',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentUser?.name ?? '');
    _shopController = TextEditingController(text: widget.currentUser?.shopName ?? '');
    _phoneController = TextEditingController(text: widget.currentUser?.phone ?? '');
    _productController = TextEditingController(text: widget.initialProductOrCategory);
    _quantityController = TextEditingController(text: '500');
    _notesController = TextEditingController();

    if (widget.initialSelectedProduct != null) {
      _selectedProduct = widget.initialSelectedProduct;
      _productController.text = _selectedProduct!.name;
    } else if (widget.initialProductOrCategory.isNotEmpty) {
      _isCustomProduct = true;
    }

    if (widget.catalogProducts != null && widget.catalogProducts!.isNotEmpty) {
      _availableProducts = List.from(widget.catalogProducts!);
    } else {
      _loadProducts();
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final models = await _repo.getProducts();
      if (mounted) {
        setState(() {
          _availableProducts = models.map((m) => DemoProduct.fromProductModel(m)).toList();
          _isLoadingProducts = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingProducts = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shopController.dispose();
    _phoneController.dispose();
    _productController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 82,
      );
      if (picked == null) return;

      setState(() => _isUploadingPhoto = true);
      final bytes = await picked.readAsBytes();
      try {
        final fileName = 'inq_${DateTime.now().microsecondsSinceEpoch}.jpg';
        final storageRef = FirebaseStorage.instance.ref().child('inquiries').child(fileName);
        final uploadTask = await storageRef.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        if (mounted) {
          setState(() {
            _photoUrl = downloadUrl;
            _isUploadingPhoto = false;
          });
        }
      } catch (_) {
        // Fallback to base64 data URI if storage offline or not configured
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        if (mounted) {
          setState(() {
            _photoUrl = base64String;
            _isUploadingPhoto = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not access photo: $e')),
        );
      }
    }
  }

  void _openCatalogPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (pickerCtx) => _CatalogProductPickerSheet(
        products: _availableProducts,
        isLoading: _isLoadingProducts,
        onProductSelected: (prod) {
          setState(() {
            _selectedProduct = prod;
            _isCustomProduct = false;
            _productController.text = prod.name;
          });
        },
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final hasCatalogProduct =
        _selectedProduct != null || _productController.text.trim().isNotEmpty;
    final hasPhoto = _photoUrl != null && _photoUrl!.isNotEmpty;

    if (!hasCatalogProduct && !hasPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a product from catalog or upload a sample photo'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final productName = _selectedProduct != null
        ? _selectedProduct!.name
        : _productController.text.trim().isNotEmpty
            ? _productController.text.trim()
            : 'Custom Sample (Photo Attached)';

    final rawQty = _quantityController.text.trim();
    final quantityRange = rawQty.toLowerCase().contains('unit') ? rawQty : '$rawQty units';

    setState(() => _isSubmitting = true);
    try {
      await _repo.submitBulkInquiry(
        contactName: _nameController.text,
        shopName: _shopController.text,
        phone: _phoneController.text,
        categoryOrProduct: productName,
        quantityRange: quantityRange,
        notes: _notesController.text,
        userId: widget.currentUser?.id,
        photoUrl: _photoUrl,
        productId: _selectedProduct?.id,
      );
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submittedSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not submit inquiry: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: _submittedSuccess ? _buildSuccessView() : _buildFormView(),
    );
  }

  Widget _buildSuccessView() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFDBEAFE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.checkCircle,
              color: Color(0xFF2563EB),
              size: 54,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Inquiry Received!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Thank you! Our wholesale sales desk will review your requirements and provide special bulk pricing within 2 business hours.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              children: [
                Icon(LucideIcons.headphones, color: Color(0xFF2563EB), size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Direct Wholesale Support',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      Text(
                        'Phone & WhatsApp: +91 99045 79700',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Back to Store',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.boxes,
                    color: Color(0xFF2563EB),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bulk Order Inquiry',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Select from catalog or request custom lot',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x),
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Product / Photo Requirement (Catalog OR Device Photo OR Both)
            _buildProductOrPhotoSelection(),

            const SizedBox(height: 16),

            // 3. Quantity (Custom Units Input + Quick Chips)
            const Text(
              'Required Quantity (Units)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Type exact number of units or pick a preset below:',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'e.g. 500',
                prefixIcon: const Icon(LucideIcons.hash, size: 18, color: Color(0xFF64748B)),
                suffixText: 'units',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter required quantity';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickQuantityChips.map((preset) {
                final isSelected = _quantityController.text.trim() == preset;
                return ActionChip(
                  label: Text(
                    '$preset units',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
                    ),
                  ),
                  backgroundColor: isSelected ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.5 : 1,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onPressed: () => setState(() => _quantityController.text = preset),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 4. Contact Name & Shop Name
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Name',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'Contact Name',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter your name' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Business / Shop Name',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _shopController,
                        decoration: InputDecoration(
                          hintText: 'Shop / Company',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter shop name' : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 5. Phone Number
            const Text(
              'Contact Phone / WhatsApp',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'e.g. 9876543210',
                prefixIcon: const Icon(LucideIcons.phone, size: 18, color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              validator: (v) => v == null || v.trim().length < 10 ? 'Enter valid 10-digit number' : null,
            ),
            const SizedBox(height: 14),

            // 6. Notes
            const Text(
              'Custom Requirements / Notes (Optional)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g. Bulk carton packaging, private labeling, urgent dispatch...',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _isSubmitting || _isUploadingPhoto ? null : _handleSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Submit Bulk Inquiry',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductOrPhotoSelection() {
    final hasCatalogProduct = _selectedProduct != null || _isCustomProduct;
    final hasPhoto = _photoUrl != null || _isUploadingPhoto;

    // Case 1: Neither provided yet -> Show initial choice prompt
    if (!hasCatalogProduct && !hasPhoto) {
      return _buildInitialChoicePrompt();
    }

    // Case 2: Either or both provided
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show Catalog Product Card if selected
        if (hasCatalogProduct) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Selected Catalog Product',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    if (_isCustomProduct) {
                      _isCustomProduct = false;
                      _openCatalogPicker();
                    } else {
                      _isCustomProduct = true;
                      _selectedProduct = null;
                    }
                  });
                },
                child: Text(
                  _isCustomProduct ? 'Browse Catalog' : 'Custom Name',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_selectedProduct != null)
            _buildSelectedProductCard()
          else
            _buildCustomProductInput(),
        ],

        // Spacing if both are present
        if (hasCatalogProduct && (hasPhoto || _showPhotoSection))
          const SizedBox(height: 14),

        // Show Photo Attachment if attached OR if user specifically expanded it
        if (hasPhoto || _showPhotoSection) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Attached Photo Sample',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
              ),
              if (_photoUrl != null)
                InkWell(
                  onTap: () => setState(() {
                    _photoUrl = null;
                    _showPhotoSection = false;
                  }),
                  child: const Text(
                    'Remove',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                  ),
                )
              else if (_showPhotoSection && hasCatalogProduct)
                InkWell(
                  onTap: () => setState(() => _showPhotoSection = false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _buildPhotoAttachmentSection(),
        ],

        // Optional "+ Also attach photo" prompt if user only picked catalog product
        if (hasCatalogProduct && !hasPhoto && !_showPhotoSection) ...[
          const SizedBox(height: 10),
          InkWell(
            onTap: () => setState(() => _showPhotoSection = true),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.camera, size: 15, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Text(
                    '+ Also attach photo from camera or gallery (optional)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Optional "+ Also link catalog product" prompt if user only uploaded photo
        if (hasPhoto && !hasCatalogProduct) ...[
          const SizedBox(height: 10),
          InkWell(
            onTap: _openCatalogPicker,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.layoutGrid, size: 15, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Text(
                    '+ Also link an existing catalog product (optional)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInitialChoicePrompt() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Product Specification',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Text(
                'Catalog or Photo Required',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose an item from our catalog OR upload a photo from your device:',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 10),

        // Choice 1: Select from Catalog
        InkWell(
          onTap: _openCatalogPicker,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF93C5FD), width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.layoutGrid, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select from Catalog',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF1E3A8A)),
                      ),
                      Text(
                        'Browse products with wholesale wholesale price reference',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF3B82F6)),
                      ),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronRight, size: 18, color: Color(0xFF2563EB)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Choice 2: Upload Photo from Device (Camera or Gallery)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.camera, size: 16, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Text(
                    'Upload Photo from Device',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Attach a picture of your sample item or packaging',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.camera),
                      icon: const Icon(LucideIcons.camera, size: 15, color: Color(0xFF2563EB)),
                      label: const Text('Take Photo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.gallery),
                      icon: const Icon(LucideIcons.image, size: 15, color: Color(0xFF2563EB)),
                      label: const Text('From Gallery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: InkWell(
            onTap: () => setState(() => _isCustomProduct = true),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.pencilLine, size: 13, color: Color(0xFF64748B)),
                  SizedBox(width: 6),
                  Text(
                    'Or type a custom unlisted product name',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedProductCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ProductImageWidget(
              imageSrc: _selectedProduct!.image,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedProduct!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_selectedProduct!.category} • Ref Price: ₹${_selectedProduct!.price.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Change Product',
            icon: const Icon(LucideIcons.repeat, size: 18, color: Color(0xFF2563EB)),
            onPressed: _openCatalogPicker,
          ),
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(LucideIcons.x, size: 18, color: Color(0xFF64748B)),
            onPressed: () {
              setState(() {
                _selectedProduct = null;
                _productController.clear();
                _isCustomProduct = false;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCustomProductInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _productController,
          decoration: InputDecoration(
            hintText: 'e.g. Custom Garment Lots, Cashews, Almonds...',
            prefixIcon: const Icon(LucideIcons.pencil, size: 18, color: Color(0xFF64748B)),
            suffixIcon: IconButton(
              icon: const Icon(LucideIcons.x, size: 16, color: Color(0xFF64748B)),
              onPressed: () {
                setState(() {
                  _isCustomProduct = false;
                  _productController.clear();
                });
              },
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          validator: (v) {
            if (_photoUrl != null && _photoUrl!.isNotEmpty) return null;
            if (v == null || v.trim().isEmpty) return 'Please specify product name or attach photo';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPhotoAttachmentSection() {
    if (_isUploadingPhoto) {
      return Container(
        height: 68,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
              ),
              SizedBox(width: 12),
              Text('Attaching image...', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }

    if (_photoUrl != null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ProductImageWidget(
                imageSrc: _photoUrl!,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Photo Attached',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    'Sample will be sent with inquiry',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Take New Photo',
              icon: const Icon(LucideIcons.camera, size: 18, color: Color(0xFF2563EB)),
              onPressed: () => _pickPhoto(ImageSource.camera),
            ),
            IconButton(
              tooltip: 'Pick from Gallery',
              icon: const Icon(LucideIcons.image, size: 18, color: Color(0xFF2563EB)),
              onPressed: () => _pickPhoto(ImageSource.gallery),
            ),
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(LucideIcons.trash2, size: 18, color: Color(0xFFDC2626)),
              onPressed: () => setState(() {
                _photoUrl = null;
                _showPhotoSection = false;
              }),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickPhoto(ImageSource.camera),
            icon: const Icon(LucideIcons.camera, size: 16, color: Color(0xFF2563EB)),
            label: const Text(
              'Take Photo',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickPhoto(ImageSource.gallery),
            icon: const Icon(LucideIcons.image, size: 16, color: Color(0xFF2563EB)),
            label: const Text(
              'From Gallery',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

class _CatalogProductPickerSheet extends StatefulWidget {
  final List<DemoProduct> products;
  final bool isLoading;
  final ValueChanged<DemoProduct> onProductSelected;

  const _CatalogProductPickerSheet({
    required this.products,
    required this.isLoading,
    required this.onProductSelected,
  });

  @override
  State<_CatalogProductPickerSheet> createState() => _CatalogProductPickerSheetState();
}

class _CatalogProductPickerSheetState extends State<_CatalogProductPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.products.where((p) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          p.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Product from Catalog',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search products by name or category...',
              prefixIcon: const Icon(LucideIcons.search, size: 18, color: Color(0xFF64748B)),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: widget.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No products found matching your search.',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, idx) {
                          final prod = filtered[idx];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ProductImageWidget(
                                imageSrc: prod.image,
                                width: 46,
                                height: 46,
                                fit: BoxFit.cover,
                              ),
                            ),
                            title: Text(
                              prod.name,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            subtitle: Text(
                              '${prod.category} • ₹${prod.price.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            trailing: const Icon(LucideIcons.plusCircle, size: 20, color: Color(0xFF2563EB)),
                            onTap: () {
                              widget.onProductSelected(prod);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
