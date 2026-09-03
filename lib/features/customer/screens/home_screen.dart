import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:goodwin/core/constants/app_constants.dart';
import 'package:goodwin/core/services/firestore_product_repository.dart';
import 'package:goodwin/core/services/firestore_user_repository.dart';
import 'package:goodwin/core/state/notification_controller.dart';
import 'package:goodwin/core/utils/quantity_dialog.dart';
import 'package:goodwin/features/admin/dialogs/add_edit_product_dialog.dart';
import 'package:goodwin/features/admin/screens/admin_all_orders_screen.dart';
import 'package:goodwin/features/admin/screens/admin_bulk_quotes_screen.dart';
import 'package:goodwin/features/admin/screens/admin_product_manager_screen.dart';
import 'package:goodwin/features/customer/screens/customer_bulk_quotes_screen.dart';
import 'package:goodwin/features/customer/dialogs/bulk_inquiry_dialog.dart';
import 'package:goodwin/features/customer/payment/prepaid_razorpay_screen.dart';
import 'package:goodwin/features/customer/screens/checkout_screen.dart';
import 'package:goodwin/features/customer/screens/customer_orders_screen.dart';
import 'package:goodwin/features/customer/screens/product_detail_screen.dart';
import 'package:goodwin/features/customer/screens/profile_screen.dart';
import 'package:goodwin/models/cart_item.dart';
import 'package:goodwin/models/category_model.dart';
import 'package:goodwin/models/demo_product.dart';
import 'package:goodwin/models/filter_criteria.dart';
import 'package:goodwin/models/product_model.dart';
import 'package:goodwin/models/user_model.dart';
import 'package:goodwin/shared/widgets/customer_tier_badge.dart';
import 'package:goodwin/shared/widgets/empty_state_view.dart';
import 'package:goodwin/shared/widgets/modern_product_card.dart';
import 'package:goodwin/shared/widgets/pickup_location_modal.dart';
import 'package:goodwin/shared/widgets/product_image_widget.dart';
import 'package:goodwin/shared/widgets/profile_avatar_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class DemoHomeScreen extends StatefulWidget {
  final VoidCallback onLogout;
  final int initialIndex;
  final List<DemoProduct>? initialProducts;

  const DemoHomeScreen({
    super.key,
    required this.onLogout,
    this.initialIndex = 0,
    this.initialProducts,
  });

  @override
  State<DemoHomeScreen> createState() => _DemoHomeScreenState();
}

class _DemoHomeScreenState extends State<DemoHomeScreen> {
  final _userRepository = FirestoreUserRepository();
  final _productRepository = FirestoreProductRepository();

  int selectedIndex = 0;
  String selectedCategory = 'All';
  String homeSearchQuery = '';
  ProductSortOption selectedSortOption = ProductSortOption.featured;
  ProductFilterCriteria filterCriteria = const ProductFilterCriteria();
  AppUser? currentUser;
  bool isLoadingProducts = true;
  List<DemoProduct> products = <DemoProduct>[];
  List<String> categoryTabs = <String>[
    'All',
    'Beverages',
    'Dry Fruits',
    'Grocery & Staples',
    'Snacks',
    'Spices',
    'Sweets & Confectionery',
  ];
  final Set<String> favoriteIds = <String>{};
  final List<CartItem> cart = <CartItem>[];
  final Map<String, int> productQuantities = <String, int>{};

  bool _isCatalogHeaderVisible = true;
  int _displayedProductCount = 12;
  bool _isLoadingMore = false;
  static const int _batchSize = 12;

  final TextEditingController _catalogSearchController =
      TextEditingController();

