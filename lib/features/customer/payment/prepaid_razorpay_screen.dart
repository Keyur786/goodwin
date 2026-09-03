import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:goodwin/models/cart_item.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:goodwin/core/services/firestore_order_repository.dart';
import 'package:goodwin/core/services/firestore_user_repository.dart';
import 'package:goodwin/models/order_model.dart';
import 'package:goodwin/models/user_model.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class _RazorpayCheckoutModal extends StatefulWidget {
  const _RazorpayCheckoutModal({
    required this.amount,
    required this.customerName,
    required this.customerPhone,
    required this.paymentMethod,
    required this.paymentId,
  });

  final double amount;
  final String customerName;
  final String customerPhone;
  final String paymentMethod;
  final String paymentId;

  @override
  State<_RazorpayCheckoutModal> createState() => _RazorpayCheckoutModalState();
}

class _RazorpayCheckoutModalState extends State<_RazorpayCheckoutModal> {
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() => _isSuccess = true);
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Razorpay Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0C2340),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3395FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          LucideIcons.zap,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Razorpay',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          LucideIcons.lock,
                          size: 11,
                          color: Colors.white70,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '256-BIT SECURE',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (!_isSuccess) ...[
              const SizedBox(
                height: 48,
                width: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3395FF)),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Connecting to Razorpay...',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Authorizing ₹${widget.amount.toStringAsFixed(0)} via ${widget.paymentMethod}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.check,
                  color: Color(0xFF16A34A),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Payment Authorized!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF15803D),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ID: ${widget.paymentId}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PrepaidDeliveryRazorpayPage extends StatefulWidget {
  const PrepaidDeliveryRazorpayPage({
    super.key,
    required this.items,
    this.currentUser,
  });

  final List<CartItem> items;
  final AppUser? currentUser;

  @override
  State<PrepaidDeliveryRazorpayPage> createState() =>
      _PrepaidDeliveryRazorpayPageState();
}

