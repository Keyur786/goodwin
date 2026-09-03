import 'package:goodwin/models/order_model.dart';
import 'package:goodwin/models/product_model.dart';
import 'package:goodwin/models/user_model.dart';

enum AnalyticsTimeFilter {
  today('Today'),
  week('7 Days'),
  month('30 Days'),
  allTime('All Time');

  const AnalyticsTimeFilter(this.label);
  final String label;
}

class CustomerSalesMetric {
  const CustomerSalesMetric({
    required this.customerId,
    required this.name,
    required this.shopName,
    required this.phone,
    required this.tier,
    required this.totalSpend,
    required this.orderCount,
    required this.averageOrderValue,
    this.lastOrderDate,
  });

  final String customerId;
  final String name;
  final String shopName;
  final String phone;
  final CustomerTier tier;
  final double totalSpend;
  final int orderCount;
  final double averageOrderValue;
  final DateTime? lastOrderDate;
}

class ProductSalesMetric {
  const ProductSalesMetric({
    required this.productId,
    required this.productName,
    this.imageUrl,
    required this.unitsSold,
    required this.revenue,
  });

  final String productId;
  final String productName;
  final String? imageUrl;
  final int unitsSold;
  final double revenue;
}

class DashboardAnalyticsData {
  const DashboardAnalyticsData({
    required this.timeFilter,
    required this.totalRevenue,
    required this.totalOrders,
    required this.completedOrders,
    required this.pendingOrders,
    required this.averageOrderValue,
    required this.totalUnitsSold,
    required this.pickupOrdersCount,
    required this.pickupRevenue,
    required this.deliveryOrdersCount,
    required this.deliveryRevenue,
    required this.razorpayRevenue,
    required this.cashRevenue,
    required this.activeCustomersCount,
    required this.repeatCustomersCount,
    required this.customerMetrics,
    required this.diamondTierSpend,
    required this.diamondTierCount,
    required this.goldTierSpend,
    required this.goldTierCount,
    required this.silverTierSpend,
    required this.silverTierCount,
    required this.topProducts,
    required this.lowStockProducts,
    required this.pendingInquiriesCount,
  });

  final AnalyticsTimeFilter timeFilter;
  final double totalRevenue;
  final int totalOrders;
  final int completedOrders;
  final int pendingOrders;
  final double averageOrderValue;
  final int totalUnitsSold;

  // Channel metrics
  final int pickupOrdersCount;
  final double pickupRevenue;
  final int deliveryOrdersCount;
  final double deliveryRevenue;

  // Payment metrics
  final double razorpayRevenue;
  final double cashRevenue;

  // Customer metrics
  final int activeCustomersCount;
  final int repeatCustomersCount;
  final List<CustomerSalesMetric> customerMetrics;

  // Tier metrics
  final double diamondTierSpend;
  final int diamondTierCount;
  final double goldTierSpend;
  final int goldTierCount;
  final double silverTierSpend;
  final int silverTierCount;

  // Product metrics
  final List<ProductSalesMetric> topProducts;
  final List<ProductModel> lowStockProducts;

  // Inquiries
  final int pendingInquiriesCount;
}

