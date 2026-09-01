import 'package:firebase_auth/firebase_auth.dart';
import 'package:goodwin/models/user_model.dart';
import 'package:goodwin/shared/widgets/customer_tier_badge.dart';
import 'package:flutter/material.dart';
import 'package:goodwin/core/services/firestore_order_repository.dart';
import 'package:goodwin/features/admin/dialogs/edit_order_dialog.dart';
import 'package:goodwin/models/order_model.dart';
import 'package:goodwin/shared/widgets/wholesale_invoice_sheet.dart';

class CustomerOrdersScreen extends StatelessWidget {
  final String? userId;

  const CustomerOrdersScreen({super.key, this.userId});

  Widget _buildCustomerOrderStatusBadge(OrderModel order) {
    Color bgColor;
    Color textColor;
    Color borderColor;
    String label;
    IconData icon;

    if (order.isOnlineOrder) {
      if (order.orderStatus == OrderStatus.pickedUp ||
          order.orderStatus == OrderStatus.completed) {
        bgColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF16A34A);
        borderColor = const Color(0xFF86EFAC);
        label = 'DELIVERED';
        icon = Icons.check_circle_rounded;
      } else if (order.orderStatus == OrderStatus.inDelivery) {
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        borderColor = const Color(0xFFFCD34D);
        label = 'IN DELIVERY';
        icon = Icons.local_shipping_rounded;
      } else {
        bgColor = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF2563EB);
        borderColor = const Color(0xFF93C5FD);
        label = 'CONFIRMED';
        icon = Icons.inventory_2_rounded;
      }
    } else {
      if (order.orderStatus == OrderStatus.pickedUp ||
          order.orderStatus == OrderStatus.completed) {
        bgColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF16A34A);
        borderColor = const Color(0xFF86EFAC);
        label = 'DELIVERED';
        icon = Icons.check_circle_rounded;
      } else {
        bgColor = const Color(0xFFCCFBF1);
        textColor = const Color(0xFF0F766E);
        borderColor = const Color(0xFF99F6E4);
        label = 'CONFIRMED';
        icon = Icons.storefront_rounded;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderRepo = FirestoreOrderRepository();
    final effectiveUserId = userId?.isNotEmpty == true
        ? userId!
        : (FirebaseAuth.instance.currentUser?.uid ?? 'guest_customer');

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: StreamBuilder<List<OrderModel>>(
        stream: orderRepo.streamOrdersByCustomer(effectiveUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 68,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No orders placed yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Add items to your cart and checkout. Your orders will appear here in real-time.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final order = orders[index];
              final dateStr =
                  '${order.createdAt.day.toString().padLeft(2, '0')}/${order.createdAt.month.toString().padLeft(2, '0')}/${order.createdAt.year} at ${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}';

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFF1F5F9), width: 1.2),
                ),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    order.orderNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17,
                                      color: Color(0xFF0F172A),
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
                                dateStr,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          _buildCustomerOrderStatusBadge(order),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (order.isOnlineOrder) ...[
                        // Prepaid Online Delivery - NO PICKUP CODE
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F7FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDBEAFE),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.local_shipping_rounded,
                                  color: Color(0xFF2563EB),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Prepaid Delivery (Razorpay)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF2563EB),
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFF86EFAC),
                                            ),
                                          ),
                                          child: const Text(
                                            'PAID',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF16A34A),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      order.deliveryAddress ??
                                          'Doorstep Delivery',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF334155),
                                        fontWeight: FontWeight.w600,
                                        height: 1.3,
                                      ),
                                    ),
                                    if (order.paymentId != null &&
                                        order.paymentId!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Payment ID: ${order.paymentId}',
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
                            ],
                          ),
                        ),
                      ] else ...[
                        // Warehouse Pickup - WITH PICKUP CODE
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFCCFBF1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.qr_code_2_rounded,
                                      color: Color(0xFF0F766E),
                                      size: 26,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Pickup Code',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F766E),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          Text(
                                            'Katargam Warehouse, Surat',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF99F6E4),
                                  ),
                                ),
                                child: Text(
                                  order.pickupCode,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      const Text(
                        'Items Ordered:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...order.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.productName} × ${item.quantity}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Color(0xFF1E293B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '₹${item.totalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '₹${order.totalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => showWholesaleInvoiceModal(context, order),
                          icon: const Icon(Icons.receipt_long_rounded, size: 18),
                          label: const Text('View Wholesale Invoice / PO'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F766E),
                            side: const BorderSide(color: Color(0xFF0F766E)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      if (!order.isOnlineOrder &&
                          order.orderStatus != OrderStatus.pickedUp &&
                          order.orderStatus != OrderStatus.completed &&
                          order.orderStatus != OrderStatus.cancelled) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  showDialog<void>(
                                    context: context,
                                    builder: (dialogCtx) => EditOrderDialog(
                                      order: order,
                                      onOrderUpdated: () {},
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.edit_note_rounded,
                                  size: 18,
                                ),
                                label: const Text('Edit Items'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0F766E),
                                  side: const BorderSide(
                                    color: Color(0xFF0F766E),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _confirmDeleteOrder(context, order),
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: Colors.red.shade700,
                              ),
                              label: Text(
                                'Delete',
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade300),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else if (order.isOnlineOrder) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              order.orderStatus == OrderStatus.pickedUp ||
                                      order.orderStatus == OrderStatus.completed
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.verified_user_rounded,
                              size: 15,
                              color: const Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              order.orderStatus == OrderStatus.pickedUp ||
                                      order.orderStatus == OrderStatus.completed
                                  ? 'Delivered • Prepaid Razorpay Order'
                                  : 'Prepaid Razorpay Order • Placed & Verified',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ] else if (order.orderStatus == OrderStatus.pickedUp ||
                          order.orderStatus == OrderStatus.completed) ...[
                        const SizedBox(height: 10),
                        const Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 16,
                              color: Color(0xFF16A34A),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Delivered • Order cannot be modified',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF16A34A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteOrder(
    BuildContext context,
    OrderModel order,
  ) async {
    if (order.isOnlineOrder) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Prepaid Razorpay orders cannot be modified or deleted.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_forever_rounded,
                color: Colors.red.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Delete Order?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete order #${order.orderNumber}? This will remove the order permanently.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Keep Order'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete Order'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await FirestoreOrderRepository().deleteOrder(order.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Order #${order.orderNumber} deleted successfully.',
              ),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete order: $e')));
        }
      }
    }
  }
}


