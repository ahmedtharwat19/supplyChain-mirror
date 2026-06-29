// pages/admin/update_all_users_stats_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class UpdateAllUsersStatsPage extends StatefulWidget {
  const UpdateAllUsersStatsPage({super.key});

  @override
  State<UpdateAllUsersStatsPage> createState() =>
      _UpdateAllUsersStatsPageState();
}

class _UpdateAllUsersStatsPageState extends State<UpdateAllUsersStatsPage> {
  bool _isUpdating = false;
  String _status = '';
  int _updatedCount = 0;
  int _totalCount = 0;
  List<String> _errors = [];
  bool _isAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAdminAndLoad();
  }

  Future<void> _checkAdminAndLoad() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      _isAdmin = userDoc.data()?['isAdmin'] == true;

      if (!_isAdmin) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('هذه الصفحة للمسؤولين فقط')),
          );
          context.go('/dashboard');
        }
        return;
      }
    } catch (e) {
      safeDebugPrint('Error checking admin: $e');
      if (mounted) {
        context.go('/dashboard');
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateAllUsersStats() async {
    setState(() {
      _isUpdating = true;
      _status = 'جاري جلب المستخدمين...';
      _errors = [];
    });

    try {
      final users = await FirebaseFirestore.instance.collection('users').get();
      _totalCount = users.docs.length;
      _updatedCount = 0;

      for (int i = 0; i < users.docs.length; i++) {
        final user = users.docs[i];
        final userId = user.id;
        final userEmail = user.data()['email'] ?? userId;

        setState(() {
          _status =
              'جاري تحديث ${userEmail.length > 20 ? userEmail.substring(0, 20) : userEmail}... (${i + 1}/$_totalCount)';
        });

        try {
          await _updateSingleUserStats(userId);
          _updatedCount++;
        } catch (e) {
          _errors.add('$userEmail: $e');
        }

        await Future.delayed(const Duration(milliseconds: 300));
      }

      setState(() {
        _status = '✅ تم تحديث $_updatedCount من $_totalCount مستخدم بنجاح';
        if (_errors.isNotEmpty) {
          _status += '\n⚠️ فشل: ${_errors.length} مستخدم';
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث $_updatedCount مستخدم'),
            backgroundColor: _errors.isEmpty ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _status = '❌ خطأ: $e';
      });
    } finally {
      setState(() => _isUpdating = false);
    }
  }

// pages/admin/update_all_users_stats_page.dart - استبدل الدالة بالكامل

Future<void> _updateSingleUserStats(String userId) async {
  try {
    safeDebugPrint('📊 Starting update for user: $userId');
    
    // جلب بيانات المستخدم
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    
    final userData = userDoc.data() ?? {};
    final companyIds = List<String>.from(userData['companyIds'] ?? []);
    final factoryIds = List<String>.from(userData['factoryIds'] ?? []);
    
    safeDebugPrint('📊 User $userId: Companies=${companyIds.length}, Factories=${factoryIds.length}');
    
    // ✅ 1. عدد الموردين
    int suppliersCount = 0;
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('vendors')
          .where('userId', isEqualTo: userId)
          .get();
      suppliersCount = querySnapshot.docs.length;
      safeDebugPrint('📊 Suppliers: $suppliersCount');
    } catch (e) {
      safeDebugPrint('⚠️ Error counting suppliers: $e');
    }
    
    // ✅ 2. عدد الطلبات المعلقة
    int ordersCount = 0;
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('purchase_orders')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();
      ordersCount = querySnapshot.docs.length;
      safeDebugPrint('📊 Pending Orders: $ordersCount');
    } catch (e) {
      safeDebugPrint('⚠️ Error counting orders: $e');
    }
    
    // ✅ 3. عدد المنتجات
    int itemsCount = 0;
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('items')
          .where('userId', isEqualTo: userId)
          .get();
      itemsCount = querySnapshot.docs.length;
      safeDebugPrint('📊 Items: $itemsCount');
    } catch (e) {
      safeDebugPrint('⚠️ Error counting items: $e');
    }
    
    // ✅ 4. عدد أوامر التصنيع
    int manufacturingCount = 0;
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('manufacturing_orders')
          .where('userId', isEqualTo: userId)
          .get();
      manufacturingCount = querySnapshot.docs.length;
      safeDebugPrint('📊 Manufacturing Orders: $manufacturingCount');
    } catch (e) {
      safeDebugPrint('⚠️ Error counting manufacturing orders: $e');
    }
    
    // ✅ 5. إجمالي المبلغ للطلبات المعلقة
    double totalAmount = 0;
    try {
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('purchase_orders')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      for (var doc in ordersSnapshot.docs) {
        totalAmount += (doc['totalAmountAfterTax'] ?? doc['totalAmount'] ?? 0).toDouble();
      }
      safeDebugPrint('📊 Total Amount: $totalAmount');
    } catch (e) {
      safeDebugPrint('⚠️ Error calculating total amount: $e');
    }
    
    // ✅ 6. عدد المنتجات التامة
    int finishedCount = 0;
    for (final companyId in companyIds) {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('finished_products')
            .where('companyId', isEqualTo: companyId)
            .get();
        finishedCount += querySnapshot.docs.length;
      } catch (e) {
        safeDebugPrint('⚠️ Error counting finished products for company $companyId: $e');
      }
    }
    safeDebugPrint('📊 Finished Products: $finishedCount');
    
    // ✅ 7. عدد حركات المخزون
    int stockMovementsCount = 0;
    for (final companyId in companyIds) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('stock_movements')
            .where('userId', isEqualTo: userId)
            .get();
        stockMovementsCount += snapshot.docs.length;
      } catch (e) {
        safeDebugPrint('⚠️ Error counting stock movements for company $companyId: $e');
      }
    }
    safeDebugPrint('📊 Stock Movements: $stockMovementsCount');
    
    // ✅ 8. عدد المصانع
    final factoriesCount = factoryIds.length;
    
    // ✅ حفظ الإحصائيات في Firestore
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'stats': {
        'totalSuppliers': suppliersCount,
        'totalOrders': ordersCount,
        'totalItems': itemsCount,
        'totalManufacturingOrders': manufacturingCount,
        'totalAmount': totalAmount,
        'totalFactories': factoriesCount,
        'totalFinishedProducts': finishedCount,
        'totalStockMovements': stockMovementsCount,
        'lastUpdated': FieldValue.serverTimestamp(),
      }
    });
    
    safeDebugPrint('✅ Successfully updated stats for user: $userId');
    
  } catch (e) {
    safeDebugPrint('❌ Failed to update user $userId: $e');
    rethrow;
  }
}

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return const SizedBox.shrink(); // لن يظهر لأنه سيعيد التوجيه
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('تحديث إحصائيات جميع المستخدمين'),
        backgroundColor: Colors.red,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_alt, size: 64, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'تحديث إحصائيات جميع المستخدمين',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              '⚠️ هذه الصفحة مخصصة للمسؤولين فقط ⚠️',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 8),
            const Text(
              'هذه العملية ستقوم بحساب وتحديث إحصائيات جميع المستخدمين في قاعدة البيانات.\nقد تستغرق بعض الوقت حسب عدد المستخدمين.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 32),
            if (_status.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_status, textAlign: TextAlign.center),
              ),
            if (_totalCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'التقدم: $_updatedCount / $_totalCount',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            if (_errors.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  '⚠️ فشل تحديث ${_errors.length} مستخدم',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 32),
            if (_isUpdating)
              const CircularProgressIndicator()
            else
              ElevatedButton.icon(
                onPressed: _updateAllUsersStats,
                icon: const Icon(Icons.play_arrow),
                label: const Text('بدء التحديث'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
