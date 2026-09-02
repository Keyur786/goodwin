enum AppScreen { splash, login, home }

enum ProfileAction {
  profile,
  orders,
  bulkQuotes,
  manageProducts,
  allOrders,
  adminBulkQuotes,
  addresses,
  help,
  signOut,
}

class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';
  static const String login = '/login';
  static const String home = '/';
  static const String catalog = '/catalog';
  static const String product = '/product';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String orders = '/orders';
  static const String profile = '/profile';

  static const String adminDashboard = '/admin/dashboard';
  static const String adminOrders = '/admin/orders';
  static const String adminPickup = '/admin/pickup';
  static const String adminProducts = '/admin/products';
  static const String adminInventory = '/admin/inventory';
}

const List<String> kPresetAvatars = [
  'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
  'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
  'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=400&q=80',
  'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
  'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=400&q=80',
  'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?auto=format&fit=crop&w=400&q=80',
  'https://images.unsplash.com/photo-1580489944761-15a19d654956?auto=format&fit=crop&w=400&q=80',
  'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&w=400&q=80',
];
