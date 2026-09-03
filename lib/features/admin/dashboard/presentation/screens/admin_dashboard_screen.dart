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
import 'package:goodwin/shared/widgets/wholesale_invoice_sheet.dart';
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
  DateTimeRange? _customRange;

  CustomerTier? _selectedTierFilter;

  final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: now,
      initialDateRange: _customRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customRange = picked;
        _selectedFilter = AnalyticsTimeFilter.custom;
      });
    }
  }

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
              'Interactive Executive Intelligence Hub',
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
            icon: const Icon(LucideIcons.calendarDays, size: 20, color: Color(0xFF2563EB)),
            tooltip: 'Pick Date Range',
            onPressed: _pickCustomDateRange,
          ),
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
                        customRange: _customRange,
                      );

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                        children: [
                          _buildTimeFilterBar(data),
                          const SizedBox(height: 16),
                          _buildExecutiveKpiCards(data, products),
                          const SizedBox(height: 24),
                          _buildCustomerSalesSection(data),
                          const SizedBox(height: 24),
                          _buildSalesAndChannelSection(data),
                          const SizedBox(height: 24),
                          _buildTopProductsSection(data, products),
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
  // 1. Time Filter Bar with Calendar Range
  // ---------------------------------------------------------------------------
  Widget _buildTimeFilterBar(DashboardAnalyticsData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...AnalyticsTimeFilter.values.map((filter) {
                final isSelected = _selectedFilter == filter;
                final isCustom = filter == AnalyticsTimeFilter.custom;
                String label = filter.label;
                if (isCustom && _customRange != null) {
                  final s = _customRange!.start;
                  final e = _customRange!.end;
                  label = '${s.day}/${s.month} - ${e.day}/${e.month}';
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isCustom) ...[
                          Icon(
                            LucideIcons.calendar,
                            size: 13,
                            color: isSelected ? Colors.white : const Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(label),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (!selected) return;
                      if (isCustom) {
                        _pickCustomDateRange();
                      } else {
                        setState(() {
                          _selectedFilter = filter;
                          _customRange = null;
                        });
                      }
                    },
                    selectedColor: const Color(0xFF2563EB),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(LucideIcons.calendarClock, size: 12, color: Color(0xFF64748B)),
            const SizedBox(width: 5),
            Text(
              'Showing: ${data.rangeDescription} • ${data.totalOrders} total orders',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Executive KPI Cards (All Clickable for Drill-down)
  // ---------------------------------------------------------------------------
  Widget _buildExecutiveKpiCards(DashboardAnalyticsData data, List<ProductModel> catalogProducts) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Gross Revenue',
                value: _currencyFormat.format(data.totalRevenue),
                subtitle: 'Avg: ${_currencyFormat.format(data.averageOrderValue)} / ord',
                icon: LucideIcons.indianRupee,
                iconColor: const Color(0xFF16A34A),
                bgColor: const Color(0xFFF0FDF4),
                borderColor: const Color(0xFFBBF7D0),
                onTap: () => _showRevenueBreakdownSheet(context, data),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: 'Total Orders',
                value: data.totalOrders.toString(),
                subtitle: '${data.completedOrders} Delivered • Tap to view',
                icon: LucideIcons.shoppingBag,
                iconColor: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
                borderColor: const Color(0xFFBFDBFE),
                onTap: () => _showOrdersListSheet(
                  context,
                  data.filteredOrders,
                  title: 'Orders Placed (${data.rangeDescription})',
                ),
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
                subtitle: '${data.repeatCustomersCount} Repeat • Tap for list',
                icon: LucideIcons.users,
                iconColor: const Color(0xFF9333EA),
                bgColor: const Color(0xFFFAF5FF),
                borderColor: const Color(0xFFE9D5FF),
                onTap: () => _showResellersSheet(context, data.customerMetrics),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: 'Units Dispatched',
                value: NumberFormat.compact().format(data.totalUnitsSold),
                subtitle: 'Tap for itemized items',
                icon: LucideIcons.boxes,
                iconColor: const Color(0xFFEA580C),
                bgColor: const Color(0xFFFFF7ED),
                borderColor: const Color(0xFFFED7AA),
                onTap: () => _showDispatchesSheet(context, data.topProducts, data.totalUnitsSold),
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
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
                  child: Icon(icon, size: 15, color: iconColor),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
                const Icon(LucideIcons.chevronRight, size: 12, color: Color(0xFFCBD5E1)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Customer & Reseller Sales Intelligence Section
  // ---------------------------------------------------------------------------
  Widget _buildCustomerSalesSection(DashboardAnalyticsData data) {
    // Filter list if a specific tier pill was clicked
    final displayedMetrics = _selectedTierFilter == null
        ? data.customerMetrics
        : data.customerMetrics.where((c) => c.tier == _selectedTierFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.award, size: 18, color: Color(0xFF2563EB)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'B2B Customer & Reseller Sales',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _showResellersSheet(context, data.customerMetrics),
              icon: const Icon(LucideIcons.list, size: 14),
              label: const Text('View All', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                padding: EdgeInsets.zero,
                minimumSize: const Size(60, 30),
              ),
            ),
          ],
        ),
        const Text(
          'Tap any tier pill to filter, or tap any customer to view order history.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),

        // Interactive Tier Summary Pills
        Row(
          children: [
            Expanded(
              child: _buildInteractiveTierPill(
                tier: CustomerTier.diamond,
                count: data.diamondTierCount,
                spend: data.diamondTierSpend,
                color: const Color(0xFF0284C7),
                bgColor: const Color(0xFFE0F2FE),
                isSelected: _selectedTierFilter == CustomerTier.diamond,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildInteractiveTierPill(
                tier: CustomerTier.gold,
                count: data.goldTierCount,
                spend: data.goldTierSpend,
                color: const Color(0xFFD97706),
                bgColor: const Color(0xFFFEF3C7),
                isSelected: _selectedTierFilter == CustomerTier.gold,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildInteractiveTierPill(
                tier: CustomerTier.silver,
                count: data.silverTierCount,
                spend: data.silverTierSpend,
                color: const Color(0xFF64748B),
                bgColor: const Color(0xFFF1F5F9),
                isSelected: _selectedTierFilter == CustomerTier.silver,
              ),
            ),
          ],
        ),
        if (_selectedTierFilter != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Filtering by ${_selectedTierFilter!.displayName} Tier (${displayedMetrics.length})',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _selectedTierFilter = null),
                child: const Text(
                  'Clear Filter',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFEF4444)),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),

        // Customer Leaderboard Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: displayedMetrics.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                  child: Center(
                    child: Text(
                      'No reseller transactions matching this criteria.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayedMetrics.length.clamp(0, 6),
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final cust = displayedMetrics[index];
                    final rank = index + 1;
                    return InkWell(
                      onTap: () => _showCustomerDetailSheet(context, cust, data.filteredOrders),
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

  Widget _buildInteractiveTierPill({
    required CustomerTier tier,
    required int count,
    required double spend,
    required Color color,
    required Color bgColor,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTierFilter = isSelected ? null : tier;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : color.withAlpha(50),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withAlpha(40),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
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
                    color: isSelected ? Colors.white : color,
                  ),
                ),
                const Spacer(),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? Colors.white : color,
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
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Sales Channel & Settlement (Clickable Bars to View Orders)
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
          Row(
            children: [
              const Icon(LucideIcons.barChart2, size: 18, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Channel & Settlement Health',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                'Tap bar to view orders',
                style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Fulfillment: Warehouse vs Delivery
          GestureDetector(
            onTap: () {
              _showOrdersListSheet(
                context,
                data.filteredOrders.where((o) => !o.isOnlineOrder).toList(),
                title: 'Warehouse Pickup Orders (${data.pickupOrdersCount})',
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🏪 Katargam Warehouse Pickup (${data.pickupOrdersCount})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                ),
                Text(
                  _currencyFormat.format(data.pickupRevenue),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                ),
              ],
            ),
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
                    child: GestureDetector(
                      onTap: () {
                        _showOrdersListSheet(
                          context,
                          data.filteredOrders.where((o) => !o.isOnlineOrder).toList(),
                          title: 'Warehouse Pickup Orders (${data.pickupOrdersCount})',
                        );
                      },
                      child: Container(color: const Color(0xFF2563EB)),
                    ),
                  ),
                  Expanded(
                    flex: ((1 - pickupRatio) * 100).round().clamp(1, 99),
                    child: GestureDetector(
                      onTap: () {
                        _showOrdersListSheet(
                          context,
                          data.filteredOrders.where((o) => o.isOnlineOrder).toList(),
                          title: 'Online Delivery Orders (${data.deliveryOrdersCount})',
                        );
                      },
                      child: Container(color: const Color(0xFF10B981)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              _showOrdersListSheet(
                context,
                data.filteredOrders.where((o) => o.isOnlineOrder).toList(),
                title: 'Online Delivery Orders (${data.deliveryOrdersCount})',
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '🚚 Online Delivery',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                ),
                Text(
                  _currencyFormat.format(data.deliveryRevenue),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Payment settlement: Razorpay vs Cash
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  _showOrdersListSheet(
                    context,
                    data.filteredOrders.where((o) {
                      final pm = o.paymentMethod.toLowerCase();
                      return pm.contains('razorpay') || pm.contains('online') || pm.contains('prepaid');
                    }).toList(),
                    title: 'Razorpay Prepaid Orders',
                  );
                },
                child: Text(
                  '⚡ Razorpay: ${_currencyFormat.format(data.razorpayRevenue)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6)),
                ),
              ),
              GestureDetector(
                onTap: () {
                  _showOrdersListSheet(
                    context,
                    data.filteredOrders.where((o) {
                      final pm = o.paymentMethod.toLowerCase();
                      return !pm.contains('razorpay') && !pm.contains('online') && !pm.contains('prepaid');
                    }).toList(),
                    title: 'Cash Collection Orders',
                  );
                },
                child: Text(
                  '💵 Cash: ${_currencyFormat.format(data.cashRevenue)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B)),
                ),
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
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Top Performing Products (Clickable Product Performance Sheet)
  // ---------------------------------------------------------------------------
  Widget _buildTopProductsSection(DashboardAnalyticsData data, List<ProductModel> catalogProducts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.packageCheck, size: 18, color: Color(0xFF2563EB)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Top Revenue Generating Products',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            TextButton(
              onPressed: () => _showDispatchesSheet(context, data.topProducts, data.totalUnitsSold),
              child: const Text('View All', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ),
        const Text(
          'Tap any product to inspect warehouse stock and contributing orders.',
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
                  itemCount: data.topProducts.length.clamp(0, 6),
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final item = data.topProducts[index];
                    return InkWell(
                      onTap: () => _showProductPerformanceSheet(context, item, catalogProducts, data.filteredOrders),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
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
                                    '${item.unitsSold} units • in ${item.orderCount} orders',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _currencyFormat.format(item.revenue),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Inspect', style: TextStyle(fontSize: 10.5, color: Color(0xFF2563EB), fontWeight: FontWeight.w700)),
                                    Icon(LucideIcons.chevronRight, size: 12, color: Color(0xFF2563EB)),
                                  ],
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
  // 7. Quick Operations Hub
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

  // ===========================================================================
  // INTERACTIVE DRILL-DOWN MODALS
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // A. Orders Drill-Down Sheet (Tapped from "Total Orders" or Channels)
  // ---------------------------------------------------------------------------
  void _showOrdersListSheet(BuildContext context, List<OrderModel> orders, {required String title}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return _DrillDownOrdersSheet(
          orders: orders,
          title: title,
          currencyFormat: _currencyFormat,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // B. Reseller Directory Sheet (Tapped from "Active Resellers")
  // ---------------------------------------------------------------------------
  void _showResellersSheet(BuildContext context, List<CustomerSalesMetric> metrics) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return _DrillDownResellersSheet(
          metrics: metrics,
          currencyFormat: _currencyFormat,
          onCustomerSelected: (cust) {
            Navigator.pop(ctx);
            _showCustomerDetailSheet(context, cust, const []);
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // C. Dispatches Sheet (Tapped from "Units Dispatched")
  // ---------------------------------------------------------------------------
  void _showDispatchesSheet(BuildContext context, List<ProductSalesMetric> products, int totalUnits) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.boxes, size: 20, color: Color(0xFFEA580C)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Dispatched Items Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                            Text('$totalUnits total units sold in this period', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(LucideIcons.x, size: 20)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: products.isEmpty
                      ? const Center(child: Text('No dispatched items in this window', style: TextStyle(color: Color(0xFF94A3B8))))
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: products.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final p = products[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: ProductImageWidget(imageSrc: p.imageUrl ?? '', fit: BoxFit.cover),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.productName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                                        const SizedBox(height: 2),
                                        Text('${p.unitsSold} units dispatched • ${p.orderCount} orders', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                  Text(_currencyFormat.format(p.revenue), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF16A34A))),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // D. Revenue Breakdown Sheet (Tapped from "Gross Revenue")
  // ---------------------------------------------------------------------------
  void _showRevenueBreakdownSheet(BuildContext context, DashboardAnalyticsData data) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(LucideIcons.wallet, color: Color(0xFF16A34A), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Gross Revenue Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                          Text(data.rangeDescription, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                _buildSummaryRow('Gross Merchandise Value (GMV)', _currencyFormat.format(data.totalRevenue), isBold: true),
                const SizedBox(height: 10),
                _buildSummaryRow('Average Order Value (AOV)', _currencyFormat.format(data.averageOrderValue)),
                const SizedBox(height: 10),
                _buildSummaryRow('Prepaid Online (Razorpay)', _currencyFormat.format(data.razorpayRevenue)),
                const SizedBox(height: 10),
                _buildSummaryRow('Cash Collection', _currencyFormat.format(data.cashRevenue)),
                const SizedBox(height: 10),
                _buildSummaryRow('Warehouse Pickup Revenue', _currencyFormat.format(data.pickupRevenue)),
                const SizedBox(height: 10),
                _buildSummaryRow('Online Delivery Revenue', _currencyFormat.format(data.deliveryRevenue)),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, color: const Color(0xFF475569), fontWeight: isBold ? FontWeight.w800 : FontWeight.w500)),
        Text(value, style: TextStyle(fontSize: 13.5, color: const Color(0xFF0F172A), fontWeight: isBold ? FontWeight.w900 : FontWeight.w700)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // E. Product Performance Drill-Down Sheet
  // ---------------------------------------------------------------------------
  void _showProductPerformanceSheet(
    BuildContext context,
    ProductSalesMetric metric,
    List<ProductModel> catalog,
    List<OrderModel> periodOrders,
  ) {
    final product = catalog.where((p) => p.id == metric.productId).firstOrNull;
    final contributingOrders = periodOrders.where((o) => o.items.any((it) => it.productId == metric.productId)).toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: ProductImageWidget(imageSrc: metric.imageUrl ?? '', fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(metric.productName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(
                            product != null ? 'Current Warehouse Stock: ${product.availableQty} units' : 'Product ID: ${metric.productId}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: (product != null && product.isLowStock) ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(child: _buildDetailMetric(label: 'Units Sold', value: '${metric.unitsSold}')),
                    Expanded(child: _buildDetailMetric(label: 'Total Revenue', value: _currencyFormat.format(metric.revenue))),
                    Expanded(child: _buildDetailMetric(label: 'Orders Count', value: '${contributingOrders.length}')),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Orders Containing this Product', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),

                if (contributingOrders.isEmpty)
                  const Text('No orders found', style: TextStyle(color: Color(0xFF94A3B8)))
                else
                  ...contributingOrders.map((ord) {
                    final item = ord.items.firstWhere((it) => it.productId == metric.productId);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Order #${ord.orderNumber}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                              Text('${ord.customerName} • ${DateFormat('dd MMM').format(ord.createdAt)}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                          Text('${item.quantity} units (${_currencyFormat.format(item.totalPrice)})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                        ],
                      ),
                    );
                  }),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // F. Customer Detail Modal
  // ---------------------------------------------------------------------------
  void _showCustomerDetailSheet(
    BuildContext context,
    CustomerSalesMetric cust,
    List<OrderModel> periodOrders,
  ) {
    final customerOrders = periodOrders.where((o) => o.customerId == cust.customerId).toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),

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
                  const SizedBox(height: 12),
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
                if (customerOrders.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('Orders in this Period (${customerOrders.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  ...customerOrders.take(3).map((o) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Order #${o.orderNumber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          Text(_currencyFormat.format(o.totalAmount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
                        ],
                      ),
                    );
                  }),
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

// =============================================================================
// DRILL-DOWN SUB-WIDGET: ORDERS LIST SHEET
// =============================================================================
class _DrillDownOrdersSheet extends StatefulWidget {
  const _DrillDownOrdersSheet({
    required this.orders,
    required this.title,
    required this.currencyFormat,
  });

  final List<OrderModel> orders;
  final String title;
  final NumberFormat currencyFormat;

  @override
  State<_DrillDownOrdersSheet> createState() => _DrillDownOrdersSheetState();
}

class _DrillDownOrdersSheetState extends State<_DrillDownOrdersSheet> {
  String _search = '';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.orders.where((o) {
      final q = _search.toLowerCase();
      final matchesSearch = q.isEmpty ||
          o.orderNumber.toLowerCase().contains(q) ||
          o.customerName.toLowerCase().contains(q) ||
          (o.customerPhone != null && o.customerPhone!.contains(q));

      if (!matchesSearch) return false;

      if (_statusFilter == 'All') return true;
      if (_statusFilter == 'Delivered') {
        return o.orderStatus == OrderStatus.completed || o.orderStatus == OrderStatus.pickedUp;
      }
      if (_statusFilter == 'Pending') {
        return o.orderStatus == OrderStatus.pending;
      }
      if (_statusFilter == 'In Delivery') {
        return o.orderStatus == OrderStatus.inDelivery;
      }
      return true;
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(LucideIcons.shoppingBag, size: 20, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x, size: 20)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                onChanged: (val) => setState(() => _search = val),
                decoration: InputDecoration(
                  hintText: 'Search by order #, customer, or phone...',
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: ['All', 'Delivered', 'Pending', 'In Delivery'].map((st) {
                  final isSel = _statusFilter == st;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(st),
                      selected: isSel,
                      onSelected: (_) => setState(() => _statusFilter = st),
                      selectedColor: const Color(0xFF2563EB),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSel ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No orders found matching criteria', style: TextStyle(color: Color(0xFF94A3B8))))
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final ord = filtered[i];
                        return _buildOrderItem(context, ord);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrderItem(BuildContext context, OrderModel ord) {
    final isDelivered = ord.orderStatus == OrderStatus.completed || ord.orderStatus == OrderStatus.pickedUp;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #${ord.orderNumber}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDelivered ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isDelivered ? 'Delivered' : ord.orderStatus.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isDelivered ? const Color(0xFF16A34A) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${ord.customerName} • ${DateFormat('dd MMM yyyy, hh:mm a').format(ord.createdAt)}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${ord.items.length} ${ord.items.length == 1 ? 'item' : 'items'}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ord.isOnlineOrder ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  ord.isOnlineOrder ? '🚚 Delivery' : '🏪 Katargam Pickup',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: ord.isOnlineOrder ? const Color(0xFF2563EB) : const Color(0xFF475569),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                widget.currencyFormat.format(ord.totalAmount),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => WholesaleInvoiceSheet(order: ord, isAdmin: true),
                );
              },
              icon: const Icon(LucideIcons.fileText, size: 14),
              label: const Text('View Wholesale Invoice / PO', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFFBFDBFE)),
                padding: const EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// DRILL-DOWN SUB-WIDGET: RESELLERS DIRECTORY SHEET
// =============================================================================
class _DrillDownResellersSheet extends StatefulWidget {
  const _DrillDownResellersSheet({
    required this.metrics,
    required this.currencyFormat,
    required this.onCustomerSelected,
  });

  final List<CustomerSalesMetric> metrics;
  final NumberFormat currencyFormat;
  final ValueChanged<CustomerSalesMetric> onCustomerSelected;

  @override
  State<_DrillDownResellersSheet> createState() => _DrillDownResellersSheetState();
}

class _DrillDownResellersSheetState extends State<_DrillDownResellersSheet> {
  String _search = '';
  CustomerTier? _tierFilter;

  @override
  Widget build(BuildContext context) {
    final filtered = widget.metrics.where((c) {
      final q = _search.toLowerCase();
      final matchesSearch = q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.shopName.toLowerCase().contains(q) ||
          c.phone.contains(q);

      if (!matchesSearch) return false;
      if (_tierFilter != null && c.tier != _tierFilter) return false;
      return true;
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(LucideIcons.users, size: 20, color: Color(0xFF9333EA)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Reseller Accounts Directory', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        Text('${widget.metrics.length} active wholesale buyers', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x, size: 20)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                onChanged: (val) => setState(() => _search = val),
                decoration: InputDecoration(
                  hintText: 'Search by shop name, owner, or phone...',
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: const Text('All Tiers'),
                      selected: _tierFilter == null,
                      onSelected: (_) => setState(() => _tierFilter = null),
                      selectedColor: const Color(0xFF0F172A),
                      labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _tierFilter == null ? Colors.white : const Color(0xFF475569)),
                    ),
                  ),
                  ...CustomerTier.values.map((tier) {
                    final isSel = _tierFilter == tier;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text('${tier.emoji} ${tier.displayName}'),
                        selected: isSel,
                        onSelected: (_) => setState(() => _tierFilter = isSel ? null : tier),
                        selectedColor: const Color(0xFF2563EB),
                        labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isSel ? Colors.white : const Color(0xFF475569)),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No resellers found matching criteria', style: TextStyle(color: Color(0xFF94A3B8))))
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        return ListTile(
                          onTap: () => widget.onCustomerSelected(c),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFDBEAFE),
                            child: Text(
                              (c.shopName.isNotEmpty ? c.shopName[0] : c.name[0]).toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2563EB)),
                            ),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  c.shopName.isNotEmpty ? c.shopName : c.name,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                                ),
                              ),
                              const SizedBox(width: 6),
                              CustomerTierBadge(tier: c.tier, isCompact: true),
                            ],
                          ),
                          subtitle: Text(
                            '${c.name} • ${c.phone} • ${c.orderCount} orders',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                widget.currencyFormat.format(c.totalSpend),
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF16A34A)),
                              ),
                              Text('AOV: ${widget.currencyFormat.format(c.averageOrderValue)}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