  void _loadMoreProducts() {
    if (_isLoadingMore || _displayedProductCount >= filteredProducts.length) {
      return;
    }
    setState(() => _isLoadingMore = true);
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _displayedProductCount = (_displayedProductCount + _batchSize).clamp(
            0,
            filteredProducts.length,
          );
          _isLoadingMore = false;
        });
      }
    });
  }

  StreamSubscription<AppUser?>? _userSub;
  StreamSubscription<List<ProductModel>>? _productsSub;
  StreamSubscription<List<CategoryModel>>? _categoriesSub;
  Timer? _cartDebounceTimer;
  Timer? _favoritesDebounceTimer;
  Timer? _searchDebounceTimer;
  Timer? _loadingTimeoutTimer;
  List<ProductModel> _rawFirestoreProducts = [];
  List<CategoryModel> _firestoreCategoryList = [];

  bool _isProductMatchingCategory(DemoProduct product, String targetCategory) {
    if (targetCategory == 'All') return true;
    final cleanTarget = targetCategory.trim().toLowerCase();
    final cleanProductCat = product.category.trim().toLowerCase();

    if (cleanProductCat == cleanTarget) return true;

    // Normalization comparison for punctuation and prefix differences
    final normTarget = cleanTarget
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    final normProduct = cleanProductCat
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .replaceFirst('cat', '');

    if (normTarget.isNotEmpty &&
        (normTarget == normProduct ||
            normTarget.contains(normProduct) ||
            normProduct.contains(normTarget))) {
      return true;
    }

    return false;
  }

  void _updateCategoryTabsAndProducts() {
    final Map<String, String> catMap = {};
    for (final c in _firestoreCategoryList) {
      catMap[c.id] = c.name;
      catMap[c.id.toLowerCase()] = c.name;
      catMap[c.slug.toLowerCase()] = c.name;
      catMap[c.name.toLowerCase()] = c.name;
    }

    if (_rawFirestoreProducts.isNotEmpty) {
      products = _rawFirestoreProducts
          .map((p) => DemoProduct.fromProductModel(p, '', catMap))
          .toList();
    } else if (products.isNotEmpty) {
      products = products
          .map(
            (p) => DemoProduct(
              id: p.id,
              name: p.name,
              category: catMap[p.category] ??
                  catMap[p.category.toLowerCase()] ??
                  p.category,
              image: p.image,
              images: p.images,
              price: p.price,
              originalPrice: p.originalPrice,
              subtitle: p.subtitle,
              description: p.description,
              tags: p.tags,
              availableQty: p.availableQty,
              variants: p.variants,
            ),
          )
          .toList();
    }

    final Set<String> catNames = {};
    for (final c in _firestoreCategoryList) {
      if (c.name.trim().isNotEmpty) catNames.add(c.name.trim());
    }
    for (final p in products) {
      if (p.category.trim().isNotEmpty && p.category.trim() != 'All') {
        catNames.add(p.category.trim());
      }
    }

    if (catNames.isNotEmpty) {
      final sortedCats = catNames.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      categoryTabs = ['All', ...sortedCats];
    }
  }

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
    if (widget.initialProducts != null && widget.initialProducts!.isNotEmpty) {
      products = List.from(widget.initialProducts!);
      isLoadingProducts = false;
      _updateCategoryTabsAndProducts();
    }
    _initFirebaseData();
  }

  @override
  void dispose() {
    _catalogSearchController.dispose();
    _cartDebounceTimer?.cancel();
    _favoritesDebounceTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _loadingTimeoutTimer?.cancel();
    _userSub?.cancel();
    _productsSub?.cancel();
    _categoriesSub?.cancel();
    super.dispose();
  }

  Future<void> _initFirebaseData() async {
    try {
      User? firebaseUser;
      try {
        firebaseUser = FirebaseAuth.instance.currentUser;
      } catch (_) {}

      if (firebaseUser != null) {
        NotificationController().setUserId(firebaseUser.uid);
        // 1. Ensure user has a profile and unique 6-alphabet username in Firestore
        final user = await _userRepository.getOrCreateUser(firebaseUser);
        if (mounted) {
          setState(() {
            currentUser = user;
            favoriteIds.addAll(user.favorites);
          });
          NotificationController().syncFromUserData(user.notifications);
          _checkLowStockFavorites();
        }

        // Listen for real-time user updates (profile changes, username changes)
        _userSub = _userRepository.streamUser(firebaseUser.uid).listen((user) {
          if (user != null && mounted) {
            setState(() {
              currentUser = user;
              favoriteIds.clear();
              favoriteIds.addAll(user.favorites);
            });
            NotificationController().syncFromUserData(user.notifications);
            _syncCartFromUserData(user.cart);
            _checkLowStockFavorites();
          }
        });
      }

      // 2. Stream products from Firestore
      try {
        _productsSub = _productRepository.streamProducts().listen(
          (firestoreProducts) {
            if (mounted) {
              setState(() {
                isLoadingProducts = false;
                _rawFirestoreProducts = firestoreProducts;
                _updateCategoryTabsAndProducts();
              });
              if (currentUser != null && currentUser!.cart.isNotEmpty) {
                _syncCartFromUserData(currentUser!.cart);
              }
              _checkLowStockFavorites();
            }
          },
          onError: (_) {
            if (mounted) setState(() => isLoadingProducts = false);
          },
        );
      } catch (_) {
        if (mounted) setState(() => isLoadingProducts = false);
      }

      // 3. Stream categories from Firestore
      try {
        _categoriesSub = _productRepository.streamCategories().listen((
          firestoreCategories,
        ) {
          if (firestoreCategories.isNotEmpty && mounted) {
            setState(() {
              _firestoreCategoryList = firestoreCategories;
              _updateCategoryTabsAndProducts();
            });
          }
        });
      } catch (_) {}

      // 4. Timeout safeguard to never keep user stuck on loading spinner
      _loadingTimeoutTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted && isLoadingProducts && products.isEmpty) {
          setState(() => isLoadingProducts = false);
        }
      });

      // 5. Ensure catalog is seeded to Firestore
      try {
        unawaited(_productRepository.seedDemoDataIfNeeded());
      } catch (_) {}
    } catch (_) {
      if (mounted) {
        setState(() => isLoadingProducts = false);
      }
    }
  }

  void _syncCartFromUserData(List<Map<String, dynamic>> savedCart) {
    if (savedCart.isEmpty) return;
    final List<CartItem> restoredCart = [];
    for (final itemData in savedCart) {
      final pId = itemData['productId']?.toString();
      final qty = (itemData['quantity'] as num?)?.toInt() ?? 1;
      final variantId = itemData['variantId']?.toString();
      if (pId == null) continue;

      final matchedProduct = products.firstWhere(
        (p) => p.id == pId,
        orElse: () => DemoProduct(
          id: pId,
          name: 'Wholesale Product',
          category: 'General',
          image: 'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?auto=format&fit=crop&w=900&q=80',
          price: 50,
          originalPrice: 100,
          subtitle: 'Saved product',
          description: '',
          tags: const [],
        ),
      );

      ProductVariantModel? matchedVariant;
      if (variantId != null && matchedProduct.variants.isNotEmpty) {
        for (final v in matchedProduct.variants) {
          if (v.id == variantId) {
            matchedVariant = v;
            break;
          }
        }
      }

      restoredCart.add(
        CartItem(
          product: matchedProduct,
          quantity: qty,
          selectedVariant: matchedVariant,
        ),
      );
    }

    setState(() {
      cart.clear();
      cart.addAll(restoredCart);
    });
  }

  void _saveCartToFirestore() {
    if (currentUser == null) return;
    _cartDebounceTimer?.cancel();
    _cartDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || currentUser == null) return;
      final cartList = cart
          .map(
            (item) => {
              'productId': item.product.id,
              'quantity': item.quantity,
              if (item.selectedVariant != null)
                'variantId': item.selectedVariant!.id,
            },
          )
          .toList();
      unawaited(_userRepository.syncCart(currentUser!.id, cartList));
    });
  }

  void _saveFavoritesToFirestore() {
    if (currentUser == null) return;
    _favoritesDebounceTimer?.cancel();
    _favoritesDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || currentUser == null) return;
      unawaited(
        _userRepository.syncFavorites(currentUser!.id, favoriteIds.toList()),
      );
    });
  }

  int get totalCartItemCount =>
      cart.fold<int>(0, (sum, item) => sum + item.quantity);

  int getCartQuantity(String productId) {
    for (final item in cart) {
      if (item.product.id == productId) {
        return item.quantity;
      }
    }
    return 0;
  }

  int getQuantity(String productId) {
    final cartQty = getCartQuantity(productId);
    if (cartQty > 0) return cartQty;
    return productQuantities[productId] ?? 1;
  }

  void setQuantity(String productId, int quantity) {
    DemoProduct? matchedProduct;
    for (final p in products) {
      if (p.id == productId) {
        matchedProduct = p;
        break;
      }
    }
    final maxStock = matchedProduct?.availableQty ?? 99999;
    final clampedQty = maxStock > 0 ? quantity.clamp(1, maxStock) : 1;

    setState(() {
      CartItem? existingItem;
      for (final item in cart) {
        if (item.product.id == productId) {
          existingItem = item;
          break;
        }
      }

      if (existingItem != null) {
        if (quantity <= 0) {
          cart.remove(existingItem);
          productQuantities.remove(productId);
        } else {
          existingItem.quantity = clampedQty;
        }
      } else {
        if (quantity <= 0) {
          productQuantities.remove(productId);
        } else {
          productQuantities[productId] = clampedQty;
        }
      }
    });
    _saveCartToFirestore();
  }

  List<DemoProduct> get filteredProducts {
    final rawQuery = homeSearchQuery.trim().toLowerCase();
    final tokens = rawQuery.isEmpty
        ? <String>[]
        : rawQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    final list = products.where((product) {
      final matchesCategory = _isProductMatchingCategory(product, selectedCategory);

      final matchesSearch =
          tokens.isEmpty ||
          tokens.every((token) {
            final inName = product.name.toLowerCase().contains(token);
            final inCategory = product.category.toLowerCase().contains(token);
            final inDescription = product.description.toLowerCase().contains(
              token,
            );
            final inTags = product.tags.any(
              (tag) => tag.toLowerCase().contains(token),
            );
            final inVariants = product.variants.any(
              (v) =>
                  v.name.toLowerCase().contains(token) ||
                  v.sku.toLowerCase().contains(token),
            );
            return inName ||
                inCategory ||
                inDescription ||
                inTags ||
                inVariants;
          });

      final matchesMinPrice =
          filterCriteria.minPrice == null ||
          product.price >= filterCriteria.minPrice!;
      final matchesMaxPrice =
          filterCriteria.maxPrice == null ||
          product.price <= filterCriteria.maxPrice!;
      final matchesStock =
          !filterCriteria.inStockOnly || product.availableQty > 0;
      final matchesFeatured =
          !filterCriteria.featuredOnly ||
          product.tags.any(
            (t) =>
                t.toLowerCase() == 'featured' ||
                t.toLowerCase() == 'wholesale' ||
                t.toLowerCase() == 'dry fruits',
          );
      final matchesBestSeller =
          !filterCriteria.bestSellerOnly ||
          product.tags.any(
            (t) =>
                t.toLowerCase() == 'best seller' ||
                t.toLowerCase() == 'bestseller' ||
                t.toLowerCase() == 'top',
          );

      return matchesCategory &&
          matchesSearch &&
          matchesMinPrice &&
          matchesMaxPrice &&
          matchesStock &&
          matchesFeatured &&
          matchesBestSeller;
    }).toList();

    switch (selectedSortOption) {
      case ProductSortOption.categoryAZ:
      case ProductSortOption.featured:
        list.sort((a, b) {
          final catComp = a.category.toLowerCase().compareTo(
            b.category.toLowerCase(),
          );
          if (catComp != 0) return catComp;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case ProductSortOption.priceLowHigh:
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case ProductSortOption.priceHighLow:
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case ProductSortOption.discountHighLow:
        list.sort((a, b) {
          final discA = a.originalPrice > a.price
              ? (a.originalPrice - a.price) / a.originalPrice
              : 0.0;
          final discB = b.originalPrice > b.price
              ? (b.originalPrice - b.price) / b.originalPrice
              : 0.0;
          return discB.compareTo(discA);
        });
        break;
      case ProductSortOption.nameAZ:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case ProductSortOption.nameZA:
        list.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        break;
    }

    return list;
  }

  double get cartTotal =>
      cart.fold(0.0, (total, item) => total + item.totalPrice);

  void toggleFavorite(String id) {
    setState(() {
      if (favoriteIds.contains(id)) {
        favoriteIds.remove(id);
      } else {
        favoriteIds.add(id);
      }
    });
    _saveFavoritesToFirestore();
    _checkLowStockFavorites();
  }

  void _checkLowStockFavorites() {
    if (!mounted || products.isEmpty || favoriteIds.isEmpty) return;
    NotificationController().setUserId(
      currentUser?.id ?? FirebaseAuth.instance.currentUser?.uid,
    );
    NotificationController().checkFavoriteStockAlerts(
      products: products,
      favoriteIds: favoriteIds,
    );
  }

  void addToCart(
    DemoProduct product, {
    int quantity = 1,
    ProductVariantModel? variant,
  }) {
    final maxStock = variant != null
        ? variant.availableQty
        : product.availableQty;
    if (maxStock <= 0) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} is currently out of stock'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    bool hitStockLimit = false;
    setState(() {
      CartItem? existingItem;
      for (final item in cart) {
        if (item.product.id == product.id &&
            item.selectedVariant?.id == variant?.id) {
          existingItem = item;
          break;
        }
      }

      final addQty = quantity <= 0 ? 1 : quantity;
      if (existingItem == null) {
        final finalQty = addQty.clamp(1, maxStock);
        if (finalQty < addQty) hitStockLimit = true;
        cart.add(
          CartItem(
            product: product,
            quantity: finalQty,
            selectedVariant: variant,
          ),
        );
      } else {
        final proposed = existingItem.quantity + addQty;
        final finalQty = proposed.clamp(1, maxStock);
        if (finalQty < proposed) hitStockLimit = true;
        existingItem.quantity = finalQty;
      }
      productQuantities.remove(product.id);
    });
    _saveCartToFirestore();

    final variantSuffix = variant != null ? ' (${variant.name})' : '';
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hitStockLimit
              ? '${product.name}$variantSuffix: Max stock limit ($maxStock units) reached'
              : '${product.name}$variantSuffix added to cart',
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<bool> confirmRemoveFromCart(CartItem item) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: const Icon(
                LucideIcons.trash2,
                color: Color(0xFFDC2626),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Remove from Cart?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "${item.displayName}" from your cart?',
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: Color(0xFF475569),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'Keep in Cart',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogCtx, true),
            icon: const Icon(LucideIcons.trash2, size: 16),
            label: const Text(
              'Remove',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldRemove == true) {
      removeFromCart(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${item.displayName}" from cart'),
            action: SnackBarAction(
              label: 'Undo',
              textColor: const Color(0xFFBFDBFE),
              onPressed: () {
                setState(() => cart.add(item));
                _saveCartToFirestore();
              },
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return true;
    }
    return false;
  }

  void updateCartQuantity(CartItem item, int quantity) {
    if (quantity <= 0) {
      confirmRemoveFromCart(item);
      return;
    }
    setState(() {
      item.quantity = quantity.clamp(
        1,
        item.maxAvailableStock > 0 ? item.maxAvailableStock : 1,
      );
    });
    _saveCartToFirestore();
  }

  void removeFromCart(CartItem item) {
    setState(() => cart.remove(item));
    _saveCartToFirestore();
  }

  Future<void> handleProfileAction(ProfileAction action) async {
    if (action == ProfileAction.profile) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ProfilePage(
            currentUser: currentUser,
            onUserUpdated: (updatedUser) {
              setState(() => currentUser = updatedUser);
            },
          ),
        ),
      );
      return;
    }

    if (action == ProfileAction.orders) {
      final uid =
          currentUser?.id ?? FirebaseAuth.instance.currentUser?.uid ?? '';
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CustomerOrdersScreen(userId: uid),
        ),
      );
      return;
    }

    if (action == ProfileAction.manageProducts) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const AdminProductManagerScreen(),
        ),
      );
      return;
    }

    if (action == ProfileAction.allOrders) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const AdminAllOrdersScreen()),
      );
      return;
    }

    if (action == ProfileAction.adminBulkQuotes) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const AdminBulkQuotesScreen()),
      );
      return;
    }

    if (action == ProfileAction.bulkQuotes) {
      final uid = currentUser?.id ?? FirebaseAuth.instance.currentUser?.uid ?? '';
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CustomerBulkQuotesScreen(
            userId: uid,
            userName: currentUser?.name ?? '',
          ),
        ),
      );
      return;
    }

    if (action == ProfileAction.signOut) {
      final shouldSignOut = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sign out?'),
          content: const Text(
            'You will need to sign in again to access your account. Your cart and favorites are safely preserved in the cloud.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out'),
            ),
          ],
        ),
      );
      if (shouldSignOut == true && mounted) {
        await FirebaseAuth.instance.signOut();
        setState(() {
          currentUser = null;
          cart.clear();
          favoriteIds.clear();
        });
        if (mounted) widget.onLogout();
      }
      return;
    }

    if (action == ProfileAction.addresses) {
      showPickupLocationModal(context);
      return;
    }

    final message = switch (action) {
      ProfileAction.help => 'Support is available at support@goodwin.com.',
      _ => '',
    };
    if (message.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  bool get isAdminUser =>
      currentUser?.role == UserRole.superAdmin ||
      currentUser?.role == UserRole.manager ||
      FirestoreUserRepository.isSuperAdminPhone(currentUser?.phone);

  void openProduct(DemoProduct product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProductDetailScreen(
          product: product,
          onToggleFavorite: toggleFavorite,
          isFavorite: favoriteIds.contains(product.id),
          cartItemCount: totalCartItemCount,
          isAdmin: isAdminUser,
          onOpenCart: () => setState(() => selectedIndex = 3),
          onAddToCart: (
            product, {
            int quantity = 1,
            ProductVariantModel? variant,
          }) => addToCart(product, quantity: quantity, variant: variant),
        ),
      ),
    );
  }

  void _openProductSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
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
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sort Products',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          icon: const Icon(LucideIcons.x),
                        ),
                      ],
                    ),
                    const Divider(height: 12),
                    ...ProductSortOption.values.map((option) {
                      final isSelected = selectedSortOption == option;
                      return ListTile(
                        leading: Icon(
                          option.icon,
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF64748B),
                        ),
                        title: Text(
                          option.label,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                LucideIcons.check,
                                color: Color(0xFF2563EB),
                                size: 18,
                              )
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: isSelected ? const Color(0xFFEFF6FF) : null,
                        onTap: () {
                          setState(() => selectedSortOption = option);
                          Navigator.pop(sheetCtx);
                        },
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openProductFilterSheet() {
    double? tempMinPrice = filterCriteria.minPrice;
    double? tempMaxPrice = filterCriteria.maxPrice;
    bool tempInStock = filterCriteria.inStockOnly;
    bool tempFeatured = filterCriteria.featuredOnly;
    bool tempBestSeller = filterCriteria.bestSellerOnly;

    final pricePresets = [
      {'label': 'All Prices', 'min': null, 'max': null},
      {'label': 'Under ₹500', 'min': null, 'max': 500.0},
      {'label': '₹500 - ₹1,000', 'min': 500.0, 'max': 1000.0},
      {'label': '₹1,000 - ₹2,000', 'min': 1000.0, 'max': 2000.0},
      {'label': '₹2,000+', 'min': 2000.0, 'max': null},
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter Products',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              tempMinPrice = null;
                              tempMaxPrice = null;
                              tempInStock = false;
                              tempFeatured = false;
                              tempBestSeller = false;
                            });
                          },
                          child: const Text('Reset All'),
                        ),
                      ],
                    ),
                    const Divider(height: 12),
                    const SizedBox(height: 8),

                    // Price Range
                    const Text(
                      'Price Range',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: pricePresets.map((preset) {
                        final minP = preset['min'] as double?;
                        final maxP = preset['max'] as double?;
                        final isSelected =
                            tempMinPrice == minP && tempMaxPrice == maxP;
                        return ChoiceChip(
                          label: Text(preset['label'] as String),
                          selected: isSelected,
                          selectedColor: const Color(0xFFDBEAFE),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF334155),
                          ),
                          onSelected: (_) {
                            setSheetState(() {
                              tempMinPrice = minP;
                              tempMaxPrice = maxP;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Availability & Highlights
                    const Text(
                      'Availability & Highlights',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'In Stock Only',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Hide products that are currently sold out',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      value: tempInStock,
                      activeThumbColor: const Color(0xFF2563EB),
                      onChanged: (val) {
                        setSheetState(() => tempInStock = val);
                      },
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        FilterChip(
                          label: const Text('Featured Items'),
                          selected: tempFeatured,
                          selectedColor: const Color(0xFFDBEAFE),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: tempFeatured
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: tempFeatured
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF334155),
                          ),
                          onSelected: (val) {
                            setSheetState(() => tempFeatured = val);
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Best Sellers'),
                          selected: tempBestSeller,
                          selectedColor: const Color(0xFFDBEAFE),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: tempBestSeller
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: tempBestSeller
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF334155),
                          ),
                          onSelected: (val) {
                            setSheetState(() => tempBestSeller = val);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Apply Button
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          filterCriteria = ProductFilterCriteria(
                            minPrice: tempMinPrice,
                            maxPrice: tempMaxPrice,
                            inStockOnly: tempInStock,
                            featuredOnly: tempFeatured,
                            bestSellerOnly: tempBestSeller,
                          );
                        });
                        Navigator.pop(sheetCtx);
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget buildHomeTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // 1. Hero Wholesale Bulk Program Banner (Single Bulk Inquiry)
        _buildHeroBanner(),
        const SizedBox(height: 20),

        // 2. Quick Category Navigation
        _buildCategorySection(),
        const SizedBox(height: 20),

        // 3. Quick Action Hub (4 interactive cards)
        _buildQuickActionHub(),
        const SizedBox(height: 20),

        // 4. Central Warehouse & Dispatch Hub Card
        _buildWarehouseHubCard(),
        const SizedBox(height: 20),

        // 5. Wholesale Account & Partner Tier Card
        _buildAccountTierCard(),
        const SizedBox(height: 20),

        // 6. Quality & Trade Assurance Card
        _buildQualityAssuranceGrid(),
      ],
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withAlpha(45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.shieldCheck, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'DIRECT FACTORY SUPPLY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(
                LucideIcons.truck,
                color: Color(0xFFBFDBFE),
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Bulk Orders &\nQuotation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Direct factory shipments & full carton lots from our Katargam warehouse.',
            style: TextStyle(
              color: Color(0xFFDBEAFE),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => setState(() => selectedIndex = 1),
                  icon: const Icon(LucideIcons.shoppingBag, size: 15),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Place Order',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showBulkOrderInquiryDialog(
                    context: context,
                    currentUser: currentUser,
                    catalogProducts: products,
                  ),
                  icon: const Icon(
                    LucideIcons.messageSquare,
                    size: 15,
                    color: Colors.white,
                  ),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Request Bulk Quote',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF93C5FD), width: 1.2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    final categories = categoryTabs.where((c) => c != 'All').toList();
    if (categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Explore Categories',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            InkWell(
              onTap: () => setState(() => selectedIndex = 1),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'All Categories',
                      style: TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: Color(0xFF2563EB),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final icon = _getCategoryIcon(cat);
              final count = products.where((p) => _isProductMatchingCategory(p, cat)).length;

              return InkWell(
                onTap: () {
                  setState(() {
                    selectedCategory = cat;
                    selectedIndex =
                        1; // Seamless jump to catalog with category filtered
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 110,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDBEAFE),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 22,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cat,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        '$count items',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
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
  }

  Widget _buildQuickActionHub() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Trade Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionCardItem(
                icon: LucideIcons.layoutGrid,
                iconBg: const Color(0xFFDBEAFE),
                iconColor: const Color(0xFF2563EB),
                title: 'Full Catalog',
                subtitle: 'Browse all products',
                onTap: () => setState(() => selectedIndex = 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCardItem(
                icon: LucideIcons.receiptText,
                iconBg: const Color(0xFFDBEAFE),
                iconColor: const Color(0xFF2563EB),
                title: 'Past Orders',
                subtitle: 'Track dispatches',
                onTap: () => handleProfileAction(ProfileAction.orders),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionCardItem(
                icon: LucideIcons.heart,
                iconBg: const Color(0xFFFFE4E6),
                iconColor: const Color(0xFFE11D48),
                title: 'Saved Items',
                subtitle: '${favoriteIds.length} favorited lots',
                onTap: () => setState(() => selectedIndex = 2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCardItem(
                icon: LucideIcons.mapPin,
                iconBg: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF16A34A),
                title: 'Pickup Hub',
                subtitle: 'Katargam Branch',
                onTap: () => showPickupLocationModal(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWarehouseHubCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.warehouse,
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
                      'Katargam Central Warehouse',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Surat, Gujarat • Main Logistics Hub',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: Color(0xFF16A34A)),
                    SizedBox(width: 4),
                    Text(
                      'OPEN',
                      style: TextStyle(
                        color: Color(0xFF166534),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Direct bay self-pickup and rapid freight loading available on all confirmed lots.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF475569),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              children: [
                _WarehouseDetailRow(
                  icon: LucideIcons.clock,
                  label: 'Operating Hours',
                  value: '9:00 AM - 8:00 PM (Mon - Sat)',
                ),
                SizedBox(height: 8),
                _WarehouseDetailRow(
                  icon: LucideIcons.truck,
                  label: 'Transport Options',
                  value: 'Self-Pickup & Gujarat Freight Dispatch',
                ),
                SizedBox(height: 8),
                _WarehouseDetailRow(
                  icon: LucideIcons.phoneCall,
                  label: 'Dispatch Desk',
                  value: '+91 99045 79700',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTierCard() {
    final tier = currentUser?.tier ?? CustomerTier.silver;
    final totalSpend = currentUser?.totalPurchases ?? 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.shieldCheck,
                  color: Color(0xFFD97706),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trade Partnership Tier',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      currentUser?.shopName ?? 'Verified Business Account',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              CustomerTierBadge(tier: tier),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Account Spend',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${totalSpend.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fulfillment Status',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Priority Packing',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQualityAssuranceGrid() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Goodwin Quality Assurance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: _AssuranceFeatureCard(
                  icon: LucideIcons.shieldCheck,
                  iconColor: Color(0xFF2563EB),
                  title: 'Grade-A Inspection',
                  description: 'Laboratory moisture & grade testing',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _AssuranceFeatureCard(
                  icon: LucideIcons.truck,
                  iconColor: Color(0xFF2563EB),
                  title: 'Same-Day Dispatch',
                  description: 'Priority bay pickup & fast logistics',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(
                child: _AssuranceFeatureCard(
                  icon: LucideIcons.scale,
                  iconColor: Color(0xFF7C3AED),
                  title: 'Certified Net Weight',
                  description: 'Calibrated digital scale weighing',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _AssuranceFeatureCard(
                  icon: LucideIcons.packageCheck,
                  iconColor: Color(0xFFD97706),
                  title: 'Export-Grade Packaging',
                  description: 'Multi-layer moisture lock cartons',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('cloth') || lower.contains('apparel')) {
      return LucideIcons.shirt;
    }
    if (lower.contains('elec') ||
        lower.contains('phone') ||
        lower.contains('device')) {
      return LucideIcons.smartphone;
    }
    if (lower.contains('home') || lower.contains('kitchen')) {
      return LucideIcons.house;
    }
    if (lower.contains('beauty') || lower.contains('cosmetic')) {
      return LucideIcons.sparkles;
    }
    if (lower.contains('toy') || lower.contains('game')) {
      return LucideIcons.gamepad2;
    }
    if (lower.contains('access') || lower.contains('watch')) {
      return LucideIcons.watch;
    }
    if (lower.contains('dry') || lower.contains('nut')) {
      return LucideIcons.leaf;
    }
    if (lower.contains('spice')) {
      return LucideIcons.flame;
    }
    if (lower.contains('bev') ||
        lower.contains('tea') ||
        lower.contains('coffee')) {
      return LucideIcons.coffee;
    }
    if (lower.contains('snack')) {
      return LucideIcons.cookie;
    }
    if (lower.contains('groc') ||
        lower.contains('staple') ||
        lower.contains('grain')) {
      return LucideIcons.wheat;
    }
    if (lower.contains('sweet') || lower.contains('conf')) {
      return LucideIcons.cake;
    }
    return LucideIcons.layoutGrid;
  }

  Widget _buildCatalogSearchField() {
    return TextField(
      controller: _catalogSearchController,
      onChanged: (value) {
        _searchDebounceTimer?.cancel();
        _searchDebounceTimer = Timer(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() {
              homeSearchQuery = value;
              _displayedProductCount = _batchSize;
            });
          }
        });
      },
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search catalog by name, category, SKU...',
        hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
        prefixIcon: const Icon(
          LucideIcons.search,
          color: Color(0xFF2563EB),
          size: 18,
        ),
        suffixIcon: homeSearchQuery.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchDebounceTimer?.cancel();
                  _catalogSearchController.clear();
                  setState(() {
                    homeSearchQuery = '';
                    _displayedProductCount = _batchSize;
                  });
                },
                icon: const Icon(LucideIcons.x, size: 18),
                tooltip: 'Clear search',
              ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildCategoryGroupHeader(String category, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getCategoryIcon(category),
              size: 15,
              color: const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            category,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count items',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Divider(color: Color(0xFFE2E8F0), thickness: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersBar() {
    final activeFilters = <Widget>[];

    if (homeSearchQuery.isNotEmpty) {
      activeFilters.add(
        _buildRemovableFilterChip(
          label: '"$homeSearchQuery"',
          icon: LucideIcons.search,
          onRemove: () {
            _searchDebounceTimer?.cancel();
            _catalogSearchController.clear();
            setState(() {
              homeSearchQuery = '';
              _displayedProductCount = _batchSize;
            });
          },
        ),
      );
    }

    if (selectedCategory != 'All') {
      activeFilters.add(
        _buildRemovableFilterChip(
          label: selectedCategory,
          icon: _getCategoryIcon(selectedCategory),
          onRemove: () => setState(() {
            selectedCategory = 'All';
            _displayedProductCount = _batchSize;
          }),
        ),
      );
    }

    if (filterCriteria.inStockOnly) {
      activeFilters.add(
        _buildRemovableFilterChip(
          label: 'In Stock Only',
          icon: LucideIcons.boxes,
          onRemove: () => setState(() {
            filterCriteria = ProductFilterCriteria(
              minPrice: filterCriteria.minPrice,
              maxPrice: filterCriteria.maxPrice,
              inStockOnly: false,
              featuredOnly: filterCriteria.featuredOnly,
              bestSellerOnly: filterCriteria.bestSellerOnly,
            );
            _displayedProductCount = _batchSize;
          }),
        ),
      );
    }

    if (filterCriteria.minPrice != null || filterCriteria.maxPrice != null) {
      final min = filterCriteria.minPrice != null
          ? '₹${filterCriteria.minPrice!.toInt()}'
          : '₹0';
      final max = filterCriteria.maxPrice != null
          ? '₹${filterCriteria.maxPrice!.toInt()}'
          : 'Any';
      activeFilters.add(
        _buildRemovableFilterChip(
          label: '$min - $max',
          icon: LucideIcons.indianRupee,
          onRemove: () => setState(() {
            filterCriteria = ProductFilterCriteria(
              minPrice: null,
              maxPrice: null,
              inStockOnly: filterCriteria.inStockOnly,
              featuredOnly: filterCriteria.featuredOnly,
              bestSellerOnly: filterCriteria.bestSellerOnly,
            );
            _displayedProductCount = _batchSize;
          }),
        ),
      );
    }

    if (activeFilters.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...activeFilters.map(
              (w) =>
                  Padding(padding: const EdgeInsets.only(right: 6), child: w),
            ),
            TextButton(
              onPressed: () {
                _searchDebounceTimer?.cancel();
                _catalogSearchController.clear();
                setState(() {
                  homeSearchQuery = '';
                  selectedCategory = 'All';
                  selectedSortOption = ProductSortOption.featured;
                  filterCriteria = const ProductFilterCriteria();
                  _displayedProductCount = _batchSize;
                });
              },
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              ),
              child: const Text(
                'Clear All',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemovableFilterChip({
    required String label,
    required IconData icon,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF2563EB)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                LucideIcons.x,
                size: 13,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCatalogTab() {
    final hasActiveFilterOrSearch =
        homeSearchQuery.isNotEmpty ||
        selectedCategory != 'All' ||
        !filterCriteria.isDefault;

    final visibleProducts = filteredProducts
        .take(_displayedProductCount)
        .toList();
    final hasMoreProducts = _displayedProductCount < filteredProducts.length;

    final showCategoryDividers =
        selectedCategory == 'All' &&
        (selectedSortOption == ProductSortOption.categoryAZ ||
            selectedSortOption == ProductSortOption.featured) &&
        homeSearchQuery.isEmpty;

    return Column(
      children: [
        // Top Unified Control Deck with smooth scroll-to-hide animation
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _isCatalogHeaderVisible
              ? Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(6),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Header & Quick Controls Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Catalog',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                hasActiveFilterOrSearch || hasMoreProducts
                                    ? 'Showing ${visibleProducts.length} of ${products.isNotEmpty ? products.length : filteredProducts.length} products'
                                    : '${products.isNotEmpty ? products.length : filteredProducts.length} Total Products Available',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      (hasActiveFilterOrSearch ||
                                          hasMoreProducts)
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Sort Button beside Title
                              InkWell(
                                onTap: _openProductSortSheet,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selectedSortOption !=
                                            ProductSortOption.featured
                                        ? const Color(0xFFDBEAFE)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selectedSortOption !=
                                              ProductSortOption.featured
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        selectedSortOption.icon,
                                        size: 13,
                                        color: selectedSortOption !=
                                                ProductSortOption.featured
                                            ? const Color(0xFF2563EB)
                                            : const Color(0xFF475569),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        selectedSortOption ==
                                                ProductSortOption.featured
                                            ? 'Sort'
                                            : selectedSortOption.label,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: selectedSortOption !=
                                                  ProductSortOption.featured
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: selectedSortOption !=
                                                  ProductSortOption.featured
                                              ? const Color(0xFF2563EB)
                                              : const Color(0xFF334155),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      const Icon(
                                        LucideIcons.chevronDown,
                                        size: 14,
                                        color: Color(0xFF64748B),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Filter Button beside Title
                              InkWell(
                                onTap: _openProductFilterSheet,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !filterCriteria.isDefault
                                        ? const Color(0xFFDBEAFE)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: !filterCriteria.isDefault
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        LucideIcons.slidersHorizontal,
                                        size: 13,
                                        color: !filterCriteria.isDefault
                                            ? const Color(0xFF2563EB)
                                            : const Color(0xFF475569),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        filterCriteria.isDefault
                                            ? 'Filter'
                                            : 'Filter (${filterCriteria.activeFiltersCount})',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: !filterCriteria.isDefault
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: !filterCriteria.isDefault
                                              ? const Color(0xFF2563EB)
                                              : const Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 2. Search Input
                      _buildCatalogSearchField(),
                      const SizedBox(height: 10),

                      // 3. Category Filter Chips Carousel
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categoryTabs.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final category = categoryTabs[index];
                            final isSelected = selectedCategory == category;

                            return ChoiceChip(
                              label: Text(
                                category,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF334155),
                                  fontSize: 12.5,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: const Color(0xFF2563EB),
                              backgroundColor: const Color(0xFFF8FAFC),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              showCheckmark: false,
                              onSelected: (_) => setState(() {
                                selectedCategory = category;
                                _displayedProductCount = _batchSize;
                              }),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 4. Active Removable Filters Bar
                      _buildActiveFiltersBar(),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // Product Listings Area with Lazy Infinite Scrolling
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is UserScrollNotification) {
                if (notification.direction == ScrollDirection.reverse) {
                  if (_isCatalogHeaderVisible) {
                    setState(() => _isCatalogHeaderVisible = false);
                  }
                } else if (notification.direction == ScrollDirection.forward) {
                  if (!_isCatalogHeaderVisible) {
                    setState(() => _isCatalogHeaderVisible = true);
                  }
                }
              } else if (notification is ScrollUpdateNotification ||
                  notification is ScrollEndNotification) {
                if (notification.metrics.pixels <= 10 &&
                    !_isCatalogHeaderVisible) {
                  setState(() => _isCatalogHeaderVisible = true);
                }
                if (notification.metrics.extentAfter < 300) {
                  if (!_isLoadingMore &&
                      _displayedProductCount < filteredProducts.length) {
                    _loadMoreProducts();
                  }
                }
              }
              return false;
            },
            child: isLoadingProducts && products.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF2563EB),
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Loading wholesale catalog...',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : filteredProducts.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.searchX,
                              size: 36,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            selectedCategory == 'All'
                                ? (homeSearchQuery.isNotEmpty
                                      ? 'No results for "$homeSearchQuery"'
                                      : 'No Products in Catalog')
                                : 'No products in "$selectedCategory"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            hasActiveFilterOrSearch
                                ? 'Try adjusting your search keywords or clearing active filters to view all products.'
                                : 'Products added to the database will appear here.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (hasActiveFilterOrSearch)
                            FilledButton.icon(
                              onPressed: () {
                                _searchDebounceTimer?.cancel();
                                _catalogSearchController.clear();
                                setState(() {
                                  homeSearchQuery = '';
                                  selectedCategory = 'All';
                                  selectedSortOption =
                                      ProductSortOption.featured;
                                  filterCriteria =
                                      const ProductFilterCriteria();
                                  _displayedProductCount = _batchSize;
                                });
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                              icon: const Icon(LucideIcons.rotateCcw, size: 16),
                              label: const Text(
                                'Clear Filters & Show All',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          else if (products.isEmpty)
                            FilledButton.icon(
                              onPressed: () async {
                                setState(() => isLoadingProducts = true);
                                await _productRepository.seedDemoData();
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                              ),
                              icon: const Icon(LucideIcons.uploadCloud),
                              label: const Text('Seed Products to Firebase'),
                            ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount:
                        visibleProducts.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == visibleProducts.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Loading more wholesale products...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final product = visibleProducts[index];
                      final isFirstOfCategory =
                          showCategoryDividers &&
                          (index == 0 ||
                              visibleProducts[index - 1].category !=
                                  product.category);

                      final categoryCount = products
                          .where((p) => _isProductMatchingCategory(p, product.category))
                          .length;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isFirstOfCategory)
                            _buildCategoryGroupHeader(
                              product.category,
                              categoryCount,
                            ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ModernProductCard(
                              product: product,
                              isFavorite: favoriteIds.contains(product.id),
                              quantity: getQuantity(product.id),
                              isAdmin: isAdminUser,
                              onTap: () => openProduct(product),
                              onToggleFavorite: () =>
                                  toggleFavorite(product.id),
                              onSetQuantity: (q) => setQuantity(product.id, q),
                              onAddToCart: () {
                                final cartQty = getCartQuantity(product.id);
                                final staged = productQuantities[product.id];
                                if (cartQty == 0 &&
                                    staged != null &&
                                    staged > 1) {
                                  addToCart(product, quantity: staged);
                                } else {
                                  addToCart(product, quantity: 1);
                                }
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget buildFavoritesTab() {
    final favoriteProducts = products
        .where((product) => favoriteIds.contains(product.id))
        .toList();

    if (favoriteProducts.isEmpty) {
      return EmptyStateView(
        icon: LucideIcons.heart,
        title: 'No Favorites Yet',
        description:
            'Tap the heart icon on any wholesale product to save it. You can easily compare and reorder your favorites anytime.',
        buttonText: 'Explore Catalog',
        themeColor: const Color(0xFFE11D48),
        onAction: () => setState(() => selectedIndex = 0),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: favoriteProducts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final product = favoriteProducts[index];
        return ModernProductCard(
          product: product,
          isFavorite: true,
          quantity: getQuantity(product.id),
          isAdmin: isAdminUser,
          onTap: () => openProduct(product),
          onToggleFavorite: () => toggleFavorite(product.id),
          onSetQuantity: (q) => setQuantity(product.id, q),
          onAddToCart: () {
            final cartQty = getCartQuantity(product.id);
            final staged = productQuantities[product.id];
            if (cartQty == 0 && staged != null && staged > 1) {
              addToCart(product, quantity: staged);
            } else {
              addToCart(product, quantity: 1);
            }
          },
        );
      },
    );
  }

  Widget buildCartTab() {
    if (cart.isEmpty) {
      return EmptyStateView(
        icon: LucideIcons.shoppingBag,
        title: 'Your Cart is Empty',
        description:
            'Add wholesale items from the catalog. They will stay saved in your account across all your devices.',
        buttonText: 'Start Shopping',
        themeColor: const Color(0xFF2563EB),
        onAction: () => setState(() => selectedIndex = 0),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cart.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final cartItem = cart[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFF1F5F9), width: 1.2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ProductImageWidget(
                        imageSrc: cartItem.displayImage,
                        width: 68,
                        height: 68,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cartItem.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${cartItem.unitPrice.toStringAsFixed(0)} / unit',
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 3,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: cartItem.quantity > 1
                                        ? () => updateCartQuantity(
                                            cartItem,
                                            cartItem.quantity - 1,
                                          )
                                        : () => confirmRemoveFromCart(cartItem),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(5),
                                      child: Icon(
                                        cartItem.quantity > 1
                                            ? LucideIcons.minus
                                            : LucideIcons.trash2,
                                        size: 17,
                                        color: cartItem.quantity > 1
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  InkWell(
                                    onTap: () async {
                                      final newQty =
                                          await showQuantityInputDialog(
                                            context: context,
                                            initialQuantity: cartItem.quantity,
                                            productName: cartItem.displayName,
                                            maxQuantity:
                                                cartItem.maxAvailableStock,
                                          );
                                      if (newQty != null) {
                                        if (newQty == 0) {
                                          confirmRemoveFromCart(cartItem);
                                        } else {
                                          updateCartQuantity(cartItem, newQty);
                                        }
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 34,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFCBD5E1),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        '${cartItem.quantity}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  InkWell(
                                    onTap:
                                        cartItem.quantity <
                                            cartItem.maxAvailableStock
                                        ? () => updateCartQuantity(
                                            cartItem,
                                            cartItem.quantity + 1,
                                          )
                                        : null,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(5),
                                      child: Icon(
                                        LucideIcons.plus,
                                        size: 17,
                                        color:
                                            cartItem.quantity <
                                                cartItem.maxAvailableStock
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${cartItem.totalPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(height: 8),
                          IconButton(
                            onPressed: () => confirmRemoveFromCart(cartItem),
                            icon: const Icon(
                              LucideIcons.trash2,
                              size: 20,
                            ),
                            color: const Color(0xFFDC2626),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Remove item',
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(12),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Order Subtotal',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    '₹${cartTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final method = await showCheckoutFulfillmentSheet(context);
                    if (method == null || !mounted) return;

                    bool? completed;
                    if (method == FulfillmentMethod.warehousePickup) {
                      completed = await Navigator.of(context).push<bool>(
                        MaterialPageRoute<bool>(
                          builder: (_) => CheckoutPage(
                            items: List<CartItem>.from(cart),
                            currentUser: currentUser,
                          ),
                        ),
                      );
                    } else {
                      completed = await Navigator.of(context).push<bool>(
                        MaterialPageRoute<bool>(
                          builder: (_) => PrepaidDeliveryRazorpayPage(
                            items: List<CartItem>.from(cart),
                            currentUser: currentUser,
                          ),
                        ),
                      );
                    }

                    if (completed == true && mounted) {
                      setState(() {
                        cart.clear();
                        selectedIndex = 0;
                      });
                      if (currentUser != null) {
                        unawaited(
                          _userRepository.syncCart(currentUser!.id, []),
                        );
                      }
                    }
                  },
                  icon: const Icon(LucideIcons.arrowRight, size: 18),
                  label: const Text('Proceed to Checkout'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      buildHomeTab(),
      buildCatalogTab(),
      buildFavoritesTab(),
      buildCartTab(),
    ];

    final isAdmin =
        currentUser?.role == UserRole.superAdmin ||
        currentUser?.role == UserRole.manager ||
        FirestoreUserRepository.isSuperAdminPhone(currentUser?.phone);

    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ProfileAvatarWidget(
                          radius: 26,
                          photoUrl: currentUser?.photoUrl,
                          name: currentUser?.name.isNotEmpty == true
                              ? currentUser!.name
                              : (isAdmin ? 'Admin' : 'Reseller'),
                          showCameraBadge: false,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      currentUser?.name.isNotEmpty == true
                                          ? currentUser!.name
                                          : (isAdmin
                                                ? 'Goodwin Admin'
                                                : 'Goodwin Reseller'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  CustomerTierBadge(
                                    tier:
                                        currentUser?.tier ??
                                        CustomerTier.silver,
                                    isCompact: true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                currentUser?.shopName != null &&
                                        currentUser!.shopName!.isNotEmpty
                                    ? currentUser!.shopName!
                                    : (isAdmin
                                          ? 'Central Administrator'
                                          : 'Wholesale Partner'),
                                style: const TextStyle(
                                  color: Color(0xFFDBEAFE),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      currentUser?.phone.isNotEmpty == true
                          ? currentUser!.phone
                          : (currentUser?.email ?? 'wholesale@goodwin.com'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAdmin) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text(
                    'ADMIN MANAGEMENT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2563EB),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                DrawerProfileItem(
                  icon: LucideIcons.packagePlus,
                  label: 'Manage Products',
                  action: ProfileAction.manageProducts,
                  onSelected: handleProfileAction,
                ),
                DrawerProfileItem(
                  icon: LucideIcons.clipboardList,
                  label: 'Customer Orders',
                  action: ProfileAction.allOrders,
                  onSelected: handleProfileAction,
                ),
                DrawerProfileItem(
                  icon: LucideIcons.messageSquare,
                  label: 'Bulk Quotes',
                  action: ProfileAction.adminBulkQuotes,
                  onSelected: handleProfileAction,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Divider(height: 1),
                ),
              ],
              const SizedBox(height: 4),
              DrawerProfileItem(
                icon: LucideIcons.user,
                label: 'My profile',
                action: ProfileAction.profile,
                onSelected: handleProfileAction,
              ),
              DrawerProfileItem(
                icon: LucideIcons.receiptText,
                label: 'My orders',
                action: ProfileAction.orders,
                onSelected: handleProfileAction,
              ),
              DrawerProfileItem(
                icon: LucideIcons.messageSquare,
                label: 'My Bulk Quotes',
                action: ProfileAction.bulkQuotes,
                onSelected: handleProfileAction,
              ),
              DrawerProfileItem(
                icon: LucideIcons.mapPin,
                label: 'Pickup location',
                action: ProfileAction.addresses,
                onSelected: handleProfileAction,
              ),
              DrawerProfileItem(
                icon: LucideIcons.headphones,
                label: 'Help & support',
                action: ProfileAction.help,
                onSelected: handleProfileAction,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Divider(height: 1),
              ),
              DrawerProfileItem(
                icon: LucideIcons.logOut,
                label: 'Sign out',
                action: ProfileAction.signOut,
                isDestructive: true,
                onSelected: handleProfileAction,
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                LucideIcons.store,
                color: Color(0xFF2563EB),
                size: 19,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'GOODWIN',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 18,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          ListenableBuilder(
            listenable: NotificationController(),
            builder: (context, _) {
              final unread = NotificationController().unreadCount;
              return IconButton(
                tooltip: 'Stock Alerts & Notifications',
                icon: unread > 0
                    ? Badge.count(
                        count: unread,
                        backgroundColor: const Color(0xFFDC2626),
                        textColor: Colors.white,
                        child: const Icon(
                          LucideIcons.bell,
                          color: Color(0xFF1E293B),
                        ),
                      )
                    : const Icon(
                        LucideIcons.bell,
                        color: Color(0xFF1E293B),
                      ),
                onPressed: () => showNotificationsSheet(context),
              );
            },
          ),
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: 'Add Product',
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    LucideIcons.plus,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => const AddEditProductDialog(),
                  );
                },
              ),
            ),
        ],
      ),
      body: pages[selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (value) => setState(() => selectedIndex = value),
        destinations: [
          const NavigationDestination(
            icon: Icon(LucideIcons.house),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(LucideIcons.layoutGrid),
            label: 'Catalog',
          ),
          const NavigationDestination(
            icon: Icon(LucideIcons.heart),
            label: 'Favorites',
          ),
          NavigationDestination(
            icon: totalCartItemCount > 0
                ? Badge.count(
                    count: totalCartItemCount,
                    backgroundColor: const Color(0xFF2563EB),
                    textColor: Colors.white,
                    child: const Icon(LucideIcons.shoppingBag),
                  )
                : const Icon(LucideIcons.shoppingBag),
            label: 'Cart',
          ),
        ],
      ),
    );
  }

  void showNotificationsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: NotificationController(),
          builder: (context, _) {
            final notifications = NotificationController().notifications;
            final unreadCount = NotificationController().unreadCount;

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            LucideIcons.bellRing,
                            color: Color(0xFFD97706),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Stock & Order Alerts',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                unreadCount > 0
                                    ? '$unreadCount unread notification${unreadCount > 1 ? "s" : ""}'
                                    : 'All notifications up to date',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: unreadCount > 0
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (notifications.isNotEmpty)
                          PopupMenuButton<String>(
                            icon: const Icon(LucideIcons.ellipsisVertical),
                            onSelected: (val) {
                              if (val == 'read') {
                                NotificationController().markAllAsRead();
                              } else if (val == 'clear') {
                                NotificationController().clearAll();
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'read',
                                child: Text('Mark all as read'),
                              ),
                              const PopupMenuItem(
                                value: 'clear',
                                child: Text(
                                  'Clear all',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: notifications.isEmpty
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
                                  child: const Icon(
                                    LucideIcons.bell,
                                    size: 40,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No alerts right now',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 40),
                                  child: Text(
                                    'When favorited items drop below 100 units in stock, you will receive real-time alerts here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount: notifications.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final alert = notifications[index];
                              return InkWell(
                                onTap: () {
                                  NotificationController().markAsRead(alert.id);
                                  final matched = products.firstWhere(
                                    (p) => p.id == alert.productId,
                                    orElse: () => products.first,
                                  );
                                  Navigator.pop(ctx);
                                  openProduct(matched);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: alert.isRead
                                        ? const Color(0xFFF8FAFC)
                                        : const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: alert.isRead
                                          ? const Color(0xFFE2E8F0)
                                          : const Color(0xFFFDE68A),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ProductImageWidget(
                                        imageSrc: alert.productImage,
                                        width: 50,
                                        height: 50,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    alert.productName,
                                                    style: TextStyle(
                                                      fontWeight: alert.isRead
                                                          ? FontWeight.w700
                                                          : FontWeight.w900,
                                                      fontSize: 14,
                                                      color: const Color(
                                                        0xFF0F172A,
                                                      ),
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 7,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFFEF2F2,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    border: Border.all(
                                                      color: const Color(
                                                        0xFFFCA5A5,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    '${alert.stockQuantity} left',
                                                    style: const TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Color(0xFFDC2626),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              alert.message,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF475569),
                                                height: 1.3,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'Tap to view product',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: Theme.of(context)
                                                        .primaryColor,
                                                  ),
                                                ),
                                                IconButton(
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  icon: const Icon(
                                                    LucideIcons.x,
                                                    size: 16,
                                                    color: Color(0xFF94A3B8),
                                                  ),
                                                  onPressed: () {
                                                    NotificationController()
                                                        .removeNotification(
                                                          alert.id,
                                                        );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ActionCardItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCardItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarehouseDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WarehouseDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF2563EB)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _AssuranceFeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _AssuranceFeatureCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF64748B),
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
