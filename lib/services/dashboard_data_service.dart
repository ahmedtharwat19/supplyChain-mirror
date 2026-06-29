// dashboard_data_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardStats {
  final int totalCompanies;
  final int totalSuppliers;
  final int totalOrders;
  final double totalAmount;
  final int totalItems;
  final int totalStockMovements;
  final int totalManufacturingOrders;
  final int totalFinishedProducts;
  final int totalFactories;

  DashboardStats({
    required this.totalCompanies,
    required this.totalSuppliers,
    required this.totalOrders,
    required this.totalAmount,
    required this.totalItems,
    required this.totalStockMovements,
    required this.totalManufacturingOrders,
    required this.totalFinishedProducts,
    required this.totalFactories,
  });
}

class DashboardDataService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DashboardDataService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Future<DashboardStats?> fetchDashboardStats(List<String> userCompanyIds) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      // Fetch general counts
      final results = await Future.wait([
        _fetchCollectionCount('items', user.uid),
        _fetchCollectionCount('vendors', user.uid),
      ]);

      int totalItems = results[0];
      int totalSuppliers = results[1];

      // If user has companies, fetch additional data
      int totalOrders = 0;
      double totalAmount = 0.0;
      int totalMovements = 0;
      int totalManufacturingOrders = 0;
      int totalFinishedProducts = 0;
      int totalFactories = 0;

      if (userCompanyIds.isNotEmpty) {
        final additional = await _fetchAdditionalData(userCompanyIds, user.uid);
        totalOrders = additional['totalOrders'] ?? 0;
        totalAmount = additional['totalAmount'] ?? 0.0;
        totalMovements = additional['totalMovements'] ?? 0;
        totalManufacturingOrders = additional['totalManufacturingOrders'] ?? 0;
        totalFinishedProducts = additional['totalFinishedProducts'] ?? 0;
        totalFactories = additional['totalFactories'] ?? 0;
      }

      return DashboardStats(
        totalCompanies: userCompanyIds.length,
        totalSuppliers: totalSuppliers,
        totalOrders: totalOrders,
        totalAmount: totalAmount,
        totalItems: totalItems,
        totalStockMovements: totalMovements,
        totalManufacturingOrders: totalManufacturingOrders,
        totalFinishedProducts: totalFinishedProducts,
        totalFactories: totalFactories,
      );
    } catch (e) {
      // Log error or rethrow if needed
      return null;
    }
  }

  Future<int> _fetchCollectionCount(String collection, String userId) async {
    try {
      final snapshot = await _firestore
          .collection(collection)
          .where('userId', isEqualTo: userId)
          .get();
      return snapshot.size;
    } catch (e) {
      return 0;
    }
  }

  Future<Map<String, dynamic>> _fetchAdditionalData(
      List<String> companyIds, String userId) async {
    int totalOrders = 0;
    double totalAmount = 0.0;
    int totalMovements = 0;
    int totalManufacturingOrders = 0;
    int totalFinishedProducts = 0;
    int totalFactories = 0;

    final futures = companyIds.map((companyId) => _getCompanyStats(companyId, userId));
    final results = await Future.wait(futures);

    for (var result in results) {
      totalOrders += result['orders'] as int;
      totalAmount += result['amount'] as double;
      totalMovements += result['movements'] as int;
      totalManufacturingOrders += result['manufacturing'] as int;
      totalFinishedProducts += result['finishedProducts'] as int;
      totalFactories += result['factories'] as int;
    }

    return {
      'totalOrders': totalOrders,
      'totalAmount': totalAmount,
      'totalMovements': totalMovements,
      'totalManufacturingOrders': totalManufacturingOrders,
      'totalFinishedProducts': totalFinishedProducts,
      'totalFactories': totalFactories,
    };
  }

  Future<Map<String, dynamic>> _getCompanyStats(String companyId, String userId) async {
    final results = await Future.wait([
      _getSubCollectionCount('purchase_orders', companyId, userId),
      _getSubCollectionCount('stock_movements', companyId, userId),
      _getSubCollectionCount('manufacturing_orders', companyId, userId),
      _getSubCollectionCount('finished_products', companyId, userId),
      _getSubCollectionCount('factories', companyId, userId),
    ]);

    return {
      'orders': results[0]['count'],
      'amount': results[0]['amount'],
      'movements': results[1]['count'],
      'manufacturing': results[2]['count'],
      'finishedProducts': results[3]['count'],
      'factories': results[4]['count'],
    };
  }

  Future<Map<String, dynamic>> _getSubCollectionCount(
      String collection, String companyId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('companies/$companyId/$collection')
          .where('userId', isEqualTo: userId)
          .get();

      double amount = 0.0;
      if (collection == 'purchase_orders') {
        amount = snapshot.docs.fold(0.0, (total, doc) {
          final val = doc.data()['totalAmount'];
          return total + ((val is num) ? val.toDouble() : 0.0);
        });
      }

      return {'count': snapshot.size, 'amount': amount};
    } catch (e) {
      return {'count': 0, 'amount': 0.0};
    }
  }
}
