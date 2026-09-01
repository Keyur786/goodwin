import 'package:goodwin/models/category_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:goodwin/core/constants/app_constants.dart';
import 'package:goodwin/core/services/firestore_product_repository.dart';
import 'package:goodwin/core/services/firestore_user_repository.dart';
import 'package:goodwin/core/utils/quantity_dialog.dart';
import 'package:goodwin/features/admin/dialogs/add_edit_product_dialog.dart';
import 'package:goodwin/features/admin/screens/admin_all_orders_screen.dart';
import 'package:goodwin/features/admin/screens/admin_product_manager_screen.dart';
import 'package:goodwin/features/customer/payment/prepaid_razorpay_screen.dart';
import 'package:goodwin/features/customer/screens/checkout_screen.dart';
import 'package:goodwin/features/customer/screens/customer_orders_screen.dart';
import 'package:goodwin/features/customer/screens/product_detail_screen.dart';
import 'package:goodwin/features/customer/screens/profile_screen.dart';
import 'package:goodwin/models/cart_item.dart';
import 'package:goodwin/models/demo_product.dart';
import 'package:goodwin/models/filter_criteria.dart';
import 'package:goodwin/models/product_model.dart';
import 'package:goodwin/models/user_model.dart';
import 'package:goodwin/shared/widgets/customer_tier_badge.dart';
import 'package:goodwin/shared/widgets/empty_state_view.dart';
import 'package:goodwin/shared/widgets/modern_product_card.dart';
import 'package:goodwin/shared/widgets/product_image_widget.dart';
import 'package:goodwin/shared/widgets/profile_avatar_widget.dart';

class DemoHomeScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const DemoHomeScreen({super.key, required this.onLogout});

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
  List<String> categoryTabs = <String>['All'];
  final Set<String> favoriteIds = <String>{};
  final List<CartItem> cart = <CartItem>[];
  final Map<String, int> productQuantities = <String, int>{};

  StreamSubscription<AppUser?>? _userSub;
  StreamSubscription<List<ProductModel>>? _productsSub;
  StreamSubscription<List<CategoryModel>>? _categoriesSub;
  Timer? _cartDebounceTimer;
  Timer? _favoritesDebounceTimer;
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _initFirebaseData();
  }

  @override
  void dispose() {
    _cartDebounceTimer?.cancel();
    _favoritesDebounceTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _userSub?.cancel();
    _productsSub?.cancel();
    _categoriesSub?.cancel();
    super.dispose();
  }

  Future<void> _initFirebaseData() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      // 1. Ensure user has a profile and unique 6-alphabet username in Firestore
      final user = await _userRepository.getOrCreateUser(firebaseUser);
      if (mounted) {
        setState(() {
          currentUser = user;
          favoriteIds.addAll(user.favorites);
        });
      }

      // Listen for real-time user updates (profile changes, username changes)
      _userSub = _userRepository.streamUser(firebaseUser.uid).listen((user) {
        if (user != null && mounted) {
          setState(() {
            currentUser = user;
            favoriteIds.clear();
            favoriteIds.addAll(user.favorites);
          });
          _syncCartFromUserData(user.cart);
        }
      });
    }

    // 2. Stream products from Firestore
    _productsSub = _productRepository.streamProducts().listen(
      (firestoreProducts) {
        if (mounted) {
          setState(() {
            isLoadingProducts = false;
            products = firestoreProducts
                .map((p) => DemoProduct.fromProductModel(p))
                .toList();

            if (categoryTabs.length <= 1 && products.isNotEmpty) {
              final dynamicCats = products
                  .map((p) => p.category)
                  .toSet()
                  .toList();
              categoryTabs = ['All', ...dynamicCats];
            }
          });
          if (currentUser != null && currentUser!.cart.isNotEmpty) {
            _syncCartFromUserData(currentUser!.cart);
          }
        }
      },
      onError: (_) {
        if (mounted) setState(() => isLoadingProducts = false);
      },
    );

    // 3. Stream categories from Firestore
    _categoriesSub = _productRepository.streamCategories().listen((
      firestoreCategories,
    ) {
      if (firestoreCategories.isNotEmpty && mounted) {
        setState(() {
          final catNames = firestoreCategories
              .map((c) => c.name)
              .toSet()
              .toList();
          categoryTabs = ['All', ...catNames];
        });
      }
    });

    // 4. Timeout safeguard to never keep user stuck on loading spinner
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && isLoadingProducts && products.isEmpty) {
        setState(() => isLoadingProducts = false);
      }
    });

    // 5. Ensure catalog is seeded to Firestore
    unawaited(_productRepository.seedDemoDataIfNeeded());
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
          image:
              'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?auto=format&fit=crop&w=900&q=80',
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
      final matchesCategory =
          selectedCategory == 'All' ||
          product.category.toLowerCase() == selectedCategory.toLowerCase();

      final matchesSearch = tokens.isEmpty ||
          tokens.every((token) {
            final inName = product.name.toLowerCase().contains(token);
            final inCategory = product.category.toLowerCase().contains(token);
            final inDescription = product.description.toLowerCase().contains(token);
            final inTags = product.tags.any((tag) => tag.toLowerCase().contains(token));
            final inVariants = product.variants.any((v) =>
                v.name.toLowerCase().contains(token) ||
                v.sku.toLowerCase().contains(token));
            return inName || inCategory || inDescription || inTags || inVariants;
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
      case ProductSortOption.featured:
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
  }

  void addToCart(
    DemoProduct product, {
    int quantity = 1,
    ProductVariantModel? variant,
  }) {
    final maxStock =
        variant != null ? variant.availableQty : product.availableQty;
    if (maxStock <= 0) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} is currently out of stock'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  void updateCartQuantity(CartItem item, int quantity) {
    setState(() {
      if (quantity <= 0) {
        cart.remove(item);
      } else {
        item.quantity = quantity.clamp(
          1,
          item.maxAvailableStock > 0 ? item.maxAvailableStock : 1,
        );
      }
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

    final message = switch (action) {
      ProfileAction.addresses => 'Warehouse pickup: Katargam Branch, Surat.',
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
          onAddToCart: (product, {int quantity = 1, ProductVariantModel? variant}) =>
              addToCart(product, quantity: quantity, variant: variant),
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
                          icon: const Icon(Icons.close_rounded),
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
                              ? const Color(0xFF0F766E)
                              : const Color(0xFF64748B),
                        ),
                        title: Text(
                          option.label,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFF0F766E)
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF0F766E),
                              )
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: isSelected ? const Color(0xFFF0FDFA) : null,
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
                          selectedColor: const Color(0xFFCCFBF1),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFF0F766E)
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
                      activeThumbColor: const Color(0xFF0F766E),
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
                          selectedColor: const Color(0xFFCCFBF1),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: tempFeatured
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: tempFeatured
                                ? const Color(0xFF0F766E)
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
                          selectedColor: const Color(0xFFCCFBF1),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: tempBestSeller
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: tempBestSeller
                                ? const Color(0xFF0F766E)
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
                        backgroundColor: const Color(0xFF0F766E),
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
    final rawQuery = homeSearchQuery.trim().toLowerCase();
    final tokens = rawQuery.isEmpty
        ? <String>[]
        : rawQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    final featured = products
        .where(
          (product) =>
              tokens.isEmpty ||
              tokens.every((token) {
                final inName = product.name.toLowerCase().contains(token);
                final inCategory = product.category.toLowerCase().contains(token);
                final inDescription = product.description.toLowerCase().contains(token);
                final inTags = product.tags.any((tag) => tag.toLowerCase().contains(token));
                final inVariants = product.variants.any((v) =>
                    v.name.toLowerCase().contains(token) ||
                    v.sku.toLowerCase().contains(token));
                return inName || inCategory || inDescription || inTags || inVariants;
              }),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          onChanged: (value) {
            _searchDebounceTimer?.cancel();
            _searchDebounceTimer = Timer(const Duration(milliseconds: 250), () {
              if (mounted) setState(() => homeSearchQuery = value);
            });
          },
          onSubmitted: (_) {
            FocusScope.of(context).unfocus();
            setState(() => selectedIndex = 1);
          },
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search products',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: homeSearchQuery.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchDebounceTimer?.cancel();
                      setState(() => homeSearchQuery = '');
                    },
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear search',
                  ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          rawQuery.isEmpty ? 'Trending Products' : 'Search results',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (isLoadingProducts && products.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Loading products...'),
                ],
              ),
            ),
          )
        else if (products.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 60,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No products yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Upload your catalog to Firestore to view them here.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      setState(() => isLoadingProducts = true);
                      await _productRepository.seedDemoData();
                    },
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Seed Wholesale Catalog'),
                  ),
                ],
              ),
            ),
          )
        else if (featured.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: Text('No products match your search.')),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: featured.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final product = featured[index];
              return ModernProductCard(
                product: product,
                isFavorite: favoriteIds.contains(product.id),
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
          ),
      ],
    );
  }

  Widget buildCatalogTab() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Catalog',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.filter_list_rounded,
                      size: 15,
                      color: Color(0xFF0F766E),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      selectedCategory,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                    fontSize: 13,
                  ),
                ),
                selected: isSelected,
                selectedColor: const Color(0xFF0F766E),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF0F766E)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                showCheckmark: false,
                onSelected: (_) => setState(() => selectedCategory = category),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Sort & Filter Action Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Sort Button
              InkWell(
                onTap: _openProductSortSheet,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: selectedSortOption != ProductSortOption.featured
                        ? const Color(0xFFCCFBF1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selectedSortOption != ProductSortOption.featured
                          ? const Color(0xFF0F766E)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selectedSortOption.icon,
                        size: 14,
                        color: selectedSortOption != ProductSortOption.featured
                            ? const Color(0xFF0F766E)
                            : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        selectedSortOption.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              selectedSortOption != ProductSortOption.featured
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color:
                              selectedSortOption != ProductSortOption.featured
                              ? const Color(0xFF0F766E)
                              : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 2),
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

              // Filter Button with Badge
              InkWell(
                onTap: _openProductFilterSheet,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: !filterCriteria.isDefault
                        ? const Color(0xFFCCFBF1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: !filterCriteria.isDefault
                          ? const Color(0xFF0F766E)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 14,
                        color: !filterCriteria.isDefault
                            ? const Color(0xFF0F766E)
                            : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        filterCriteria.isDefault
                            ? 'Filters'
                            : 'Filters (${filterCriteria.activeFiltersCount})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: !filterCriteria.isDefault
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: !filterCriteria.isDefault
                              ? const Color(0xFF0F766E)
                              : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (!filterCriteria.isDefault ||
                  selectedSortOption != ProductSortOption.featured) ...[
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedSortOption = ProductSortOption.featured;
                      filterCriteria = const ProductFilterCriteria();
                    });
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  child: const Text(
                    'Reset',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: isLoadingProducts && products.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Loading catalog...'),
                    ],
                  ),
                )
              : filteredProducts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.category_outlined,
                        size: 60,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        selectedCategory == 'All'
                            ? 'No products in Firebase'
                            : 'No products in "$selectedCategory"',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (products.isEmpty)
                        FilledButton.icon(
                          onPressed: () async {
                            setState(() => isLoadingProducts = true);
                            await _productRepository.seedDemoData();
                          },
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: const Text('Seed Products to Firebase'),
                        ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredProducts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return ModernProductCard(
                      product: product,
                      isFavorite: favoriteIds.contains(product.id),
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
        icon: Icons.favorite_border_rounded,
        title: 'No Favorites Yet',
        description: 'Tap the heart icon on any wholesale product to save it. You can easily compare and reorder your favorites anytime.',
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
        icon: Icons.shopping_bag_outlined,
        title: 'Your Cart is Empty',
        description: 'Add wholesale items from the catalog. They will stay saved in your account across all your devices.',
        buttonText: 'Start Shopping',
        themeColor: const Color(0xFF0F766E),
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
                                color: Color(0xFF0F766E),
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
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 1,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () => updateCartQuantity(
                                      cartItem,
                                      cartItem.quantity - 1,
                                    ),
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
                                      final newQty =
                                          await showQuantityInputDialog(
                                            context: context,
                                            initialQuantity: cartItem.quantity,
                                            productName: cartItem.displayName,
                                            maxQuantity: cartItem.maxAvailableStock,
                                          );
                                      if (newQty != null) {
                                        updateCartQuantity(cartItem, newQty);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
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
                                        '${cartItem.quantity}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: Color(0xFF0F766E),
                                        ),
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: cartItem.quantity < cartItem.maxAvailableStock
                                        ? () => updateCartQuantity(
                                              cartItem,
                                              cartItem.quantity + 1,
                                            )
                                        : null,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.all(3),
                                      child: Icon(
                                        Icons.add_rounded,
                                        size: 16,
                                        color: cartItem.quantity < cartItem.maxAvailableStock
                                            ? const Color(0xFF475569)
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
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          IconButton(
                            onPressed: () => removeFromCart(cartItem),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                            ),
                            color: Colors.red.shade600,
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
                      color: Color(0xFF0F766E),
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
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
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

    final usernameDisplay = currentUser?.username != null
        ? '@${currentUser!.username}'
        : (isAdmin ? '@admin' : 'Goodwin Reseller');

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
                    colors: [Color(0xFF0F766E), Color(0xFF115E59)],
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
                                  if (!isAdmin) ...[
                                    const SizedBox(width: 6),
                                    CustomerTierBadge(
                                      tier:
                                          currentUser?.tier ??
                                          CustomerTier.silver,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isAdmin
                                      ? const Color(0xFFFEF08A)
                                      : Colors.white.withAlpha(50),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isAdmin ? '🛡️ STORE ADMIN' : usernameDisplay,
                                  style: TextStyle(
                                    color: isAdmin
                                        ? const Color(0xFF854D0E)
                                        : Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    letterSpacing: 0.8,
                                  ),
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
                      color: Color(0xFF0F766E),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                DrawerProfileItem(
                  icon: Icons.add_business_rounded,
                  label: 'Add & Manage Products',
                  action: ProfileAction.manageProducts,
                  onSelected: handleProfileAction,
                ),
                DrawerProfileItem(
                  icon: Icons.assignment_rounded,
                  label: 'All Placed Customer Orders',
                  action: ProfileAction.allOrders,
                  onSelected: handleProfileAction,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Divider(height: 1),
                ),
              ],
              const SizedBox(height: 4),
              DrawerProfileItem(
                icon: Icons.person_rounded,
                label: 'My profile',
                action: ProfileAction.profile,
                onSelected: handleProfileAction,
              ),
              DrawerProfileItem(
                icon: Icons.receipt_long_rounded,
                label: 'My orders',
                action: ProfileAction.orders,
                onSelected: handleProfileAction,
              ),
              DrawerProfileItem(
                icon: Icons.location_on_rounded,
                label: 'Pickup location',
                action: ProfileAction.addresses,
                onSelected: handleProfileAction,
              ),
              DrawerProfileItem(
                icon: Icons.headset_mic_rounded,
                label: 'Help & support',
                action: ProfileAction.help,
                onSelected: handleProfileAction,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Divider(height: 1),
              ),
              DrawerProfileItem(
                icon: Icons.logout_rounded,
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
                color: const Color(0xFF0F766E).withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Color(0xFF0F766E),
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
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: 'Add Product',
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
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Catalog',
          ),
          const NavigationDestination(
            icon: Icon(Icons.favorite_rounded),
            label: 'Favorites',
          ),
          NavigationDestination(
            icon: totalCartItemCount > 0
                ? Badge.count(
                    count: totalCartItemCount,
                    backgroundColor: const Color(0xFF0F766E),
                    textColor: Colors.white,
                    child: const Icon(Icons.shopping_bag_outlined),
                  )
                : const Icon(Icons.shopping_bag_outlined),
            selectedIcon: totalCartItemCount > 0
                ? Badge.count(
                    count: totalCartItemCount,
                    backgroundColor: const Color(0xFF0F766E),
                    textColor: Colors.white,
                    child: const Icon(Icons.shopping_bag_rounded),
                  )
                : const Icon(Icons.shopping_bag_rounded),
            label: 'Cart',
          ),
        ],
      ),
    );
  }
}


