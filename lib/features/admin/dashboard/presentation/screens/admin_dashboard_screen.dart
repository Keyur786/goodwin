import 'package:flutter/material.dart';
import 'package:goodwin/core/services/admin_analytics_service.dart';
import 'package:goodwin/core/services/firestore_order_repository.dart';
import 'package:goodwin/core/services/firestore_product_repository.dart';
import 'package:goodwin/core/services/firestore_user_repository.dart';
import 'package:goodwin/features/admin/screens/admin_all_orders_screen.dart';
import 'package:goodwin/features/admin/screens/admin_bulk_quotes_screen.dart';
import 'package:goodwin/features/admin/screens/admin_product_manager_screen.dart';
import 'package:goodwin/models/order_model.dart';
import 'package:goodwin/models/product_model.dart';
import 'package:goodwin/models/user_model.dart';
import 'package:goodwin/shared/widgets/customer_tier_badge.dart';
import 'package:goodwin/shared/widgets/product_image_widget.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _orderRepo = FirestoreOrderRepository();
  final _userRepo = FirestoreUserRepository();
  final _productRepo = FirestoreProductRepository();

  AnalyticsTimeFilter _selectedFilter = AnalyticsTimeFilter.month;

  final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Business & Sales Analytics',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            Text(
              'Goodwin Wholesale Operations Hub',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        surfaceTintColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
          ),
          const SizedBox(width: 4),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: _orderRepo.streamAllOrders(),
        builder: (context, ordersSnap) {
          return StreamBuilder<List<AppUser>>(
            stream: _userRepo.streamAllCustomers(),
            builder: (context, usersSnap) {
              return StreamBuilder<List<ProductModel>>(
                stream: _productRepo.streamProducts(),
                builder: (context, productsSnap) {
                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _productRepo.streamAllBulkInquiries(),
                    builder: (context, inqSnap) {
                      final isLoading = ordersSnap.connectionState == ConnectionState.waiting &&
                          !ordersSnap.hasData;

                      if (isLoading) {
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        );
                      }

                      final orders = ordersSnap.data ?? [];
                      final users = usersSnap.data ?? [];
                      final products = productsSnap.data ?? [];
                      final inquiries = inqSnap.data ?? [];

                      final data = AdminAnalyticsService.compute(
                        orders: orders,
                        registeredUsers: users,
                        catalogProducts: products,
                        inquiries: inquiries,
                        filter: _selectedFilter,
                      );

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                        children: [
                          _buildTimeFilterBar(),
                          const SizedBox(height: 16),
                          _buildExecutiveKpiCards(data),
                          const SizedBox(height: 24),
                          _buildCustomerSalesSection(data),
                          const SizedBox(height: 24),
                          _buildSalesAndChannelSection(data),
                          const SizedBox(height: 24),
                          _buildTopProductsSection(data),
                          const SizedBox(height: 24),
                          _buildOperationalAlertsSection(data),
                          const SizedBox(height: 24),
                          _buildQuickActionsSection(context),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Time Filter Bar
  // ---------------------------------------------------------------------------
  Widget _buildTimeFilterBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: AnalyticsTimeFilter.values.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withAlpha(12),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  filter.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Executive KPI Cards
  // ---------------------------------------------------------------------------
  Widget _buildExecutiveKpiCards(DashboardAnalyticsData data) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Gross Revenue',
                value: _currencyFormat.format(data.totalRevenue),
                subtitle: 'Avg: ${_currencyFormat.format(data.averageOrderValue)} / order',
                icon: LucideIcons.indianRupee,
                iconColor: const Color(0xFF16A34A),
                bgColor: const Color(0xFFF0FDF4),
                borderColor: const Color(0xFFBBF7D0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: 'Total Orders',
                value: data.totalOrders.toString(),
                subtitle: '${data.completedOrders} Delivered • ${data.pendingOrders} Active',
                icon: LucideIcons.shoppingBag,
                iconColor: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
                borderColor: const Color(0xFFBFDBFE),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Active Resellers',
                value: data.activeCustomersCount.toString(),
                subtitle: '${data.repeatCustomersCount} Repeat Accounts',
                icon: LucideIcons.users,
                iconColor: const Color(0xFF9333EA),
                bgColor: const Color(0xFFFAF5FF),
                borderColor: const Color(0xFFE9D5FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: 'Units Dispatched',
                value: NumberFormat.compact().format(data.totalUnitsSold),
                subtitle: '${data.lowStockProducts.length} low stock alerts',
                icon: LucideIcons.boxes,
                iconColor: const Color(0xFFEA580C),
                bgColor: const Color(0xFFFFF7ED),
                borderColor: const Color(0xFFFED7AA),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Customer & Reseller Sales Intelligence Section
  // ---------------------------------------------------------------------------
  Widget _buildCustomerSalesSection(DashboardAnalyticsData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(LucideIcons.award, size: 18, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text(
              'B2B Customer & Reseller Sales',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Ranked by gross purchase value and business tier in this period.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),

        // Tier Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildTierSummaryPill(
                tier: CustomerTier.diamond,
                count: data.diamondTierCount,
                spend: data.diamondTierSpend,
                color: const Color(0xFF0284C7),
                bgColor: const Color(0xFFE0F2FE),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTierSummaryPill(
                tier: CustomerTier.gold,
                count: data.goldTierCount,
                spend: data.goldTierSpend,
                color: const Color(0xFFD97706),
                bgColor: const Color(0xFFFEF3C7),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTierSummaryPill(
                tier: CustomerTier.silver,
                count: data.silverTierCount,
                spend: data.silverTierSpend,
                color: const Color(0xFF64748B),
                bgColor: const Color(0xFFF1F5F9),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Customer Leaderboard Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: data.customerMetrics.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                  child: Center(
                    child: Text(
                      'No reseller transactions in this time window.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.customerMetrics.length.clamp(0, 6),
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final cust = data.customerMetrics[index];
                    final rank = index + 1;
                    return InkWell(
                      onTap: () => _showCustomerDetailSheet(context, cust),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            // Rank pill
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: rank == 1
                                    ? const Color(0xFFFEF3C7)
                                    : (rank == 2
                                        ? const Color(0xFFF1F5F9)
                                        : (rank == 3
                                            ? const Color(0xFFFFEDD5)
                                            : Colors.transparent)),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: rank <= 3 ? const Color(0xFFCBD5E1) : Colors.transparent,
                                ),
                              ),
                              child: Text(
                                '#$rank',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: rank == 1
                                      ? const Color(0xFFB45309)
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Customer & Shop name
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          cust.shopName.isNotEmpty ? cust.shopName : cust.name,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      CustomerTierBadge(tier: cust.tier, isCompact: true),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${cust.name} • ${cust.orderCount} ${cust.orderCount == 1 ? 'order' : 'orders'}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Spend & AOV
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _currencyFormat.format(cust.totalSpend),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'AOV: ${_currencyFormat.format(cust.averageOrderValue)}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 6),
                            const Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFFCBD5E1)),
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

  Widget _buildTierSummaryPill({
    required CustomerTier tier,
    required int count,
    required double spend,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(tier.emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                tier.displayName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _currencyFormat.format(spend),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Sales Channel & Payment Health
  // ---------------------------------------------------------------------------
  Widget _buildSalesAndChannelSection(DashboardAnalyticsData data) {
    final totalFulfillment = data.pickupOrdersCount + data.deliveryOrdersCount;
    final pickupRatio = totalFulfillment > 0 ? data.pickupOrdersCount / totalFulfillment : 0.5;

    final totalPayRev = data.razorpayRevenue + data.cashRevenue;
    final razorpayRatio = totalPayRev > 0 ? data.razorpayRevenue / totalPayRev : 0.5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.barChart2, size: 18, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text(
                'Channel & Settlement Health',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Fulfillment: Warehouse vs Delivery
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🏪 Katargam Warehouse Pickup (${data.pickupOrdersCount})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              Text(
                '🚚 Online Delivery (${data.deliveryOrdersCount})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: (pickupRatio * 100).round().clamp(1, 99),
                    child: Container(color: const Color(0xFF2563EB)),
                  ),
                  Expanded(
                    flex: ((1 - pickupRatio) * 100).round().clamp(1, 99),
                    child: Container(color: const Color(0xFF10B981)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _currencyFormat.format(data.pickupRevenue),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
              ),
              Text(
                _currencyFormat.format(data.deliveryRevenue),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Payment settlement: Razorpay vs Cash
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '⚡ Razorpay Prepaid',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              const Text(
                '💵 Cash on Counter / COD',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: (razorpayRatio * 100).round().clamp(1, 99),
                    child: Container(color: const Color(0xFF8B5CF6)),
                  ),
                  Expanded(
                    flex: ((1 - razorpayRatio) * 100).round().clamp(1, 99),
                    child: Container(color: const Color(0xFFF59E0B)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _currencyFormat.format(data.razorpayRevenue),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF8B5CF6)),
              ),
              Text(
                _currencyFormat.format(data.cashRevenue),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Top Performing Products
  // ---------------------------------------------------------------------------
  Widget _buildTopProductsSection(DashboardAnalyticsData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(LucideIcons.packageCheck, size: 18, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text(
              'Top Revenue Generating Products',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Fast-moving wholesale inventory driven by customer demand.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: data.topProducts.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      'No product transactions in this period.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.topProducts.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final item = data.topProducts[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: ProductImageWidget(
                                imageSrc: item.imageUrl ?? '',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.unitsSold} units / cartons sold',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _currencyFormat.format(item.revenue),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 6. Operational Alerts & Stock Warnings
  // ---------------------------------------------------------------------------
  Widget _buildOperationalAlertsSection(DashboardAnalyticsData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(LucideIcons.alertTriangle, size: 18, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Text(
              'Operational Warnings & Inventory',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Low stock alert card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.packageMinus, color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${data.lowStockProducts.length} Items Low on Stock (< 20 units)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const AdminProductManagerScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Restock', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ],
              ),
              if (data.lowStockProducts.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: data.lowStockProducts.take(4).map((p) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        '${p.name}: ${p.availableQty} left',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Pending bulk inquiries card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.messageSquare, color: Color(0xFF2563EB), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.pendingInquiriesCount} Bulk Quote Inquiries Awaiting Reply',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Prompt quotes increase conversion by 45%',
                      style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6)),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminBulkQuotesScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(60, 32),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Open Chat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 7. Quick Action Hub
  // ---------------------------------------------------------------------------
  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Operations',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                icon: LucideIcons.clipboardList,
                label: 'All Orders',
                color: const Color(0xFF2563EB),
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const AdminAllOrdersScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionTile(
                icon: LucideIcons.packagePlus,
                label: 'Products',
                color: const Color(0xFF10B981),
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const AdminProductManagerScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionTile(
                icon: LucideIcons.messageSquare,
                label: 'Bulk Quotes',
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const AdminBulkQuotesScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Customer Detail Modal
  // ---------------------------------------------------------------------------
  void _showCustomerDetailSheet(BuildContext context, CustomerSalesMetric cust) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.user, color: Color(0xFF2563EB), size: 22),
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
                                  cust.shopName.isNotEmpty ? cust.shopName : cust.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              CustomerTierBadge(tier: cust.tier),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Owner: ${cust.name} • ${cust.phone.isNotEmpty ? cust.phone : 'No phone'}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Metrics Row
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailMetric(
                        label: 'Total Spend',
                        value: _currencyFormat.format(cust.totalSpend),
                      ),
                    ),
                    Expanded(
                      child: _buildDetailMetric(
                        label: 'Orders Placed',
                        value: '${cust.orderCount}',
                      ),
                    ),
                    Expanded(
                      child: _buildDetailMetric(
                        label: 'Avg Order Value',
                        value: _currencyFormat.format(cust.averageOrderValue),
                      ),
                    ),
                  ],
                ),
                if (cust.lastOrderDate != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(LucideIcons.clock, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(
                        'Last ordered: ${DateFormat('dd MMM yyyy, hh:mm a').format(cust.lastOrderDate!)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(LucideIcons.check, size: 16),
                    label: const Text('Close'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailMetric({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
        ),
      ],
    );
  }
}
