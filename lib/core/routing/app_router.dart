import 'package:go_router/go_router.dart';
import 'package:goodwin/core/constants/app_constants.dart';
import 'package:goodwin/features/admin/customers/presentation/screens/customers_screen.dart';
import 'package:goodwin/features/admin/dashboard/presentation/screens/admin_dashboard_screen.dart';
import 'package:goodwin/features/admin/inventory/presentation/screens/inventory_screen.dart';
import 'package:goodwin/features/admin/orders/presentation/screens/admin_orders_screen.dart';
import 'package:goodwin/features/admin/pickup/presentation/screens/pickup_scanner_screen.dart';
import 'package:goodwin/features/admin/products/presentation/screens/admin_products_screen.dart';
import 'package:goodwin/features/auth/presentation/screens/login_screen.dart';
import 'package:goodwin/features/auth/presentation/screens/splash_screen.dart';
import 'package:goodwin/features/customer/cart/presentation/screens/cart_screen.dart';
import 'package:goodwin/features/customer/catalog/presentation/screens/catalog_screen.dart';
import 'package:goodwin/features/customer/checkout/presentation/screens/checkout_screen.dart';
import 'package:goodwin/features/customer/home/presentation/screens/customer_home_screen.dart';
import 'package:goodwin/features/customer/orders/presentation/screens/orders_screen.dart';
import 'package:goodwin/features/customer/product/presentation/screens/product_detail_screen.dart';
import 'package:goodwin/features/customer/profile/presentation/screens/profile_screen.dart';
import 'package:goodwin/models/product_model.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.login,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const CustomerHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.catalog,
        builder: (context, state) => const CatalogScreen(),
      ),
      GoRoute(
        path: AppRoutes.product,
        builder: (context, state) {
          final product = state.extra is ProductModel ? state.extra as ProductModel : null;
          return ProductDetailScreen(product: product);
        },
      ),
      GoRoute(
        path: AppRoutes.cart,
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: AppRoutes.orders,
        builder: (context, state) => const OrdersScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminOrders,
        builder: (context, state) => const AdminOrdersScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminPickup,
        builder: (context, state) => const PickupScannerScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminProducts,
        builder: (context, state) => const AdminProductsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminInventory,
        builder: (context, state) => const InventoryScreen(),
      ),
      GoRoute(
        path: '/admin/customers',
        builder: (context, state) => const CustomersScreen(),
      ),
    ],
  );
}