class AdminAnalyticsService {
  static DashboardAnalyticsData compute({
    required List<OrderModel> orders,
    required List<AppUser> registeredUsers,
    required List<ProductModel> catalogProducts,
    required List<Map<String, dynamic>> inquiries,
    AnalyticsTimeFilter filter = AnalyticsTimeFilter.month,
  }) {
    final now = DateTime.now();

    // 1. Filter orders based on the chosen time window
    final filteredOrders = orders.where((o) {
      if (filter == AnalyticsTimeFilter.allTime) return true;
      final diff = now.difference(o.createdAt);
      if (filter == AnalyticsTimeFilter.today) {
        return o.createdAt.year == now.year &&
            o.createdAt.month == now.month &&
            o.createdAt.day == now.day;
      } else if (filter == AnalyticsTimeFilter.week) {
        return diff.inDays <= 7;
      } else if (filter == AnalyticsTimeFilter.month) {
        return diff.inDays <= 30;
      }
      return true;
    }).toList();

    // 2. High-level aggregates
    double totalRevenue = 0;
    int completedOrders = 0;
    int pendingOrders = 0;
    int totalUnitsSold = 0;
    int pickupCount = 0;
    double pickupRev = 0;
    int deliveryCount = 0;
    double deliveryRev = 0;
    double razorpayRev = 0;
    double cashRev = 0;

    // Per-customer aggregation map
    final Map<String, _CustomerAggregator> customerMap = {};
    // Per-product aggregation map
    final Map<String, _ProductAggregator> productMap = {};

    for (final order in filteredOrders) {
      final isCancelled = order.orderStatus == OrderStatus.cancelled;
      if (isCancelled) continue;

      totalRevenue += order.totalAmount;

      final isCompleted = order.orderStatus == OrderStatus.completed ||
          order.orderStatus == OrderStatus.pickedUp;
      if (isCompleted) {
        completedOrders++;
      } else {
        pendingOrders++;
      }

      // Fulfillment
      if (order.isOnlineOrder) {
        deliveryCount++;
        deliveryRev += order.totalAmount;
      } else {
        pickupCount++;
        pickupRev += order.totalAmount;
      }

      // Payment
      final pm = order.paymentMethod.toLowerCase();
      if (pm.contains('razorpay') || pm.contains('online') || pm.contains('prepaid')) {
        razorpayRev += order.totalAmount;
      } else {
        cashRev += order.totalAmount;
      }

      // Customer aggregation
      final custId = order.customerId.isNotEmpty ? order.customerId : 'guest';
      final existingCust = customerMap.putIfAbsent(
        custId,
        () => _CustomerAggregator(
          id: custId,
          name: order.customerName.isNotEmpty ? order.customerName : 'Walk-in Buyer',
          phone: order.customerPhone ?? '',
        ),
      );
      existingCust.totalSpend += order.totalAmount;
      existingCust.orderCount++;
      if (existingCust.lastOrderDate == null ||
          order.createdAt.isAfter(existingCust.lastOrderDate!)) {
        existingCust.lastOrderDate = order.createdAt;
      }

      // Item & Product aggregation
      for (final item in order.items) {
        totalUnitsSold += item.quantity;
        final pAgg = productMap.putIfAbsent(
          item.productId,
          () => _ProductAggregator(
            id: item.productId,
            name: item.productName,
            imageUrl: item.imageUrl,
          ),
        );
        pAgg.units += item.quantity;
        pAgg.revenue += item.totalPrice;
        if (pAgg.imageUrl == null && item.imageUrl != null) {
          pAgg.imageUrl = item.imageUrl;
        }
      }
    }

    // Connect with registeredUsers metadata
    final userLookup = {for (final u in registeredUsers) u.id: u};
    final phoneLookup = {for (final u in registeredUsers) u.phone: u};

    final List<CustomerSalesMetric> customerMetrics = [];
    int repeatCustomersCount = 0;

    for (final agg in customerMap.values) {
      final user = userLookup[agg.id] ?? phoneLookup[agg.phone];
      final shopName = user?.shopName ?? '';
      final name = user != null && user.name.isNotEmpty ? user.name : agg.name;
      final phone = user?.phone ?? agg.phone;
      final tier = CustomerTier.fromSpend(user?.totalPurchases ?? agg.totalSpend);
      final aov = agg.orderCount > 0 ? agg.totalSpend / agg.orderCount : 0.0;

      if (agg.orderCount > 1) {
        repeatCustomersCount++;
      }

      customerMetrics.add(CustomerSalesMetric(
        customerId: agg.id,
        name: name,
        shopName: shopName,
        phone: phone,
        tier: tier,
        totalSpend: agg.totalSpend,
        orderCount: agg.orderCount,
        averageOrderValue: aov,
        lastOrderDate: agg.lastOrderDate,
      ));
    }

    // Sort customer metrics by total spend descending
    customerMetrics.sort((a, b) => b.totalSpend.compareTo(a.totalSpend));

    // Calculate customer tier spend & count distributions across all registered users
    double diamondSpend = 0;
    int diamondCount = 0;
    double goldSpend = 0;
    int goldCount = 0;
    double silverSpend = 0;
    int silverCount = 0;

    for (final u in registeredUsers) {
      final t = u.tier;
      if (t == CustomerTier.diamond) {
        diamondCount++;
        diamondSpend += u.totalPurchases;
      } else if (t == CustomerTier.gold) {
        goldCount++;
        goldSpend += u.totalPurchases;
      } else {
        silverCount++;
        silverSpend += u.totalPurchases;
      }
    }

    // Top Products ranking by revenue
    final topProducts = productMap.values.map((p) {
      return ProductSalesMetric(
        productId: p.id,
        productName: p.name,
        imageUrl: p.imageUrl,
        unitsSold: p.units,
        revenue: p.revenue,
      );
    }).toList();
    topProducts.sort((a, b) => b.revenue.compareTo(a.revenue));

    // Low stock items (< 20 cartons / pieces or below lowStockThreshold)
    final lowStockProducts = catalogProducts.where((p) => p.isLowStock || p.availableQty <= 20).toList();
    lowStockProducts.sort((a, b) => a.availableQty.compareTo(b.availableQty));

    // Pending bulk quote inquiries
    final pendingInquiries = inquiries.where((inq) {
      final s = inq['status']?.toString().toLowerCase() ?? '';
      return s == 'pending' || s == 'unread';
    }).length;

    final aov = filteredOrders.isNotEmpty ? totalRevenue / filteredOrders.length : 0.0;

    return DashboardAnalyticsData(
      timeFilter: filter,
      totalRevenue: totalRevenue,
      totalOrders: filteredOrders.length,
      completedOrders: completedOrders,
      pendingOrders: pendingOrders,
      averageOrderValue: aov,
      totalUnitsSold: totalUnitsSold,
      pickupOrdersCount: pickupCount,
      pickupRevenue: pickupRev,
      deliveryOrdersCount: deliveryCount,
      deliveryRevenue: deliveryRev,
      razorpayRevenue: razorpayRev,
      cashRevenue: cashRev,
      activeCustomersCount: customerMap.length,
      repeatCustomersCount: repeatCustomersCount,
      customerMetrics: customerMetrics,
      diamondTierSpend: diamondSpend,
      diamondTierCount: diamondCount,
      goldTierSpend: goldSpend,
      goldTierCount: goldCount,
      silverTierSpend: silverSpend,
      silverTierCount: silverCount,
      topProducts: topProducts.take(8).toList(),
      lowStockProducts: lowStockProducts,
      pendingInquiriesCount: pendingInquiries,
    );
  }
}

class _CustomerAggregator {
  _CustomerAggregator({required this.id, required this.name, required this.phone});
  final String id;
  String name;
  String phone;
  double totalSpend = 0.0;
  int orderCount = 0;
  DateTime? lastOrderDate;
}

class _ProductAggregator {
  _ProductAggregator({required this.id, required this.name, this.imageUrl});
  final String id;
  final String name;
  String? imageUrl;
  int units = 0;
  double revenue = 0.0;
}
