import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:goodwin/core/services/pdf_invoice_service.dart';
import 'package:goodwin/core/utils/product_image_resolver.dart';
import 'package:goodwin/models/order_model.dart';
import 'package:goodwin/models/user_model.dart';
import 'package:goodwin/shared/widgets/customer_tier_badge.dart';
import 'package:goodwin/shared/widgets/product_image_widget.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void showWholesaleInvoiceModal(
  BuildContext context,
  OrderModel order, {
  bool isAdmin = true,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => WholesaleInvoiceSheet(
      order: order,
      isAdmin: isAdmin,
    ),
  );
}

class WholesaleInvoiceSheet extends StatelessWidget {
  final OrderModel order;
  final bool isAdmin;

  const WholesaleInvoiceSheet({
    super.key,
    required this.order,
    this.isAdmin = true,
  });

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}';
  }

  void _copyInvoiceToClipboard(BuildContext context) {
    final buffer = StringBuffer();
    buffer.writeln('GOODWIN WHOLESALE & DISTRIBUTION');
    buffer.writeln('Tax Invoice / Purchase Order: #${order.orderNumber.isNotEmpty ? order.orderNumber : order.id}');
    buffer.writeln('Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt)}');
    buffer.writeln('Customer: ${order.customerName}');
    if (order.pickupCode.isNotEmpty) {
      buffer.writeln('Pickup Code: ${order.pickupCode}');
    }
    buffer.writeln('----------------------------------------');
    for (final item in order.items) {
      final variantText = item.variant != null && item.variant!.isNotEmpty
          ? ' (${item.variant})'
          : '';
      buffer.writeln('${item.productName}$variantText');
      buffer.writeln('  ${item.quantity} x ${_formatCurrency(item.unitPrice)} = ${_formatCurrency(item.totalPrice)}');
    }
    buffer.writeln('----------------------------------------');
    buffer.writeln('Total Items: ${order.items.fold<int>(0, (sum, i) => sum + i.quantity)}');
    buffer.writeln('Grand Total: ${_formatCurrency(order.totalAmount)}');
    buffer.writeln('Status: ${order.orderStatus.name.toUpperCase()}');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invoice details copied to clipboard!'),
        backgroundColor: Color(0xFF2563EB),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleDownloadPdf(BuildContext context) async {
    try {
      await PdfInvoiceService.printInvoice(order);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _handleSharePdf(BuildContext context) async {
    try {
      await PdfInvoiceService.shareInvoice(order);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share PDF: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final totalItems = order.items.fold<int>(0, (sum, i) => sum + i.quantity);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 6),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    const Icon(LucideIcons.receiptText, color: Color(0xFF2563EB), size: 24),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Wholesale Tax Invoice',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        LucideIcons.printer,
                        color: Color(0xFF2563EB),
                        size: 22,
                      ),
                      tooltip: 'Print / Save PDF',
                      onPressed: () => _handleDownloadPdf(context),
                    ),
                    IconButton(
                      icon: const Icon(
                        LucideIcons.share2,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                      tooltip: 'Share PDF',
                      onPressed: () => _handleSharePdf(context),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Invoice Body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Header Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'GOODWIN WHOLESALE',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: Color(0xFF2563EB),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    'B2B Distribution Hub',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              CustomerTierBadge(
                                tier: CustomerTier.fromString(order.customerTier),
                                isCompact: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Invoice / PO No:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  Text(
                                    '#${order.orderNumber.isNotEmpty ? order.orderNumber : order.id}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Date & Time:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  Text(
                                    dateFormat.format(order.createdAt),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Billed To:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  Text(
                                    order.customerName.isNotEmpty ? order.customerName : 'Reseller Buyer',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ],
                              ),
                              if (order.pickupCode.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Pickup Code: ${order.pickupCode}',
                                    style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Itemized Table Title
                    const Text(
                      'Purchased Items',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 10),

                    // Itemized List
                    ...order.items.map((item) {
                      final hasVariant = item.variant != null && item.variant!.isNotEmpty;
                      final img = resolveOrderItemImage(item);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ProductImageWidget(
                                imageSrc: img,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
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
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (hasVariant)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.variant!,
                                          style: const TextStyle(
                                            color: Color(0xFF2563EB),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${item.quantity} units @ ${_formatCurrency(item.unitPrice)}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatCurrency(item.totalPrice),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Summary Box
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Quantity:', style: TextStyle(color: Color(0xFF64748B))),
                        Text('$totalItems units', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal:', style: TextStyle(color: Color(0xFF64748B))),
                        Text(_formatCurrency(order.totalAmount), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Taxes & Warehouse Fees:', style: TextStyle(color: Color(0xFF64748B))),
                        Text('Included in wholesale price', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Grand Total:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        Text(
                          _formatCurrency(order.totalAmount),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Primary Action: Print / Save PDF
                    FilledButton.icon(
                      onPressed: () => _handleDownloadPdf(context),
                      icon: const Icon(LucideIcons.printer, size: 18),
                      label: const Text('Download / Print PDF Invoice'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Secondary Actions: Share PDF & Copy Text
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _handleSharePdf(context),
                            icon: const Icon(LucideIcons.share2, size: 16, color: Color(0xFF2563EB)),
                            label: const Text('Share PDF'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFF2563EB)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _copyInvoiceToClipboard(context),
                            icon: const Icon(LucideIcons.copy, size: 16),
                            label: const Text('Copy Text'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF475569),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
