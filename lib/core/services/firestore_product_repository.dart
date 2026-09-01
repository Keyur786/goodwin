import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goodwin/core/data/demo_data.dart';
import 'package:goodwin/models/category_model.dart';
import 'package:goodwin/models/product_model.dart';

class FirestoreProductRepository {
  FirestoreProductRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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

  Future<void> deleteProduct(String id) async {
    await _firestore.collection('products').doc(id).delete();
  }

  Future<void> updateStock(String id, int newStock) async {
    await _firestore.collection('products').doc(id).update({
      'availableQty': newStock,
      'updatedAt': FieldValue.serverTimestamp(),
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
