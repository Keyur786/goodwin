import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:goodwin/core/data/demo_data.dart';
import 'package:goodwin/models/user_model.dart';

class FirestoreUserRepository {
  FirestoreUserRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  User? get currentFirebaseUser => _auth.currentUser;

  /// Generates a random 6-character uppercase alphabetic username (A-Z).
  static String generateRandomAlphabetCode([int length = 6]) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final rand = Random();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Generates a unique 6-alphabet username by querying Firestore to prevent duplicates.
  Future<String> generateUniqueUsername() async {
    for (int attempt = 0; attempt < 15; attempt++) {
      final candidate = generateRandomAlphabetCode(6);
      try {
        final query = await _firestore
            .collection('users')
            .where('username', isEqualTo: candidate)
            .limit(1)
            .get();
        if (query.docs.isEmpty) {
          return candidate;
        }
      } catch (_) {
        // If query fails (e.g. index/network in dev), return the generated candidate
        return candidate;
      }
    }
    // Fallback: 6-char random with millisecond salt
    return '${generateRandomAlphabetCode(4)}${DateTime.now().millisecond % 100}';
  }

  /// Checks if a username is available (not taken by another user).
  Future<bool> isUsernameAvailable(String username, {String? excludeUserId}) async {
    final cleanUsername = username.trim().toUpperCase();
    if (cleanUsername.isEmpty) return false;

    try {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: cleanUsername)
          .limit(2)
          .get();

      for (final doc in query.docs) {
        if (excludeUserId != null && doc.id == excludeUserId) {
          continue;
        }
        return false; // Taken by another user
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Stream user document updates in real time.
  Stream<AppUser?> streamUser(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromJson({'id': doc.id, ...doc.data()!});
    });
  }

  /// Check if a phone number belongs to the Goodwin Super Admin.
  static bool isSuperAdminPhone(String? phone) {
    if (phone == null) return false;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.endsWith('9904579700');
  }

  /// Gets existing user or creates a new user profile with a unique 6-alphabet username.
  Future<AppUser> getOrCreateUser(User firebaseUser) async {
    final phone = firebaseUser.phoneNumber ?? '';
    final isSpecialAdmin = isSuperAdminPhone(phone);
    final targetRole = isSpecialAdmin ? UserRole.superAdmin : UserRole.customer;

    try {
      final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      if (doc.exists && doc.data() != null) {
        final existing = AppUser.fromJson({'id': doc.id, ...doc.data()!});
        final shouldUpdateRole = isSpecialAdmin && existing.role != UserRole.superAdmin;
        final needsUsername = existing.username == null || existing.username!.isEmpty;

        if (needsUsername || shouldUpdateRole) {
          final uniqueUsername = existing.username?.isNotEmpty == true
              ? existing.username!
              : await generateUniqueUsername();
          final updatedData = <String, dynamic>{
            if (needsUsername) 'username': uniqueUsername,
            if (shouldUpdateRole) 'role': UserRole.superAdmin.name,
            if (existing.name.isEmpty)
              'name': isSpecialAdmin ? 'Goodwin Admin' : 'Reseller $uniqueUsername',
          };
          await updateUser(
            userId: firebaseUser.uid,
            data: updatedData,
          );
          return existing.copyWith(
            username: uniqueUsername,
            role: isSpecialAdmin ? UserRole.superAdmin : existing.role,
            name: existing.name.isEmpty
                ? (isSpecialAdmin ? 'Goodwin Admin' : 'Reseller $uniqueUsername')
                : existing.name,
          );
        }
        return existing;
      }

      // Create new user profile with a random unique 6-alphabet username
      final uniqueUsername = await generateUniqueUsername();
      final newUser = AppUser(
        id: firebaseUser.uid,
        name: isSpecialAdmin ? 'Goodwin Admin' : 'Reseller $uniqueUsername',
        phone: phone,
        username: uniqueUsername,
        role: targetRole,
        isActive: true,
        createdAt: DateTime.now(),
        favorites: const [],
        cart: const [],
      );

      await createUser(userId: firebaseUser.uid, user: newUser);
      return newUser;
    } catch (e) {
      // Fallback in-memory user if offline or uninitialized
      final fallbackUsername = generateRandomAlphabetCode(6);
      return AppUser(
        id: firebaseUser.uid,
        name: isSpecialAdmin ? 'Goodwin Admin' : 'Reseller $fallbackUsername',
        phone: phone,
        username: fallbackUsername,
        role: targetRole,
        isActive: true,
        createdAt: DateTime.now(),
      );
    }
  }