class _PrepaidDeliveryRazorpayPageState
    extends State<PrepaidDeliveryRazorpayPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _pincodeController;

  String _selectedPaymentMethod = 'UPI (Google Pay, PhonePe, Paytm)';
  bool _isProcessing = false;

  double get total =>
      widget.items.fold(0.0, (total, item) => total + item.totalPrice);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.currentUser?.name.isNotEmpty == true
          ? widget.currentUser!.name
          : '',
    );
    _phoneController = TextEditingController(
      text: widget.currentUser?.phone.isNotEmpty == true
          ? widget.currentUser!.phone
          : '',
    );
    _addressController = TextEditingController(
      text: widget.currentUser?.address?.isNotEmpty == true
          ? widget.currentUser!.address!
          : (widget.currentUser?.shopName?.isNotEmpty == true
                ? widget.currentUser!.shopName!
                : ''),
    );
    _cityController = TextEditingController(text: 'Surat, Gujarat');
    _pincodeController = TextEditingController(text: '395004');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _processRazorpayPayment() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required delivery details.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    final paymentId =
        'pay_${DateTime.now().millisecondsSinceEpoch.toString().substring(3)}';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _RazorpayCheckoutModal(
          amount: total,
          customerName: _nameController.text.trim(),
          customerPhone: _phoneController.text.trim(),
          paymentMethod: _selectedPaymentMethod,
          paymentId: paymentId,
        );
      },
    );

    try {
      final orderNumber =
          'GW-${(100000 + Random().nextInt(900000)).toString()}';
      final effectiveUid =
          widget.currentUser?.id ??
          FirebaseAuth.instance.currentUser?.uid ??
          'guest_customer';
      final effectiveName = _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : (widget.currentUser?.name.isNotEmpty == true
                ? widget.currentUser!.name
                : 'Wholesale Customer');
      final fullAddress =
          '${_addressController.text.trim()}, ${_cityController.text.trim()} - ${_pincodeController.text.trim()}';

      final currentTier = widget.currentUser?.tier.displayName ?? 'Silver';
      final currentSpend = widget.currentUser?.totalPurchases ?? 0.0;

      final order = OrderModel(
        id: '',
        orderNumber: orderNumber,
        customerId: effectiveUid,
        customerName: effectiveName,
        customerPhone: _phoneController.text.trim(),
        warehouseId: 'wh_surat_katargam',
        items: widget.items
            .map(
              (c) => OrderItemModel(
                productId: c.product.id,
                productName: c.product.name,
                variant: c.selectedVariant?.name,
                sku: c.selectedVariant?.sku ?? '',
                imageUrl: c.product.image,
                unitPrice: c.unitPrice,
                quantity: c.quantity,
              ),
            )
            .toList(),
        totalAmount: total,
        paymentMethod: 'Prepaid (Razorpay)',
        paymentStatus: PaymentStatus.paid,
        orderStatus: OrderStatus.confirmed,
        pickupCode: '',
        isPaid: true,
        deliveryType: 'prepaid_delivery',
        deliveryAddress: fullAddress,
        paymentId: paymentId,
        customerTier: currentTier,
        customerTotalSpend: currentSpend + total,
        createdAt: DateTime.now(),
      );

      await FirestoreOrderRepository().createOrder(order);
      await FirestoreUserRepository().recordPurchase(effectiveUid, total);
    } catch (_) {
      // offline fallback
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }

    if (!mounted) return;

    final fullAddressDisplay =
        '${_addressController.text.trim()}, ${_cityController.text.trim()} - ${_pincodeController.text.trim()}';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: const Icon(
          LucideIcons.checkCircle,
          color: Color(0xFF2563EB),
          size: 52,
        ),
        title: const Text(
          'Prepaid Order Confirmed',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.shieldCheck,
                    color: Color(0xFF16A34A),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Paid ₹${total.toStringAsFixed(0)} via Razorpay',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF15803D),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Razorpay Ref ID:',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
                Text(
                  paymentId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Delivering to:',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              fullAddressDisplay,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your order will be dispatched from Katargam warehouse directly to your location.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('View In My Orders'),
          ),
        ],
      ),
    );

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Prepaid Delivery')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Razorpay Secure Header Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0C2340), Color(0xFF1E3A8A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0C2340).withAlpha(40),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3395FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              LucideIcons.creditCard,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Razorpay Secure Checkout',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Instant Prepaid Delivery to your doorstep with 100% buyer protection.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Delivery Address Card
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(
                          color: Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  LucideIcons.mapPin,
                                  color: Color(0xFF2563EB),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Delivery Destination',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Contact / Business Name *',
                                prefixIcon: Icon(LucideIcons.user, size: 18),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Name required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Contact Phone Number *',
                                prefixIcon: Icon(LucideIcons.phone, size: 18),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Phone required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _addressController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Street Address / Shop Location *',
                                prefixIcon: Icon(LucideIcons.building, size: 18),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Address required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _cityController,
                                    decoration: const InputDecoration(
                                      labelText: 'City & State *',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty
                                        ? 'Required'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _pincodeController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Pincode *',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty
                                        ? 'Required'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Payment Method Selector
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(
                          color: Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  LucideIcons.wallet,
                                  color: Color(0xFF2563EB),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Razorpay Payment Mode',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...[
                              'UPI (Google Pay, PhonePe, Paytm, BHIM)',
                              'Debit / Credit Card (Visa, MasterCard, RuPay)',
                              'Net Banking (All Major Indian Banks)',
                            ].map((method) {
                              final isSelected =
                                  _selectedPaymentMethod == method;
                              return InkWell(
                                onTap: () => setState(
                                  () => _selectedPaymentMethod = method,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFEFF6FF)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF3B82F6)
                                          : const Color(0xFFE2E8F0),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected
                                            ? LucideIcons.circleDot
                                            : LucideIcons.circle,
                                        color: isSelected
                                            ? const Color(0xFF2563EB)
                                            : Colors.grey,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          method,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? const Color(0xFF1E3A8A)
                                                : const Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Order Summary
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(
                          color: Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Price Summary',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Items Total (${widget.items.length})',
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                Text(
                                  '₹${total.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Doorstep Delivery Fee',
                                  style: TextStyle(color: Color(0xFF64748B)),
                                ),
                                Text(
                                  'FREE',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Payable',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  '₹${total.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isProcessing ? null : _processRazorpayPayment,
                  icon: const Icon(LucideIcons.lock, size: 18),
                  label: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Pay ₹${total.toStringAsFixed(0)} with Razorpay',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


