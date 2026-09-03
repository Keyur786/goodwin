import 'package:flutter/material.dart';
import 'package:goodwin/core/services/firestore_order_repository.dart';
import 'package:goodwin/core/utils/product_image_resolver.dart';
import 'package:goodwin/features/admin/dashboard/presentation/screens/admin_dashboard_screen.dart';
import 'package:goodwin/models/order_model.dart';
import 'package:goodwin/models/user_model.dart';
import 'package:goodwin/shared/widgets/customer_tier_badge.dart';
import 'package:goodwin/shared/widgets/product_image_widget.dart';
import 'package:goodwin/shared/widgets/wholesale_invoice_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AdminAllOrdersScreen extends StatefulWidget {
  const AdminAllOrdersScreen({super.key});

  @override
  State<AdminAllOrdersScreen> createState() => _AdminAllOrdersScreenState();
}

class _AdminAllOrdersScreenState extends State<AdminAllOrdersScreen> {
  final _orderRepo = FirestoreOrderRepository();
  String _warehouseSearch = '';
  String _onlineSearch = '';
  String _warehouseStatus = 'All';
  String _onlineStatus = 'All';

  final List<String> _warehouseStatusFilters = [
    'All',
    'Confirmed',
    'Delivered',
  ];
  final List<String> _onlineStatusFilters = [
    'All',
    'Confirmed',
    'In Delivery',
    'Delivered',
  ];

