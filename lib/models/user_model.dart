enum UserRole { customer, manager, warehouseStaff, staff, superAdmin }

enum CustomerTier {
  silver,
  gold,
  diamond;

  String get displayName {
    switch (this) {
      case CustomerTier.diamond:
        return 'Diamond';
      case CustomerTier.gold:
        return 'Gold';
      case CustomerTier.silver:
        return 'Silver';
    }
  }

  String get emoji {
    switch (this) {
      case CustomerTier.diamond:
        return '💎';
      case CustomerTier.gold:
        return '🥇';
      case CustomerTier.silver:
        return '🥈';
    }
  }

  static CustomerTier fromSpend(double totalSpent) {
    if (totalSpent >= 200000) {
      return CustomerTier.diamond;
    } else if (totalSpent >= 50000) {
      return CustomerTier.gold;
    } else {
      return CustomerTier.silver;
    }
  }

  static CustomerTier fromString(String? val) {
    if (val == null) return CustomerTier.silver;
    final lower = val.toLowerCase();
    if (lower.contains('diamond')) return CustomerTier.diamond;
    if (lower.contains('gold')) return CustomerTier.gold;
    return CustomerTier.silver;
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.phone,
    this.username,
    this.email,
    this.photoUrl,
    this.shopName,
    this.address,
    this.city,
    this.gstNumber,
    this.preferredPickupLocation,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.isProfileComplete = false,
    this.totalPurchases = 0.0,
    this.favorites = const [],
    this.cart = const [],
    this.notifications = const [],
  });

  final String id;
  final String name;
  final String phone;
  final String? username;
  final String? email;
  final String? photoUrl;
  final String? shopName;
  final String? address;
  final String? city;
  final String? gstNumber;
  final String? preferredPickupLocation;
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;
  final bool isProfileComplete;
  final double totalPurchases;
  final List<String> favorites;
  final List<Map<String, dynamic>> cart;
  final List<Map<String, dynamic>> notifications;

  CustomerTier get tier => CustomerTier.fromSpend(totalPurchases);

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      username: json['username'] as String?,
      email: json['email'] as String?,
      photoUrl: json['photoUrl'] as String?,
      shopName: json['shopName'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      gstNumber: json['gstNumber'] as String?,
      preferredPickupLocation: json['preferredPickupLocation'] as String?,
      role: UserRole.values.firstWhere(
        (value) => value.name == (json['role'] ?? 'customer'),
        orElse: () => UserRole.customer,
      ),
      isActive: json['isActive'] as bool? ?? true,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      isProfileComplete: json['isProfileComplete'] as bool? ??
          (json['name'] != null &&
              json['name'].toString().trim().isNotEmpty &&
              !json['name'].toString().startsWith('Reseller ')),
      totalPurchases: (json['totalPurchases'] as num?)?.toDouble() ?? 0.0,
      favorites: (json['favorites'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      cart: (json['cart'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      notifications: (json['notifications'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      if (username != null) 'username': username,
      if (email != null) 'email': email,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'shopName': shopName,
      'address': address,
      'city': city,
      'gstNumber': gstNumber,
      'preferredPickupLocation': preferredPickupLocation,
      'role': role.name,
      'isActive': isActive,
      'isProfileComplete': isProfileComplete,
      'createdAt': createdAt.toIso8601String(),
      'totalPurchases': totalPurchases,
      'favorites': favorites,
      'cart': cart,
      'notifications': notifications,
    };
  }

  AppUser copyWith({
    String? id,
    String? name,
    String? phone,
    String? username,
    String? email,
    String? photoUrl,
    String? shopName,
    String? address,
    String? city,
    String? gstNumber,
    String? preferredPickupLocation,
    UserRole? role,
    bool? isActive,
    bool? isProfileComplete,
    DateTime? createdAt,
    double? totalPurchases,
    List<String>? favorites,
    List<Map<String, dynamic>>? cart,
    List<Map<String, dynamic>>? notifications,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      username: username ?? this.username,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      shopName: shopName ?? this.shopName,
      address: address ?? this.address,
      city: city ?? this.city,
      gstNumber: gstNumber ?? this.gstNumber,
      preferredPickupLocation:
          preferredPickupLocation ?? this.preferredPickupLocation,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      createdAt: createdAt ?? this.createdAt,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      favorites: favorites ?? this.favorites,
      cart: cart ?? this.cart,
      notifications: notifications ?? this.notifications,
    );
  }
}