  Future<AppUser?> getCurrentUser() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return null;

      return await getOrCreateUser(firebaseUser);
    } catch (e) {
      return null;
    }
  }

  Future<AppUser?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromJson({'id': doc.id, ...doc.data()!});
    } catch (e) {
      return null;
    }
  }

  /// Lookup an existing user by their 10-digit or formatted phone number.
  Future<AppUser?> getUserByPhone(String phone) async {
    final rawDigits = phone.replaceAll(RegExp(r'\D'), '');
    if (rawDigits.isEmpty) return null;

    try {
      final formattedCandidates = [phone, '+91$rawDigits', rawDigits];
      final snapshot = await _firestore
          .collection('users')
          .where('phone', whereIn: formattedCandidates)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return AppUser.fromJson({'id': doc.id, ...doc.data()});
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Checks if a user already exists in Firestore and has completed their profile setup.
  Future<bool> isUserAlreadyPresent({
    required String userId,
    String? phone,
  }) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final name = data['name']?.toString().trim() ?? '';
        final isComplete = data['isProfileComplete'] == true;
        if (isComplete || (name.isNotEmpty && !name.startsWith('Reseller '))) {
          return true;
        }
      }

      if (phone != null && phone.trim().isNotEmpty) {
        final existing = await getUserByPhone(phone.trim());
        if (existing != null &&
            (existing.isProfileComplete ||
                (existing.name.isNotEmpty &&
                    !existing.name.startsWith('Reseller ')))) {
          return true;
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<List<AppUser>> getCustomers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: UserRole.customer.name)
          .get();
      return snapshot.docs
          .map((doc) => AppUser.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      return DemoData.customers;
    }
  }

  Future<void> createUser({
    required String userId,
    required AppUser user,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).set(user.toJson());
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateUser({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  /// Syncs the user's cart to Firestore so it persists across sessions.
  Future<void> syncCart(String userId, List<Map<String, dynamic>> cartItems) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'cart': cartItems,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Ignored for offline tolerance
    }
  }

  /// Syncs the user's favorites list to Firestore so it persists across sessions.
  Future<void> syncFavorites(String userId, List<String> favoriteIds) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'favorites': favoriteIds,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Ignored for offline tolerance
    }
  }

  /// Increments the customer's total purchases amount in Firestore to advance their tier.
  Future<void> recordPurchase(String userId, double amount) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'totalPurchases': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Ignored for offline tolerance
    }
  }

  /// Recalculates total lifetime purchases from the customer's orders in Firestore.
  Future<double> recalculateUserPurchasesFromOrders(String userId) async {
    try {
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('customerId', isEqualTo: userId)
          .get();

      double total = 0.0;
      for (final doc in ordersSnapshot.docs) {
        final data = doc.data();
        final status = data['orderStatus']?.toString().toLowerCase();
        if (status != 'cancelled') {
          total += (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        }
      }

      await _firestore.collection('users').doc(userId).set({
        'totalPurchases': total,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return total;
    } catch (_) {
      return 0.0;
    }
  }

  Future<void> seedDemoCustomers() async {
    try {
      for (final customer in DemoData.customers) {
        await _firestore.collection('users').doc(customer.id).set(customer.toJson());
      }
    } catch (_) {
      // Logging can be added here
    }
  }
}
