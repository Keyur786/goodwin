import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  FirebaseFirestore get instance => _firestore;

  Future<void> setDocument({
    required String collection,
    required String id,
    required Map<String, dynamic> data,
    bool merge = true,
  }) async {
    await _firestore.collection(collection).doc(id).set(data, SetOptions(merge: merge));
  }

  Future<Map<String, dynamic>?> getDocument({
    required String collection,
    required String id,
  }) async {
    final doc = await _firestore.collection(collection).doc(id).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  Future<List<Map<String, dynamic>>> getCollection({
    required String collection,
  }) async {
    final snapshot = await _firestore.collection(collection).get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }
}
