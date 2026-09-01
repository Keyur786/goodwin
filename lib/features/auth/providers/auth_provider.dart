import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goodwin/core/services/demo_repository.dart';
import 'package:goodwin/models/user_model.dart';

class AuthController extends Notifier<AppUser?> {
  @override
  AppUser? build() {
    return appRepositoryProvider.getCurrentUser();
  }

  void loginAsCustomer() {
    state = appRepositoryProvider.getCurrentUser();
  }

  void loginAsAdmin() {
    state = AppUser(
      id: 'admin_1',
      name: 'Warehouse Admin',
      phone: '9999999999',
      email: 'admin@cheaperzone.com',
      shopName: 'Cheaper Zone',
      address: 'Katargam, Surat',
      city: 'Surat',
      gstNumber: '27ADMIN0000A1Z5',
      preferredPickupLocation: 'Katargam Branch',
      role: UserRole.superAdmin,
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  void logout() {
    state = null;
  }

  Future<void> signInWithPhone(String phoneNumber) async {
    // Firebase OTP flow will be implemented here
    // For now, just demo login
    loginAsCustomer();
  }
}

final authProvider = NotifierProvider<AuthController, AppUser?>(() => AuthController());
