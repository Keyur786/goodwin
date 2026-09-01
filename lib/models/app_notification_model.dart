enum NotificationType {
  lowStock,
  orderStatus,
  general,
}

class AppNotificationModel {
  final String id;
  final String title;
  final String message;
  final String productId;
  final String productName;
  final String productImage;
  final int stockQuantity;
  final NotificationType type;
  final DateTime createdAt;
  bool isRead;

  AppNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.stockQuantity,
    this.type = NotificationType.lowStock,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'stockQuantity': stockQuantity,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory AppNotificationModel.fromMap(Map<String, dynamic> map) {
    return AppNotificationModel(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      productImage: map['productImage'] as String? ?? '',
      stockQuantity: (map['stockQuantity'] as num?)?.toInt() ?? 0,
      type: NotificationType.values.firstWhere(
        (t) => t.name == (map['type'] as String? ?? ''),
        orElse: () => NotificationType.lowStock,
      ),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isRead: map['isRead'] as bool? ?? false,
    );
  }
}
