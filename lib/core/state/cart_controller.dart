import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:goodwin/core/services/firestore_user_repository.dart';
import 'package:goodwin/models/cart_item.dart';
import 'package:goodwin/models/demo_product.dart';
import 'package:goodwin/models/product_model.dart';

class CartController extends ChangeNotifier {
  static final CartController instance = CartController();

  final FirestoreUserRepository? _userRepository;
  final List<CartItem> _items = [];
  Timer? _debounceTimer;
  String? _currentUserId;

  CartController({FirestoreUserRepository? repository})
      : _userRepository = repository;

  List<CartItem> get items => List.unmodifiable(_items);

  int get totalItemCount => _items.fold<int>(0, (sum, item) => sum + item.quantity);

  double get totalAmount => _items.fold<double>(0.0, (sum, item) => sum + item.totalPrice);

  bool get isEmpty => _items.isEmpty;

  bool get isNotEmpty => _items.isNotEmpty;

  void setCurrentUser(String? userId) {
    _currentUserId = userId;
  }

  int getQuantity(String productId, [String? variantId]) {
    for (final item in _items) {
      if (item.product.id == productId) {
        if (variantId == null || item.selectedVariant?.id == variantId) {
          return item.quantity;
        }
      }
    }
    return 0;
  }

  void addItem(
    DemoProduct product, {
    int quantity = 1,
    ProductVariantModel? variant,
    String? userId,
  }) {
    if (userId != null) _currentUserId = userId;
    if (quantity <= 0) return;

    final targetVariantId = variant?.id;
    final index = _items.indexWhere(
      (item) =>
          item.product.id == product.id &&
          item.selectedVariant?.id == targetVariantId,
    );

    if (index >= 0) {
      _items[index].quantity += quantity;
    } else {
      _items.add(
        CartItem(
          product: product,
          quantity: quantity,
          selectedVariant: variant,
        ),
      );
    }

    notifyListeners();
    _scheduleSync();
  }

  void setQuantity(
    String productId,
    int quantity, {
    ProductVariantModel? variant,
    DemoProduct? productFallback,
    String? userId,
  }) {
    if (userId != null) _currentUserId = userId;

    final targetVariantId = variant?.id;
    final index = _items.indexWhere(
      (item) =>
          item.product.id == productId &&
          item.selectedVariant?.id == targetVariantId,
    );

    if (quantity <= 0) {
      if (index >= 0) {
        _items.removeAt(index);
        notifyListeners();
        _scheduleSync();
      }
      return;
    }

    if (index >= 0) {
      _items[index].quantity = quantity;
    } else if (productFallback != null) {
      _items.add(
        CartItem(
          product: productFallback,
          quantity: quantity,
          selectedVariant: variant,
        ),
      );
    }

    notifyListeners();
    _scheduleSync();
  }

  void removeItem(String productId, {String? variantId, String? userId}) {
    if (userId != null) _currentUserId = userId;
    _items.removeWhere(
      (item) =>
          item.product.id == productId &&
          (variantId == null || item.selectedVariant?.id == variantId),
    );
    notifyListeners();
    _scheduleSync();
  }

  void clear({String? userId}) {
    if (userId != null) _currentUserId = userId;
    _items.clear();
    notifyListeners();
    _scheduleSync();
  }

  void syncFromUserData(
    List<Map<String, dynamic>> savedCart,
    List<DemoProduct> catalog, {
    String? userId,
  }) {
    if (userId != null) _currentUserId = userId;
    final restoredCart = <CartItem>[];

    for (final raw in savedCart) {
      final pid = raw['productId']?.toString() ?? '';
      final qty = (raw['quantity'] as num?)?.toInt() ?? 1;
      final vid = raw['variantId']?.toString();

      DemoProduct? matchedProduct;
      for (final p in catalog) {
        if (p.id == pid) {
          matchedProduct = p;
          break;
        }
      }

      if (matchedProduct == null) continue;

      ProductVariantModel? matchedVariant;
      if (vid != null && vid.isNotEmpty) {
        for (final v in matchedProduct.variants) {
          if (v.id == vid) {
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

    _items.clear();
    _items.addAll(restoredCart);
    notifyListeners();
  }

  void _scheduleSync() {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      try {
        final repo = _userRepository ?? FirestoreUserRepository();
        final cartList = _items
            .map(
              (item) => {
                'productId': item.product.id,
                'quantity': item.quantity,
                if (item.selectedVariant != null)
                  'variantId': item.selectedVariant!.id,
              },
            )
            .toList();
        unawaited(repo.syncCart(uid, cartList));
      } catch (_) {
        // Tolerant of uninitialized unit test environments
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
