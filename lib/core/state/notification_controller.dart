import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:goodwin/models/app_notification_model.dart';
import 'package:goodwin/models/demo_product.dart';
import 'package:uuid/uuid.dart';

class NotificationController extends ChangeNotifier {
  static final NotificationController _instance =
      NotificationController._internal();
  factory NotificationController() => _instance;
  NotificationController._internal();

  final List<AppNotificationModel> _notifications = [];
  final Set<String> _alertedStockKeys = {};
  String? _currentUserId;
  final _uuid = const Uuid();

  List<AppNotificationModel> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void setUserId(String? userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
    }
  }

  void syncFromUserData(List<dynamic>? rawNotifications) {
    if (rawNotifications == null) return;
    _notifications.clear();
    for (final item in rawNotifications) {
      if (item is Map<String, dynamic>) {
        _notifications.add(AppNotificationModel.fromMap(item));
      } else if (item is Map) {
        _notifications.add(
          AppNotificationModel.fromMap(Map<String, dynamic>.from(item)),
        );
      }
    }
    notifyListeners();
  }

  /// Checks if any favorited product has dropped below 100 units in stock.
  /// Triggers an alert if not already notified for the current stock count.
  List<AppNotificationModel> checkFavoriteStockAlerts({
    required List<DemoProduct> products,
    required Set<String> favoriteIds,
    Function(AppNotificationModel)? onNewAlert,
  }) {
    final List<AppNotificationModel> newAlerts = [];

    for (final product in products) {
      if (!favoriteIds.contains(product.id)) continue;

      // Threshold: quantity drops below 100 but is still in stock (> 0)
      if (product.availableQty > 0 && product.availableQty < 100) {
        // Create unique key for product and stock count to prevent duplicate spam
        final alertKey = '${product.id}_${product.availableQty}';

        // Check if we have an existing notification for this product
        final alreadyNotified = _alertedStockKeys.contains(alertKey) ||
            _notifications.any(
              (n) =>
                  n.productId == product.id &&
                  n.stockQuantity == product.availableQty,
            );

        if (!alreadyNotified) {
          _alertedStockKeys.add(alertKey);

          final notification = AppNotificationModel(
            id: _uuid.v4(),
            title: 'Low Stock Alert: ${product.name}',
            message:
                'Only ${product.availableQty} units left in stock for ${product.name} from your favorites! Order before it runs out.',
            productId: product.id,
            productName: product.name,
            productImage: product.image,
            stockQuantity: product.availableQty,
            type: NotificationType.lowStock,
            createdAt: DateTime.now(),
            isRead: false,
          );

          _notifications.insert(0, notification);
          newAlerts.add(notification);
          onNewAlert?.call(notification);
        }
      } else if (product.availableQty >= 100) {
        // Reset alerted key if restocked
        _alertedStockKeys.removeWhere((k) => k.startsWith('${product.id}_'));
      }
    }

    if (newAlerts.isNotEmpty) {
      notifyListeners();
      _saveToFirestore();
    }

    return newAlerts;
  }

  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index >= 0 && !_notifications[index].isRead) {
      _notifications[index].isRead = true;
      notifyListeners();
      _saveToFirestore();
    }
  }

  void markAllAsRead() {
    bool hasUnread = false;
    for (final n in _notifications) {
      if (!n.isRead) {
        n.isRead = true;
        hasUnread = true;
      }
    }
    if (hasUnread) {
      notifyListeners();
      _saveToFirestore();
    }
  }

  void removeNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    notifyListeners();
    _saveToFirestore();
  }

  void clearAll() {
    _notifications.clear();
    _alertedStockKeys.clear();
    notifyListeners();
    _saveToFirestore();
  }

  Future<void> _saveToFirestore() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    try {
      final data = _notifications.map((n) => n.toMap()).toList();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .set({'notifications': data}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error syncing notifications to Firestore: $e');
    }
  }
}
