import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goodwin/core/data/demo_data.dart';
import 'package:goodwin/core/services/firestore_order_repository.dart';
import 'package:goodwin/core/services/firestore_product_repository.dart';
import 'package:goodwin/core/services/firestore_user_repository.dart';
import 'package:goodwin/models/category_model.dart';
import 'package:goodwin/models/order_model.dart';
import 'package:goodwin/models/product_model.dart';
import 'package:goodwin/models/user_model.dart';

abstract class AppRepository {
  List<CategoryModel> getCategories();
  List<ProductModel> getProducts();
  List<AppUser> getCustomers();
  List<OrderModel> getOrders();
  AppUser? getCurrentUser();
}

class DemoAppRepository implements AppRepository {
  @override
  List<CategoryModel> getCategories() => DemoData.categories;

  @override
  List<ProductModel> getProducts() => DemoData.products;

  @override
  List<AppUser> getCustomers() => DemoData.customers;

  @override
  List<OrderModel> getOrders() => DemoData.orders;

  @override
  AppUser? getCurrentUser() => DemoData.customers.first;
}

final appRepositoryProvider = DemoAppRepository();

// Firestore repositories
final firestoreProductRepositoryProvider =
    Provider((ref) => FirestoreProductRepository());

final firestoreUserRepositoryProvider =
    Provider((ref) => FirestoreUserRepository());

final firestoreOrderRepositoryProvider =
    Provider((ref) => FirestoreOrderRepository());
