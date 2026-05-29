// lib/pages/admin/force_update_all_stats.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForceUpdateAllStats extends StatefulWidget {
  const ForceUpdateAllStats({super.key});

  @override
  State<ForceUpdateAllStats> createState() => _ForceUpdateAllStatsState();
}

class _ForceUpdateAllStatsState extends State<ForceUpdateAllStats> {
  bool _isUpdating = false;
  String _status = '';
  int _updatedCount = 0;
  int _totalCount = 0;
  List<String> _errors = [];

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!userDoc.exists || userDoc.data()?['isAdmin'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('هذه الصفحة للمسؤولين فقط')),
          );
          Navigator.pop(context);
        }
      }
    }
  }

  Future<void> _updateAllUsers() async {
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

        setState(() {
          _status = 'جاري تحديث المستخدم ${i + 1} من $_totalCount...';
        });

        try {
          await _updateSingleUserStats(userId);
          _updatedCount++;
        } catch (e) {
          _errors.add('$userId: $e');
        }

        await Future.delayed(const Duration(milliseconds: 200));
      }

      setState(() {
        _status = '✅ تم تحديث $_updatedCount من $_totalCount مستخدم';
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
      setState(() => _status = '❌ خطأ: $e');
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _updateSingleUserStats(String userId) async {
    // جلب بيانات المستخدم
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    final userData = userDoc.data() ?? {};
    final companyIds = List<String>.from(userData['companyIds'] ?? []);
    final factoryIds = List<String>.from(userData['factoryIds'] ?? []);

    // 1. عدد الموردين
    int suppliersCount = 0;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('vendors')
          .where('userId', isEqualTo: userId)
          .get();
      suppliersCount = snapshot.docs.length;
    } catch (e) {
      // تجاهل الخطأ - المستخدم قد لا يملك صلاحية
    }

    // 2. عدد الطلبات المعلقة
    int ordersCount = 0;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('purchase_orders')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();
      ordersCount = snapshot.docs.length;
    } catch (e) {
      // تجاهل الخطأ - المستخدم قد لا يملك صلاحية
    }

    // 3. عدد المنتجات
    int itemsCount = 0;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('items')
          .where('userId', isEqualTo: userId)
          .get();
      itemsCount = snapshot.docs.length;
    } catch (e) {
      // تجاهل الخطأ - المستخدم قد لا يملك صلاحية
    }

    // 4. عدد أوامر التصنيع
    int manufacturingCount = 0;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('manufacturing_orders')
          .where('userId', isEqualTo: userId)
          .get();
      manufacturingCount = snapshot.docs.length;
    } catch (e) {
      // تجاهل الخطأ - المستخدم قد لا يملك صلاحية
    }

    // 5. إجمالي المبلغ
    double totalAmount = 0;
    try {
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('purchase_orders')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();
      for (var doc in ordersSnapshot.docs) {
        totalAmount +=
            (doc['totalAmountAfterTax'] ?? doc['totalAmount'] ?? 0).toDouble();
      }
    } catch (e) {
      // تجاهل الخطأ - المستخدم قد لا يملك صلاحية
    }

    // 6. عدد المنتجات التامة
    int finishedCount = 0;
    for (final companyId in companyIds) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('finished_products')
            .where('companyId', isEqualTo: companyId)
            .get();
        finishedCount += snapshot.docs.length;
      } catch (e) {
        // تجاهل الخطأ - الشركة قد لا تكون موجودة
      }
    }

    // 7. عدد حركات المخزون (لكل شركة)
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
        // تجاهل الخطأ - المستخدم قد لا يملك صلاحية لهذه الشركة
      }
    }

    // 8. عدد المصانع والشركات
    final factoriesCount = factoryIds.length;
    final companiesCount = companyIds.length;

    // ✅ حفظ الإحصائيات
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'stats': {
        'totalCompanies': companiesCount,
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
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
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
              'اضغط الزر أدناه لتحديث إحصائيات جميع المستخدمين في قاعدة البيانات.',
              textAlign: TextAlign.center,
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
            const SizedBox(height: 32),
            if (_isUpdating)
              const CircularProgressIndicator()
            else
              ElevatedButton.icon(
                onPressed: _updateAllUsers,
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