  Future<void> _updateStatus(
    OrderModel order,
    OrderStatus newStatus,
    bool wasDelivered,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _orderRepo.transitionOrderStatus(
        order: order,
        newStatus: newStatus,
        wasDelivered: wasDelivered,
      );

      final isNowDelivered =
          newStatus == OrderStatus.pickedUp ||
          newStatus == OrderStatus.completed;

      String msg;
      if (isNowDelivered) {
        msg =
            'Order #${order.orderNumber} marked as Delivered! Stock deducted.';
      } else if (newStatus == OrderStatus.inDelivery) {
        msg = 'Order #${order.orderNumber} is now In Delivery.';
      } else {
        msg = wasDelivered
            ? 'Order #${order.orderNumber} set to Confirmed. Stock restored.'
            : 'Order #${order.orderNumber} status updated to Confirmed.';
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isNowDelivered
              ? const Color(0xFF16A34A)
              : (newStatus == OrderStatus.inDelivery
                    ? const Color(0xFFD97706)
                    : const Color(0xFF2563EB)),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildStatusChip(
    String st,
    String selectedStatus,
    ValueChanged<String> onSelected,
  ) {
    final isSelected = selectedStatus == st;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(st),
        selected: isSelected,
        selectedColor: const Color(0xFFDBEAFE),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          fontSize: 12,
        ),
        onSelected: (_) => onSelected(st),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('All Placed Orders'),
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.layoutDashboard, color: Color(0xFF2563EB)),
              tooltip: 'Dashboard',
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const AdminDashboardScreen(),
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xFF2563EB),
            indicatorWeight: 3,
            labelColor: Color(0xFF2563EB),
            unselectedLabelColor: Color(0xFF64748B),
            labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
            tabs: [
              Tab(
                icon: Icon(LucideIcons.store, size: 20),
                text: 'Warehouse Orders',
              ),
              Tab(
                icon: Icon(LucideIcons.truck, size: 20),
                text: 'Online Orders',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildWarehouseOrdersView(), _buildOnlineOrdersView()],
        ),
      ),
    );
  }

  Widget _buildWarehouseOrdersView() {
    return Column(
      children: [
        // Filter & Search Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                onChanged: (v) =>
                    setState(() => _warehouseSearch = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search warehouse orders, phone, code...',
                  prefixIcon: const Icon(
                    LucideIcons.search,
                    color: Color(0xFF2563EB),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _warehouseStatusFilters.map((st) {
                    return _buildStatusChip(
                      st,
                      _warehouseStatus,
                      (val) => setState(() => _warehouseStatus = val),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Stream List
        Expanded(
          child: StreamBuilder<List<OrderModel>>(
            stream: _orderRepo.streamAllOrders(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var orders = (snapshot.data ?? [])
                  .where((o) => !o.isOnlineOrder)
                  .toList();

              // Status Filter
              if (_warehouseStatus != 'All') {
                orders = orders.where((o) {
                  final isDelivered =
                      o.orderStatus == OrderStatus.pickedUp ||
                      o.orderStatus == OrderStatus.completed;
                  if (_warehouseStatus == 'Delivered') return isDelivered;
                  if (_warehouseStatus == 'Confirmed') return !isDelivered;
                  return true;
                }).toList();
              }

              // Search Query
              if (_warehouseSearch.isNotEmpty) {
                orders = orders.where((o) {
                  return o.orderNumber.toLowerCase().contains(
                        _warehouseSearch,
                      ) ||
                      o.customerName.toLowerCase().contains(_warehouseSearch) ||
                      (o.customerPhone?.toLowerCase().contains(
                            _warehouseSearch,
                          ) ??
                          false) ||
                      o.pickupCode.toLowerCase().contains(_warehouseSearch);
                }).toList();
              }

              if (orders.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.store,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _warehouseSearch.isNotEmpty
                              ? 'No warehouse orders match "$_warehouseSearch"'
                              : 'No warehouse pickup orders placed yet',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final totalRevenue = orders.fold<double>(
                0,
                (sum, o) => sum + o.totalAmount,
              );

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '🏬 Warehouse Pickup Orders',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${orders.length} Pickup Orders',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Pickup Value',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${totalRevenue.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Color(0xFFFEF08A),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final order = orders[index - 1];
                  final isDelivered =
                      order.orderStatus == OrderStatus.pickedUp ||
                      order.orderStatus == OrderStatus.completed;
                  final dateStr =
                      '${order.createdAt.day.toString().padLeft(2, '0')}/${order.createdAt.month.toString().padLeft(2, '0')}/${order.createdAt.year} at ${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Customer + Badge + Status
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            order.customerName.isNotEmpty
                                                ? order.customerName
                                                : 'Customer',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        CustomerTierBadge(
                                          tier: CustomerTier.fromString(
                                            order.customerTier,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '📞 ${order.customerPhone?.isNotEmpty == true ? order.customerPhone! : 'No phone'} • $dateStr',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDelivered
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDelivered
                                        ? const Color(0xFF86EFAC)
                                        : const Color(0xFFBAE6FD),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isDelivered
                                          ? LucideIcons.circleCheck
                                          : LucideIcons.store,
                                      size: 13,
                                      color: isDelivered
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFF0284C7),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isDelivered ? 'DELIVERED' : 'CONFIRMED',
                                      style: TextStyle(
                                        color: isDelivered
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFF0284C7),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Pickup Code Container
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Order: #${order.orderNumber}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDBEAFE),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Pickup Code: ${order.pickupCode}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Items List
                          ...order.items.map((it) {
                            final img = resolveOrderItemImage(it);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: ProductImageWidget(
                                      imageSrc: img,
                                      width: 36,
                                      height: 36,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${it.quantity}x ${it.productName}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '₹${(it.unitPrice * it.quantity).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Divider(height: 18),

                          // Total
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Amount',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '₹${order.totalAmount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => showWholesaleInvoiceModal(context, order, isAdmin: true),
                              icon: const Icon(LucideIcons.receipt, size: 16),
                              label: const Text('View Wholesale Invoice / PO'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                side: const BorderSide(color: Color(0xFF2563EB)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 2-Option Status Toggle for Warehouse: Confirmed vs Delivered
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: isDelivered
                                        ? () => _updateStatus(
                                            order,
                                            OrderStatus.confirmed,
                                            isDelivered,
                                          )
                                        : null,
                                    borderRadius: BorderRadius.circular(9),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: !isDelivered
                                            ? const Color(0xFF0284C7)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'CONFIRMED',
                                        style: TextStyle(
                                          color: !isDelivered
                                              ? Colors.white
                                              : const Color(0xFF64748B),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: InkWell(
                                    onTap: !isDelivered
                                        ? () => _updateStatus(
                                            order,
                                            OrderStatus.pickedUp,
                                            isDelivered,
                                          )
                                        : null,
                                    borderRadius: BorderRadius.circular(9),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDelivered
                                            ? const Color(0xFF16A34A)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if (isDelivered)
                                            const Padding(
                                              padding: EdgeInsets.only(
                                                right: 5,
                                              ),
                                              child: Icon(
                                                LucideIcons.circleCheck,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                            ),
                                          Text(
                                            'DELIVERED',
                                            style: TextStyle(
                                              color: isDelivered
                                                  ? Colors.white
                                                  : const Color(0xFF64748B),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isDelivered
                                ? '✓ Order Delivered • Product quantities deducted from catalog'
                                : '• Order Confirmed • Product quantities will be deducted upon delivery',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDelivered
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFF0284C7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOnlineOrdersView() {
    return Column(
      children: [
        // Filter & Search Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                onChanged: (v) =>
                    setState(() => _onlineSearch = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search online orders, address, payment ID...',
                  prefixIcon: const Icon(
                    LucideIcons.search,
                    color: Color(0xFF2563EB),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _onlineStatusFilters.map((st) {
                    return _buildStatusChip(
                      st,
                      _onlineStatus,
                      (val) => setState(() => _onlineStatus = val),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Stream List
        Expanded(
          child: StreamBuilder<List<OrderModel>>(
            stream: _orderRepo.streamAllOrders(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var orders = (snapshot.data ?? [])
                  .where((o) => o.isOnlineOrder)
                  .toList();

              // Status Filter
              if (_onlineStatus != 'All') {
                orders = orders.where((o) {
                  final isDelivered =
                      o.orderStatus == OrderStatus.pickedUp ||
                      o.orderStatus == OrderStatus.completed;
                  final isInDelivery = o.orderStatus == OrderStatus.inDelivery;
                  if (_onlineStatus == 'Delivered') return isDelivered;
                  if (_onlineStatus == 'In Delivery') return isInDelivery;
                  if (_onlineStatus == 'Confirmed') {
                    return !isDelivered && !isInDelivery;
                  }
                  return true;
                }).toList();
              }

              // Search Query
              if (_onlineSearch.isNotEmpty) {
                orders = orders.where((o) {
                  return o.orderNumber.toLowerCase().contains(_onlineSearch) ||
                      o.customerName.toLowerCase().contains(_onlineSearch) ||
                      (o.customerPhone?.toLowerCase().contains(_onlineSearch) ??
                          false) ||
                      (o.deliveryAddress?.toLowerCase().contains(
                            _onlineSearch,
                          ) ??
                          false) ||
                      (o.paymentId?.toLowerCase().contains(_onlineSearch) ??
                          false);
                }).toList();
              }

              if (orders.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.truck,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _onlineSearch.isNotEmpty
                              ? 'No online delivery orders match "$_onlineSearch"'
                              : 'No online prepaid orders placed yet',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final totalRevenue = orders.fold<double>(
                0,
                (sum, o) => sum + o.totalAmount,
              );

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '🚚 Prepaid Online Orders (Razorpay)',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${orders.length} Online Deliveries',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Prepaid Value',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${totalRevenue.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Color(0xFFFEF08A),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final order = orders[index - 1];
                  final isDelivered =
                      order.orderStatus == OrderStatus.pickedUp ||
                      order.orderStatus == OrderStatus.completed;
                  final isInDelivery =
                      order.orderStatus == OrderStatus.inDelivery;
                  final dateStr =
                      '${order.createdAt.day.toString().padLeft(2, '0')}/${order.createdAt.month.toString().padLeft(2, '0')}/${order.createdAt.year} at ${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}';

                  Color badgeBg;
                  Color badgeText;
                  Color badgeBorder;
                  String badgeLabel;
                  IconData badgeIcon;

                  if (isDelivered) {
                    badgeBg = const Color(0xFFDCFCE7);
                    badgeText = const Color(0xFF16A34A);
                    badgeBorder = const Color(0xFF86EFAC);
                    badgeLabel = 'DELIVERED';
                    badgeIcon = LucideIcons.circleCheck;
                  } else if (isInDelivery) {
                    badgeBg = const Color(0xFFFEF3C7);
                    badgeText = const Color(0xFFD97706);
                    badgeBorder = const Color(0xFFFCD34D);
                    badgeLabel = 'IN DELIVERY';
                    badgeIcon = LucideIcons.truck;
                  } else {
                    badgeBg = const Color(0xFFDBEAFE);
                    badgeText = const Color(0xFF2563EB);
                    badgeBorder = const Color(0xFF93C5FD);
                    badgeLabel = 'CONFIRMED';
                    badgeIcon = LucideIcons.package;
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Customer + Badge + Status
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            order.customerName.isNotEmpty
                                                ? order.customerName
                                                : 'Customer',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        CustomerTierBadge(
                                          tier: CustomerTier.fromString(
                                            order.customerTier,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '📞 ${order.customerPhone?.isNotEmpty == true ? order.customerPhone! : 'No phone'} • $dateStr',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: badgeBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(badgeIcon, size: 13, color: badgeText),
                                    const SizedBox(width: 4),
                                    Text(
                                      badgeLabel,
                                      style: TextStyle(
                                        color: badgeText,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Online Delivery & Address Info (NO PICKUP CODE)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F7FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFBFDBFE),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Order: #${order.orderNumber}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: Color(0xFF1E3A8A),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFF86EFAC),
                                        ),
                                      ),
                                      child: const Text(
                                        'PAID (Razorpay)',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      LucideIcons.mapPin,
                                      color: Color(0xFF2563EB),
                                      size: 15,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        order.deliveryAddress ??
                                            'Doorstep Delivery',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Color(0xFF334155),
                                          fontWeight: FontWeight.w600,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (order.paymentId != null &&
                                    order.paymentId!.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'Razorpay Ref: ${order.paymentId}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Items List
                          ...order.items.map((it) {
                            final img = resolveOrderItemImage(it);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: ProductImageWidget(
                                      imageSrc: img,
                                      width: 36,
                                      height: 36,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${it.quantity}x ${it.productName}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '₹${(it.unitPrice * it.quantity).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Divider(height: 18),

                          // Total
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Amount',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '₹${order.totalAmount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => showWholesaleInvoiceModal(context, order, isAdmin: true),
                              icon: const Icon(LucideIcons.receipt, size: 16),
                              label: const Text('View Wholesale Invoice / PO'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                side: const BorderSide(color: Color(0xFF2563EB)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 3-Option Status Toggle for Online: Confirmed, In Delivery, Delivered
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                // 1. CONFIRMED
                                Expanded(
                                  child: InkWell(
                                    onTap: (!isDelivered && !isInDelivery)
                                        ? null
                                        : () => _updateStatus(
                                            order,
                                            OrderStatus.confirmed,
                                            isDelivered,
                                          ),
                                    borderRadius: BorderRadius.circular(9),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (!isDelivered && !isInDelivery)
                                            ? const Color(0xFF2563EB)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'CONFIRMED',
                                        style: TextStyle(
                                          color: (!isDelivered && !isInDelivery)
                                              ? Colors.white
                                              : const Color(0xFF64748B),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // 2. IN DELIVERY
                                Expanded(
                                  child: InkWell(
                                    onTap: isInDelivery
                                        ? null
                                        : () => _updateStatus(
                                            order,
                                            OrderStatus.inDelivery,
                                            isDelivered,
                                          ),
                                    borderRadius: BorderRadius.circular(9),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isInDelivery
                                            ? const Color(0xFFD97706)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if (isInDelivery)
                                            const Padding(
                                              padding: EdgeInsets.only(
                                                right: 3,
                                              ),
                                              child: Icon(
                                                LucideIcons.truck,
                                                size: 13,
                                                color: Colors.white,
                                              ),
                                            ),
                                          Text(
                                            'IN DELIVERY',
                                            style: TextStyle(
                                              color: isInDelivery
                                                  ? Colors.white
                                                  : const Color(0xFF64748B),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // 3. DELIVERED
                                Expanded(
                                  child: InkWell(
                                    onTap: isDelivered
                                        ? null
                                        : () => _updateStatus(
                                            order,
                                            OrderStatus.pickedUp,
                                            isDelivered,
                                          ),
                                    borderRadius: BorderRadius.circular(9),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDelivered
                                            ? const Color(0xFF16A34A)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if (isDelivered)
                                            const Padding(
                                              padding: EdgeInsets.only(
                                                right: 3,
                                              ),
                                              child: Icon(
                                                LucideIcons.circleCheck,
                                                size: 13,
                                                color: Colors.white,
                                              ),
                                            ),
                                          Text(
                                            'DELIVERED',
                                            style: TextStyle(
                                              color: isDelivered
                                                  ? Colors.white
                                                  : const Color(0xFF64748B),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isDelivered
                                ? '✓ Order Delivered • Product quantities deducted from catalog'
                                : (isInDelivery
                                      ? '🚚 Order In Delivery • Courier in transit to destination'
                                      : '📦 Order Confirmed • Product quantities will be deducted on delivery'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDelivered
                                  ? const Color(0xFF16A34A)
                                  : (isInDelivery
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF2563EB)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

