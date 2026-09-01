import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goodwin/models/order_model.dart';

class FirestoreOrderRepository {
  FirestoreOrderRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<OrderModel?> getOrder(String orderId) async {
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();
      if (!doc.exists) return null;
      return OrderModel.fromJson({'id': doc.id, ...doc.data()!});
    } catch (e) {
      return null;
    }
  }

  Stream<List<OrderModel>> streamAllOrders() {
    return _firestore.collection('orders').snapshots().map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  Stream<List<OrderModel>> streamOrdersByCustomer(String customerId) {
    return _firestore.collection('orders').snapshots().map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromJson({'id': doc.id, ...doc.data()}))
          .where((order) =>
              order.customerId == customerId ||
              (customerId.isNotEmpty &&
                  (order.customerId == 'guest_customer' ||
                      order.customerId.isEmpty)))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  Future<List<OrderModel>> getOrdersByCustomer(String customerId) async {
    try {
      final snapshot = await _firestore.collection('orders').get();
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromJson({'id': doc.id, ...doc.data()}))
          .where((order) =>
              order.customerId == customerId ||
              (customerId.isNotEmpty &&
                  (order.customerId == 'guest_customer' ||
                      order.customerId.isEmpty)))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    } catch (e) {
      return [];
    }
  }

  /// Paginated query for orders with optional customer filter
  Future<List<OrderModel>> getOrdersPaginated({
    int limit = 20,
    DocumentSnapshot? startAfter,
    String? customerId,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('orders');

      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customerId', isEqualTo: customerId);
      }

      query = query.limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    } catch (e) {
      return [];
    }
  }

  Future<List<OrderModel>> getOrdersByWarehouse(String warehouseId) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('warehouseId', isEqualTo: warehouseId)
          .get();
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    } catch (e) {
      return [];
    }
  }

  Future<List<OrderModel>> getOrdersByStatus({
    required String warehouseId,
    required OrderStatus status,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('warehouseId', isEqualTo: warehouseId)
          .where('orderStatus', isEqualTo: status.name)
          .get();
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    } catch (e) {
      return [];
    }
  }

  Future<OrderModel> createOrder(OrderModel order) async {
    try {
      final docRef = _firestore.collection('orders').doc();
      final orderWithId = order.copyWith(id: docRef.id);
      await docRef.set(orderWithId.toJson());
      return orderWithId;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateOrder({
    required String orderId,
    required List<OrderItemModel> items,
    required double totalAmount,
  }) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'items': items.map((item) => item.toJson()).toList(),
        'totalAmount': totalAmount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> cancelOrder(String orderId) async {
    try {
      await updateOrderStatus(orderId: orderId, status: OrderStatus.cancelled);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteOrder(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).delete();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
  }) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'orderStatus': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> markOrderAsPickedUp({
    required String orderId,
    required DateTime pickedUpAt,
  }) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'orderStatus': OrderStatus.pickedUp.name,
        'pickedUpAt': pickedUpAt.toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Sets order status to Delivered (pickedUp) and deducts product quantities from inventory.
  Future<void> markOrderAsDeliveredAndDeductStock(OrderModel order) async {
    try {
      await _firestore.collection('orders').doc(order.id).update({
        'orderStatus': OrderStatus.pickedUp.name,
        'pickedUpAt': DateTime.now().toIso8601String(),
        'isPaid': true,
        'stockDeducted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Deduct available stock for each product in the delivered order
      for (final item in order.items) {
        if (item.productId.isEmpty) continue;
        try {
          final prodDoc =
              await _firestore.collection('products').doc(item.productId).get();
          if (prodDoc.exists && prodDoc.data() != null) {
            final currentQty =
                (prodDoc.data()!['availableQty'] as num?)?.toInt() ?? 0;
            final updatedQty = (currentQty - item.quantity).clamp(0, 999999);
            await _firestore.collection('products').doc(item.productId).update({
              'availableQty': updatedQty,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } catch (_) {}
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Sets order status back to Confirmed and restores inventory quantities if needed.
  Future<void> markOrderAsConfirmedAndRestoreStock(OrderModel order) async {
    try {
      await _firestore.collection('orders').doc(order.id).update({
        'orderStatus': OrderStatus.confirmed.name,
        'stockDeducted': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Restore available stock for each product
      for (final item in order.items) {
        if (item.productId.isEmpty) continue;
        try {
          final prodDoc =
              await _firestore.collection('products').doc(item.productId).get();
          if (prodDoc.exists && prodDoc.data() != null) {
            final currentQty =
                (prodDoc.data()!['availableQty'] as num?)?.toInt() ?? 0;
            final updatedQty = currentQty + item.quantity;
            await _firestore.collection('products').doc(item.productId).update({
              'availableQty': updatedQty,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } catch (_) {}
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Updates order status to target status, handling inventory deduction only on transition to Delivered,
  /// and inventory restoration if transitioned away from Delivered.
  Future<void> transitionOrderStatus({
    required OrderModel order,
    required OrderStatus newStatus,
    required bool wasDelivered,
  }) async {
    final isNowDelivered =
        newStatus == OrderStatus.pickedUp || newStatus == OrderStatus.completed;

    try {
      await _firestore.collection('orders').doc(order.id).update({
        'orderStatus': newStatus.name,
        'stockDeducted': isNowDelivered,
        if (isNowDelivered) 'pickedUpAt': DateTime.now().toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!wasDelivered && isNowDelivered) {
        // Deduct available stock for each product
        for (final item in order.items) {
          if (item.productId.isEmpty) continue;
          try {
            final prodDoc = await _firestore
                .collection('products')
                .doc(item.productId)
                .get();
            if (prodDoc.exists && prodDoc.data() != null) {
              final currentQty =
                  (prodDoc.data()!['availableQty'] as num?)?.toInt() ?? 0;
              final updatedQty = (currentQty - item.quantity).clamp(0, 999999);
              await _firestore.collection('products').doc(item.productId).update({
                'availableQty': updatedQty,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          } catch (_) {}
        }
      } else if (wasDelivered && !isNowDelivered) {
        // Restore stock
        for (final item in order.items) {
          if (item.productId.isEmpty) continue;
          try {
            final prodDoc = await _firestore
                .collection('products')
                .doc(item.productId)
                .get();
            if (prodDoc.exists && prodDoc.data() != null) {
              final currentQty =
                  (prodDoc.data()!['availableQty'] as num?)?.toInt() ?? 0;
              final updatedQty = currentQty + item.quantity;
              await _firestore.collection('products').doc(item.productId).update({
                'availableQty': updatedQty,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> recordPayment({
    required String orderId,
    required double amount,
    required PaymentStatus status,
  }) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'paymentStatus': status.name,
        'isPaid': status == PaymentStatus.paid,
        'paidAt': status == PaymentStatus.paid ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<List<OrderModel>> getReadyForPickup(String warehouseId) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('warehouseId', isEqualTo: warehouseId)
          .where('orderStatus', isEqualTo: OrderStatus.readyForPickup.name)
          .get();
      return snapshot.docs
          .map((doc) => OrderModel.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      return [];
    }
  }
}

extension OrderModelCopyWith on OrderModel {
  OrderModel copyWith({
    String? id,
    String? orderNumber,
    String? customerId,
    String? customerName,
    String? warehouseId,
    List<OrderItemModel>? items,
    double? totalAmount,
    String? paymentMethod,
    PaymentStatus? paymentStatus,
    OrderStatus? orderStatus,
    String? pickupCode,
    DateTime? pickedUpAt,
    DateTime? createdAt,
    DateTime? pickupDate,
    String? pickupTimeSlot,
    bool? isPaid,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      warehouseId: warehouseId ?? this.warehouseId,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      orderStatus: orderStatus ?? this.orderStatus,
      pickupCode: pickupCode ?? this.pickupCode,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      createdAt: createdAt ?? this.createdAt,
      pickupDate: pickupDate ?? this.pickupDate,
      pickupTimeSlot: pickupTimeSlot ?? this.pickupTimeSlot,
      isPaid: isPaid ?? this.isPaid,
    );
  }
}
