import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:goodwin/app.dart';
import 'package:goodwin/core/services/firestore_product_repository.dart';

// Exports for modular access & backward compatibility
export 'package:goodwin/app.dart';
export 'package:goodwin/core/constants/app_colors.dart';
export 'package:goodwin/core/constants/app_constants.dart';
export 'package:goodwin/core/utils/quantity_dialog.dart';
export 'package:goodwin/core/utils/stock_formatter.dart';
export 'package:goodwin/features/admin/dialogs/add_edit_product_dialog.dart';
export 'package:goodwin/features/admin/dialogs/edit_order_dialog.dart';
export 'package:goodwin/features/admin/screens/admin_all_orders_screen.dart';
export 'package:goodwin/features/admin/screens/admin_product_manager_screen.dart';
export 'package:goodwin/features/auth/screens/login_screen.dart';
export 'package:goodwin/features/auth/screens/splash_screen.dart';
export 'package:goodwin/features/customer/payment/prepaid_razorpay_screen.dart';
export 'package:goodwin/features/customer/screens/checkout_screen.dart';
export 'package:goodwin/features/customer/screens/customer_orders_screen.dart';
export 'package:goodwin/features/customer/screens/home_screen.dart';
export 'package:goodwin/features/customer/screens/product_detail_screen.dart';
export 'package:goodwin/features/customer/screens/profile_screen.dart';
export 'package:goodwin/models/cart_item.dart';
export 'package:goodwin/models/demo_product.dart';
export 'package:goodwin/models/filter_criteria.dart';
export 'package:goodwin/models/order_model.dart';
export 'package:goodwin/models/product_model.dart';
export 'package:goodwin/models/user_model.dart';
export 'package:goodwin/shared/widgets/customer_tier_badge.dart';
export 'package:goodwin/shared/widgets/empty_state_view.dart';
export 'package:goodwin/shared/widgets/full_screen_image_viewer.dart';
export 'package:goodwin/shared/widgets/modern_product_card.dart';
export 'package:goodwin/shared/widgets/photo_option_button.dart';
export 'package:goodwin/shared/widgets/product_image_widget.dart';
export 'package:goodwin/shared/widgets/profile_avatar_widget.dart';
export 'package:goodwin/shared/widgets/wholesale_invoice_sheet.dart';
export 'package:goodwin/core/services/pdf_invoice_service.dart';
export 'package:goodwin/core/state/cart_controller.dart';
export 'package:goodwin/core/state/favorites_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    // Enable offline persistence caching for smooth offline browsing
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    // Pre-seed Firestore with default wholesale catalog if database is empty
    unawaited(FirestoreProductRepository().seedDemoDataIfNeeded());
  } catch (_) {
    // Firebase is available on configured mobile builds. Keeping the demo
    // shell runnable on unsupported development platforms is intentional.
  }
  runApp(const GoodwinDemoApp());
}
