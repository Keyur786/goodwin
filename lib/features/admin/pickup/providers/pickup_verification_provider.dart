import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goodwin/core/services/demo_repository.dart';
import 'package:goodwin/models/order_model.dart';

class PickupVerificationState {
  const PickupVerificationState({
    this.scannedPickupCode,
    this.order,
    this.isLoading = false,
    this.error,
    this.isPickedUp = false,
  });

  final String? scannedPickupCode;
  final OrderModel? order;
  final bool isLoading;
  final String? error;
  final bool isPickedUp;

  PickupVerificationState copyWith({
    String? scannedPickupCode,
    OrderModel? order,
    bool? isLoading,
    String? error,
    bool? isPickedUp,
  }) {
    return PickupVerificationState(
      scannedPickupCode: scannedPickupCode ?? this.scannedPickupCode,
      order: order ?? this.order,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isPickedUp: isPickedUp ?? this.isPickedUp,
    );
  }
}

class PickupVerificationNotifier extends Notifier<PickupVerificationState> {
  @override
  PickupVerificationState build() {
    return const PickupVerificationState();
  }

  Future<void> verifyPickupCode(String pickupCode, String warehouseId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final orderRepository = ref.read(firestoreOrderRepositoryProvider);
      
      // Search for order with matching pickup code
      final orders = await orderRepository.getReadyForPickup(warehouseId);
      final matchingOrder = orders.firstWhere(
        (order) => order.pickupCode == pickupCode,
        orElse: () => throw Exception('Pickup code not found'),
      );

      state = state.copyWith(
        scannedPickupCode: pickupCode,
        order: matchingOrder,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> confirmPickup({
    required String orderId,
    required String pickupCode,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final orderRepository = ref.read(firestoreOrderRepositoryProvider);
      await orderRepository.markOrderAsPickedUp(
        orderId: orderId,
        pickedUpAt: DateTime.now(),
      );

      state = state.copyWith(
        isLoading: false,
        isPickedUp: true,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> recordPayment({
    required String orderId,
    required double amount,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final orderRepository = ref.read(firestoreOrderRepositoryProvider);
      await orderRepository.recordPayment(
        orderId: orderId,
        amount: amount,
        status: PaymentStatus.paid,
      );

      state = state.copyWith(
        isLoading: false,
        isPickedUp: true,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  void reset() {
    state = const PickupVerificationState();
  }
}

final pickupVerificationProvider =
    NotifierProvider<PickupVerificationNotifier, PickupVerificationState>(
  () => PickupVerificationNotifier(),
);
