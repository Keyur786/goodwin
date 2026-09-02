import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goodwin/core/data/demo_data.dart';
import 'package:goodwin/models/category_model.dart';
import 'package:goodwin/models/product_model.dart';

class FirestoreProductRepository {
  FirestoreProductRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  final FirebaseFirestore? _customFirestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  Stream<List<CategoryModel>> streamCategories() {
    return _firestore.collection('categories').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => CategoryModel.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    });
  }

  Future<List<CategoryModel>> getCategories() async {
    try {
      final snapshot = await _firestore.collection('categories').get();
      return snapshot.docs
          .map((doc) => CategoryModel.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Stream<List<ProductModel>> streamProducts() {
    return _firestore
        .collection('products')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ProductModel.fromJson({'id': doc.id, ...doc.data()}))
          .where((p) => !p.isDeleted)
          .toList();
    });
  }

  Stream<List<ProductModel>> streamAllProductsForAdmin() {
    return _firestore.collection('products').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ProductModel.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    });
  }

  Future<List<ProductModel>> getProducts() async {
    try {
      final snapshot = await _firestore.collection('products').get();
      return snapshot.docs
          .map((doc) => ProductModel.fromJson({'id': doc.id, ...doc.data()}))
          .where((p) => !p.isDeleted && p.isActive)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<ProductModel?> getProduct(String id) async {
    try {
      final doc = await _firestore.collection('products').doc(id).get();
      if (!doc.exists) return null;
      return ProductModel.fromJson({'id': doc.id, ...doc.data()!});
    } catch (e) {
      return null;
    }
  }

  Future<void> addProduct(ProductModel product) async {
    final docRef = product.id.isNotEmpty
        ? _firestore.collection('products').doc(product.id)
        : _firestore.collection('products').doc();
    await docRef.set({
      ...product.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProduct(ProductModel product) async {
    await _firestore.collection('products').doc(product.id).update({
      ...product.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveProduct(ProductModel product) async {
    final docRef = product.id.isNotEmpty
        ? _firestore.collection('products').doc(product.id)
        : _firestore.collection('products').doc();
    await docRef.set({
      ...product.toJson(),
      'id': docRef.id,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Soft deletes a product by moving it to the Recycle Bin
  Future<void> moveToBin(String id) async {
    await _firestore.collection('products').doc(id).update({
      'isDeleted': true,
      'isActive': false,
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Restores a product from the Recycle Bin back to active catalog
  Future<void> restoreFromBin(String id) async {
    await _firestore.collection('products').doc(id).update({
      'isDeleted': false,
      'isActive': true,
      'deletedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Permanently deletes a product document from Firestore
  Future<void> permanentDeleteProduct(String id) async {
    await _firestore.collection('products').doc(id).delete();
  }

  Future<void> deleteProduct(String id) async {
    await moveToBin(id);
  }

  Future<void> updateStock(String id, int newStock) async {
    await _firestore.collection('products').doc(id).update({
      'availableQty': newStock,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitBulkInquiry({
    required String contactName,
    required String shopName,
    required String phone,
    required String categoryOrProduct,
    required String quantityRange,
    String notes = '',
    String? userId,
  }) async {
    final inquiryId = 'inq_${DateTime.now().millisecondsSinceEpoch}';
    await _firestore.collection('bulk_inquiries').doc(inquiryId).set({
      'id': inquiryId,
      'userId': userId ?? '',
      'contactName': contactName.trim(),
      'shopName': shopName.trim(),
      'phone': phone.trim(),
      'categoryOrProduct': categoryOrProduct.trim(),
      'quantityRange': quantityRange.trim(),
      'notes': notes.trim(),
      'status': 'pending',
      'unreadByAdmin': true,
      'unreadByUser': false,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessagePreview': 'New inquiry submitted',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // --- Admin: stream all inquiries ---
  Stream<List<Map<String, dynamic>>> streamAllBulkInquiries() {
    return _firestore
        .collection('bulk_inquiries')
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // --- Customer: stream their own inquiries (sorted client-side to avoid index) ---
  Stream<List<Map<String, dynamic>>> streamMyBulkInquiries(String userId) {
    return _firestore
        .collection('bulk_inquiries')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final docs = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      docs.sort((a, b) {
        final aTs = a['lastMessageAt'];
        final bTs = b['lastMessageAt'];
        if (aTs == null && bTs == null) return 0;
        if (aTs == null) return 1;
        if (bTs == null) return -1;
        // Timestamp comparison: newer first
        return (bTs as dynamic).compareTo(aTs as dynamic) as int;
      });
      return docs;
    });
  }

  // --- Stream messages sub-collection ---
  Stream<List<Map<String, dynamic>>> streamInquiryMessages(String inquiryId) {
    return _firestore
        .collection('bulk_inquiries')
        .doc(inquiryId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // --- Send a message (admin or customer) ---
  Future<void> sendInquiryMessage({
    required String inquiryId,
    required String senderId,
    required String senderName,
    required String text,
    required bool isAdmin,
  }) async {
    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final batch = _firestore.batch();

    // Write message doc
    final msgRef = _firestore
        .collection('bulk_inquiries')
        .doc(inquiryId)
        .collection('messages')
        .doc(msgId);
    batch.set(msgRef, {
      'id': msgId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text.trim(),
      'sentAt': FieldValue.serverTimestamp(),
    });

    // Update parent inquiry
    final inquiryRef = _firestore.collection('bulk_inquiries').doc(inquiryId);
    batch.update(inquiryRef, {
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessagePreview': text.trim().length > 60
          ? '${text.trim().substring(0, 60)}…'
          : text.trim(),
      'status': isAdmin ? 'replied' : 'pending',
      'unreadByAdmin': !isAdmin,
      'unreadByUser': isAdmin,
    });

    await batch.commit();
  }

  // --- Mark read by admin ---
  Future<void> markInquiryReadByAdmin(String inquiryId) async {
    await _firestore.collection('bulk_inquiries').doc(inquiryId).update({
      'unreadByAdmin': false,
    });
  }

  // --- Mark read by user ---
  Future<void> markInquiryReadByUser(String inquiryId) async {
    await _firestore.collection('bulk_inquiries').doc(inquiryId).update({
      'unreadByUser': false,
    });
  }

  // --- Update status ---
  Future<void> updateInquiryStatus(String inquiryId, String status) async {
    await _firestore.collection('bulk_inquiries').doc(inquiryId).update({
      'status': status,
    });
  }

  Future<void> seedDemoData() async {
    try {
      for (final cat in DemoData.categories) {
        await _firestore.collection('categories').doc(cat.id).set(cat.toJson());
      }
      for (final prod in DemoData.products) {
        await _firestore.collection('products').doc(prod.id).set(prod.toJson());
      }
    } catch (_) {}
  }

  Future<void> seedDemoDataIfNeeded() async {
    try {
      final snapshot = await _firestore.collection('products').limit(1).get();
      if (snapshot.docs.isNotEmpty) return;

      await seedDemoData();
    } catch (_) {}
  }
}
