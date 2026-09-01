import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:goodwin/core/services/firestore_user_repository.dart';

class FavoritesController extends ChangeNotifier {
  static final FavoritesController instance = FavoritesController();

  final FirestoreUserRepository? _userRepository;
  final Set<String> _favoriteIds = {};
  Timer? _debounceTimer;
  String? _currentUserId;

  FavoritesController({FirestoreUserRepository? repository})
      : _userRepository = repository;

  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);

  bool isFavorite(String productId) => _favoriteIds.contains(productId);

  void setCurrentUser(String? userId) {
    _currentUserId = userId;
  }

  void toggleFavorite(String productId, {String? userId}) {
    if (userId != null) _currentUserId = userId;

    if (_favoriteIds.contains(productId)) {
      _favoriteIds.remove(productId);
    } else {
      _favoriteIds.add(productId);
    }

    notifyListeners();
    _scheduleSync();
  }

  void syncFromUserData(List<String> savedFavorites, {String? userId}) {
    if (userId != null) _currentUserId = userId;
    _favoriteIds.clear();
    _favoriteIds.addAll(savedFavorites);
    notifyListeners();
  }

  void _scheduleSync() {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      try {
        final repo = _userRepository ?? FirestoreUserRepository();
        unawaited(repo.syncFavorites(uid, _favoriteIds.toList()));
      } catch (_) {
        // Tolerant of uninitialized unit test environments
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
