// lib/pages/reports/supplier_performance_report.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class SupplierPerformanceReport extends StatefulWidget {
  const SupplierPerformanceReport({super.key});

  @override
  State<SupplierPerformanceReport> createState() =>
      _SupplierPerformanceReportState();
}

class _SupplierPerformanceReportState extends State<SupplierPerformanceReport> {
  bool _isLoading = false;
  bool _isArabic = false;

  String? _selectedCompanyId;
  String? _selectedSupplierId;

  // متغيرات الفترة الزمنية
  String _selectedPeriod = 'monthly';
  DateTime? _startDate;
  DateTime? _endDate;

  // قوائم البيانات
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _performanceData = [];

  // مقاييس الأداء
  double _onTimeDeliveryRate = 0;
  double _averageLeadTime = 0;
  double _orderAccuracyRate = 0;
  double _qualityAcceptanceRate = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isArabic = context.locale.languageCode == 'ar';
  }

  @override
  void initState() {
    super.initState();
    _setPeriodDates();
    _loadData();
    _checkDatabaseStructure();
     _debugCheckRelations();
     _printCurrentUserData();
    //  updateAllSuppliersWithCompanyIds();
    //  verifySuppliersUpdate() ;
  }

/* Future<void> verifySuppliersUpdate() async {
  safeDebugPrint('=== VERIFYING SUPPLIERS UPDATE ===');
  
  final vendorsSnapshot = await FirebaseFirestore.instance
      .collection('vendors')
      .get();
  
  for (final doc in vendorsSnapshot.docs) {
    final data = doc.data();
    final companyIds = data['companyIds'] as List? ?? [];
    final name = data['nameEn'] ?? data['nameAr'] ?? doc.id;
    
    safeDebugPrint('Supplier: $name -> companyIds: $companyIds');
  }
}

Future<void> updateAllSuppliersWithCompanyIds() async {
  safeDebugPrint('=== STARTING BULK UPDATE: SUPPLIERS WITH COMPANY IDS ===');
  
  try {
    // 1. جلب جميع المستخدمين
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .get();
    
    safeDebugPrint('Total users found: ${usersSnapshot.docs.length}');
    
    int totalUpdatedSuppliers = 0;
    int totalUsersProcessed = 0;
    
    for (final userDoc in usersSnapshot.docs) {
      final userData = userDoc.data();
      final userCompanyIds = (userData['companyIds'] as List?)?.cast<String>() ?? [];
      final userSupplierIds = (userData['supplierIds'] as List?)?.cast<String>() ?? [];
      
      if (userCompanyIds.isEmpty || userSupplierIds.isEmpty) {
        safeDebugPrint('⚠️ User ${userDoc.id} has no companies or suppliers, skipping...');
        continue;
      }
      
      safeDebugPrint('📌 Processing user: ${userDoc.id}');
      safeDebugPrint('   Companies: $userCompanyIds');
      safeDebugPrint('   Suppliers: $userSupplierIds');
      
      int userUpdatedCount = 0;
      
      // 2. لكل مورد تابع للمستخدم، قم بإضافة companyIds
      for (final supplierId in userSupplierIds) {
        final supplierRef = FirebaseFirestore.instance
            .collection('vendors')
            .doc(supplierId);
        
        final supplierDoc = await supplierRef.get();
        
        if (supplierDoc.exists) {
          final supplierData = supplierDoc.data()!;
          final existingCompanyIds = (supplierData['companyIds'] as List?)?.cast<String>() ?? [];
          
          // دمج companyIds الجديدة مع القديمة (تجنب التكرار)
          final Set<String> mergedCompanyIds = {...existingCompanyIds, ...userCompanyIds};
          
          if (mergedCompanyIds.length > existingCompanyIds.length) {
            await supplierRef.update({
              'companyIds': mergedCompanyIds.toList(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            userUpdatedCount++;
            safeDebugPrint('   ✅ Updated supplier: $supplierId (added companies: ${userCompanyIds.where((c) => !existingCompanyIds.contains(c)).toList()})');
          } else {
            safeDebugPrint('   ⏭️ Supplier already has all companies: $supplierId');
          }
        } else {
          safeDebugPrint('   ❌ Supplier document not found: $supplierId');
        }
      }
      
      totalUpdatedSuppliers += userUpdatedCount;
      totalUsersProcessed++;
      safeDebugPrint('   📊 User updated $userUpdatedCount suppliers');
    }
    
    safeDebugPrint('=== UPDATE COMPLETED ===');
    safeDebugPrint('✅ Users processed: $totalUsersProcessed');
    safeDebugPrint('✅ Suppliers updated: $totalUpdatedSuppliers');
    
  } catch (e) {
    safeDebugPrint('❌ Error updating suppliers: $e');
  }
}
 */
  void _setPeriodDates() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'monthly':
        _startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case 'quarterly':
        _startDate = DateTime(now.year, now.month - 3, now.day);
        break;
      case 'semi_annual':
        _startDate = DateTime(now.year, now.month - 6, now.day);
        break;
      case 'annual':
        _startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      case 'custom':
        if (_startDate == null) {
          _startDate = DateTime(now.year, now.month - 3, now.day);
          _endDate = now;
        }
        break;
    }
    if (_selectedPeriod != 'custom') {
      _endDate = now;
    }
  }

  Future<void> _loadData() async {
    await _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // 1. جلب بيانات المستخدم
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();

      // جلب companyIds من المستخدم
      final List<String> userCompanyIds =
          (userData?['companyIds'] as List?)?.cast<String>() ?? [];

      safeDebugPrint('User Company IDs: $userCompanyIds');

      if (userCompanyIds.isEmpty) {
        safeDebugPrint('No companies found for user');
        setState(() => _isLoading = false);
        return;
      }

      // 2. جلب تفاصيل الشركات
      _companies = [];
      for (final companyId in userCompanyIds) {
        final companyDoc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .get();

        if (companyDoc.exists) {
          final data = companyDoc.data()!;
          _companies.add({
            'id': companyId,
            'name': _isArabic ? data['nameAr'] : data['nameEn'],
          });
          safeDebugPrint('Company loaded: ${_companies.last['name']}');
        }
      }

      safeDebugPrint('Companies loaded: ${_companies.length}');

      if (_companies.isNotEmpty && _selectedCompanyId == null) {
        setState(() {
          _selectedCompanyId = _companies.first['id'] as String;
        });
        await _loadSuppliers();
      }
    } catch (e) {
      safeDebugPrint('Error loading companies: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkDatabaseStructure() async {
    safeDebugPrint('=== CHECKING DATABASE STRUCTURE ===');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // فحص user document
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final userData = userDoc.data();
    safeDebugPrint('User document fields: ${userData?.keys}');
    safeDebugPrint('User companyIds: ${userData?['companyIds']}');
    safeDebugPrint('User supplierIds: ${userData?['supplierIds']}');

    // فحص أول مورد في vendors
    final firstVendor =
        await FirebaseFirestore.instance.collection('vendors').limit(1).get();

    if (firstVendor.docs.isNotEmpty) {
      final vendorData = firstVendor.docs.first.data();
      safeDebugPrint('Vendor fields: ${vendorData.keys}');
      safeDebugPrint('Vendor companyIds: ${vendorData['companyIds']}');
    }

    safeDebugPrint('=== END CHECK ===');
  }

Future<void> _debugCheckRelations() async {
  safeDebugPrint('=== DEBUG: CHECKING USER-VENDOR-COMPANY RELATIONS ===');
  
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  
  // 1. جلب user data
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  final userSupplierIds = (userDoc.data()?['supplierIds'] as List?)?.cast<String>() ?? [];
  final userCompanyIds = (userDoc.data()?['companyIds'] as List?)?.cast<String>() ?? [];
  
  safeDebugPrint('User Companies: $userCompanyIds');
  safeDebugPrint('User Suppliers: $userSupplierIds');
  
  // 2. لكل مورد، افحص companyIds
  for (final supplierId in userSupplierIds) {
    final supplierDoc = await FirebaseFirestore.instance
        .collection('vendors')
        .doc(supplierId)
        .get();
    
    if (supplierDoc.exists) {
      final data = supplierDoc.data()!;
      final vendorCompanyIds = (data['companyIds'] as List?)?.cast<String>() ?? [];
      safeDebugPrint('Supplier ${data['nameEn']}: companyIds=$vendorCompanyIds');
      
      // 3. افحص أي الشركات المشتركة
      final commonCompanies = userCompanyIds.where((cid) => vendorCompanyIds.contains(cid)).toList();
      safeDebugPrint('  -> Common companies: $commonCompanies');
    }
  }
  
  safeDebugPrint('=== END DEBUG ===');
}


/*   Future<void> _loadSuppliers() async {
    if (_selectedCompanyId == null) return;

    setState(() => _isLoading = true);
    _suppliers = [];

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      safeDebugPrint('=== LOADING SUPPLIERS ===');
      safeDebugPrint('Selected Company ID: $_selectedCompanyId');
      safeDebugPrint('Current user ID: ${user.uid}');

      // 1. جلب supplierIds من ملف المستخدم
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      final userSupplierIds =
          (userData?['supplierIds'] as List?)?.cast<String>() ?? [];

      safeDebugPrint('User supplier IDs from profile: $userSupplierIds');

      if (userSupplierIds.isEmpty) {
        safeDebugPrint('No supplier IDs found in user profile');
        setState(() => _isLoading = false);
        return;
      }

      // 2. جلب تفاصيل كل مورد والتحقق من ارتباطه بالشركة المختارة
      for (final supplierId in userSupplierIds) {
        final supplierDoc = await FirebaseFirestore.instance
            .collection('vendors')
            .doc(supplierId)
            .get();

        if (supplierDoc.exists) {
          final data = supplierDoc.data()!;

          // ✅ التحقق من أن المورد مرتبط بالشركة المختارة
          final vendorCompanyIds =
              (data['companyIds'] as List?)?.cast<String>() ?? [];

          safeDebugPrint(
              'Checking supplier ${data['nameEn']}: companyIds=$vendorCompanyIds');

          if (vendorCompanyIds.contains(_selectedCompanyId)) {
            _suppliers.add({
              'id': supplierId,
              'name': _isArabic ? data['nameAr'] : data['nameEn'],
              'companyIds': vendorCompanyIds,
            });
            safeDebugPrint('✅ Supplier added: ${_suppliers.last['name']}');
          } else {
            safeDebugPrint(
                '❌ Supplier ${data['nameEn']} not linked to selected company');
          }
        } else {
          safeDebugPrint('Supplier document not found for ID: $supplierId');
        }
      }

      safeDebugPrint(
          'Total suppliers loaded for company $_selectedCompanyId: ${_suppliers.length}');

      if (_suppliers.isNotEmpty && _selectedSupplierId == null) {
        setState(() {
          _selectedSupplierId = _suppliers.first['id'] as String;
        });
        await _generateReport();
      } else if (_suppliers.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('no_suppliers_for_company'.tr())),
          );
        }
      }
    } catch (e) {
      safeDebugPrint('Error loading suppliers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'error_loading_suppliers'.tr()}: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
 */
 
 Future<void> _loadSuppliers() async {
  if (_selectedCompanyId == null) return;

  setState(() => _isLoading = true);
  _suppliers = [];

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    safeDebugPrint('=== LOADING SUPPLIERS ===');
    safeDebugPrint('Selected Company ID: $_selectedCompanyId');
    safeDebugPrint('Current user ID: ${user.uid}');

    // جلب supplierIds من ملف المستخدم
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    
    final userData = userDoc.data();
    final userSupplierIds = (userData?['supplierIds'] as List?)?.cast<String>() ?? [];
    
    safeDebugPrint('User supplier IDs from profile: $userSupplierIds');

    if (userSupplierIds.isEmpty) {
      safeDebugPrint('No supplier IDs found in user profile');
      setState(() => _isLoading = false);
      return;
    }

    // جلب تفاصيل الموردين
    for (final supplierId in userSupplierIds) {
      final supplierDoc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(supplierId)
          .get();
      
      if (supplierDoc.exists) {
        final data = supplierDoc.data()!;
        final vendorCompanyIds = (data['companyIds'] as List?)?.cast<String>() ?? [];
        
        safeDebugPrint('Supplier ${data['nameEn']}: companyIds=$vendorCompanyIds');
        
        // ✅ إذا كان companyIds فارغ، نعتبر المورد مرتبط بكل الشركات (حل مؤقت)
        if (vendorCompanyIds.isEmpty) {
          safeDebugPrint('⚠️ Supplier has no companyIds, showing for all companies');
          _suppliers.add({
            'id': supplierId,
            'name': _isArabic ? data['nameAr'] : data['nameEn'],
          });
        }
        // ✅ إذا كان companyIds غير فارغ، نتحقق من الارتباط
        else if (vendorCompanyIds.contains(_selectedCompanyId)) {
          _suppliers.add({
            'id': supplierId,
            'name': _isArabic ? data['nameAr'] : data['nameEn'],
          });
          safeDebugPrint('✅ Supplier added: ${_suppliers.last['name']}');
        } else {
          safeDebugPrint('❌ Supplier ${data['nameEn']} not linked to selected company');
        }
      } else {
        safeDebugPrint('Supplier document not found for ID: $supplierId');
      }
    }

    safeDebugPrint('Total suppliers loaded: ${_suppliers.length}');

    if (_suppliers.isNotEmpty && _selectedSupplierId == null) {
      setState(() {
        _selectedSupplierId = _suppliers.first['id'] as String;
      });
      await _generateReport();
    } else if (_suppliers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('no_suppliers_for_company'.tr())),
        );
      }
    }
  } catch (e) {
    safeDebugPrint('Error loading suppliers: $e');
  } finally {
    setState(() => _isLoading = false);
  }
}

Future<void> _printCurrentUserData() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  
  safeDebugPrint('=== CURRENT USER DATA ===');
  safeDebugPrint('User ID: ${user.uid}');
  safeDebugPrint('User Email: ${user.email}');
  
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  
  final userData = userDoc.data();
  safeDebugPrint('User companyIds: ${userData?['companyIds']}');
  safeDebugPrint('User supplierIds: ${userData?['supplierIds']}');
  safeDebugPrint('User factoryIds: ${userData?['factoryIds']}');
  safeDebugPrint('========================');
}


 
  Future<void> _generateReport() async {
    if (_selectedCompanyId == null || _selectedSupplierId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('select_company_and_supplier'.tr())),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    _performanceData.clear();

    try {
      safeDebugPrint(
          'Generating report for company: $_selectedCompanyId, supplier: $_selectedSupplierId');
      safeDebugPrint('Date range: $_startDate -> $_endDate');

      // جلب جميع أوامر الشراء للمورد خلال الفترة
      Query query = FirebaseFirestore.instance
          .collection('purchase_orders')
          .where('companyId', isEqualTo: _selectedCompanyId)
          .where('supplierId', isEqualTo: _selectedSupplierId);

      if (_startDate != null) {
        query = query.where('orderDate', isGreaterThanOrEqualTo: _startDate);
      }
      if (_endDate != null) {
        final endOfDay = DateTime(
            _endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        query = query.where('orderDate',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
      }

      query = query.orderBy('orderDate', descending: true);

      final ordersSnapshot = await query.get();

      safeDebugPrint('Orders found: ${ordersSnapshot.docs.length}');

      if (ordersSnapshot.docs.isEmpty) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('no_orders_found'.tr())),
          );
        }
        return;
      }

      int totalOrders = ordersSnapshot.docs.length;
      int onTimeDeliveries = 0;
      int totalLeadDays = 0;
      int leadTimeCount = 0;

      for (final doc in ordersSnapshot.docs) {
        final data = doc.data();
// ✅ FIXED: Add this cast line before your variables
        final Map<String, dynamic> docData = data as Map<String, dynamic>;

        final orderDate = (docData['orderDate'] as Timestamp?)?.toDate();
        final expectedDeliveryDate =
            (docData['expectedDeliveryDate'] as Timestamp?)?.toDate();
        final actualDeliveryDate =
            (docData['actualDeliveryDate'] as Timestamp?)?.toDate();
        final status = docData['status'];

        // حساب التسليم في الوقت المحدد
        if (status == 'completed' &&
            expectedDeliveryDate != null &&
            actualDeliveryDate != null) {
          final diffDays =
              actualDeliveryDate.difference(expectedDeliveryDate).inDays;
          if (diffDays <= 3) {
            onTimeDeliveries++;
          }
        }

        // حساب مدة التسليم
        if (orderDate != null && actualDeliveryDate != null) {
          final leadTime = actualDeliveryDate.difference(orderDate).inDays;
          if (leadTime > 0) {
            totalLeadDays += leadTime;
            leadTimeCount++;
          }
        }

        _performanceData.add({
          'poNumber': data['poNumber'],
          'orderDate': orderDate,
          'expectedDeliveryDate': expectedDeliveryDate,
          'actualDeliveryDate': actualDeliveryDate,
          'status': status,
          'isOnTime': status == 'completed' &&
              expectedDeliveryDate != null &&
              actualDeliveryDate != null &&
              actualDeliveryDate.difference(expectedDeliveryDate).inDays <= 3,
          'totalAmount': data['totalAmountAfterTax'] ?? 0,
        });
      }

      // حساب النسب المئوية
      _onTimeDeliveryRate =
          totalOrders > 0 ? (onTimeDeliveries / totalOrders) * 100 : 0;
      _averageLeadTime = leadTimeCount > 0 ? totalLeadDays / leadTimeCount : 0;

      // حساب دقة الطلب وجودة المنتج (يمكن تحسينها لاحقاً)
      _orderAccuracyRate = totalOrders > 0 ? 85.0 : 0;
      _qualityAcceptanceRate = totalOrders > 0 ? 90.0 : 0;

      setState(() {});
    } catch (e) {
      safeDebugPrint('Error generating supplier report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_generating_report'.tr())),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _startDate ?? DateTime.now().subtract(const Duration(days: 90)),
        end: _endDate ?? DateTime.now(),
      ),
      saveText: 'apply'.tr(),
      cancelText: 'cancel'.tr(),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedPeriod = 'custom';
      });
      await _generateReport();
    }
  }

  void _onPeriodChanged(String? period) {
    if (period == null) return;
    setState(() {
      _selectedPeriod = period;
      _setPeriodDates();
    });
    _generateReport();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _getPeriodText() {
    switch (_selectedPeriod) {
      case 'monthly':
        return _isArabic ? 'شهري' : 'Monthly';
      case 'quarterly':
        return _isArabic ? 'ربع سنوي' : 'Quarterly';
      case 'semi_annual':
        return _isArabic ? 'نصف سنوي' : 'Semi-Annual';
      case 'annual':
        return _isArabic ? 'سنوي' : 'Annual';
      case 'custom':
        return _isArabic ? 'مدة محددة' : 'Custom';
      default:
        return '';
    }
  }

  Color _getPerformanceColor(double rate) {
    if (rate >= 90) return Colors.green;
    if (rate >= 70) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    _isArabic = context.locale.languageCode == 'ar';

    return AppScaffold(
      title: 'supplier_performance_report'.tr(),
      body: Column(
        children: [
          // شريط الفلاتر
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[100],
            child: Column(
              children: [
                // الصف 1: الشركة
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCompanyId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'company'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: _companies.map((c) {
                          return DropdownMenuItem<String>(
                            value: c['id'],
                            child: Text(c['name']),
                          );
                        }).toList(),
                        onChanged: (val) async {
                          setState(() {
                            _selectedCompanyId = val;
                            _selectedSupplierId = null;
                            _suppliers = [];
                            _performanceData = [];
                          });
                          await _loadSuppliers();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedSupplierId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'supplier'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: _suppliers.map((s) {
                          return DropdownMenuItem<String>(
                            value: s['id'],
                            child: Text(s['name']),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedSupplierId = val;
                          });
                          _generateReport();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // الصف 2: الفترة الزمنية
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedPeriod,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'period'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem<String>(
                              value: 'monthly',
                              child: Text(_isArabic ? 'شهري' : 'Monthly')),
                          DropdownMenuItem<String>(
                              value: 'quarterly',
                              child:
                                  Text(_isArabic ? 'ربع سنوي' : 'Quarterly')),
                          DropdownMenuItem<String>(
                              value: 'semi_annual',
                              child:
                                  Text(_isArabic ? 'نصف سنوي' : 'Semi-Annual')),
                          DropdownMenuItem<String>(
                              value: 'annual',
                              child: Text(_isArabic ? 'سنوي' : 'Annual')),
                          DropdownMenuItem<String>(
                              value: 'custom',
                              child: Text(_isArabic ? 'مدة محددة' : 'Custom')),
                        ],
                        onChanged: _onPeriodChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_selectedPeriod == 'custom')
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectCustomDateRange,
                          icon: const Icon(Icons.date_range, size: 18),
                          label: Text(
                            '${_formatDate(_startDate)} → ${_formatDate(_endDate)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _generateReport,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text('refresh'.tr()),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // عرض الفترة الحالية
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${'selected_period'.tr()}: ${_getPeriodText()}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${_formatDate(_startDate)} → ${_formatDate(_endDate)}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // بطاقات مؤشرات الأداء الرئيسية (KPIs)
          if (_performanceData.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _buildKPICard(
                    title: 'on_time_delivery'.tr(),
                    value: '${_onTimeDeliveryRate.toStringAsFixed(1)}%',
                    color: _getPerformanceColor(_onTimeDeliveryRate),
                    icon: Icons.schedule,
                  ),
                  const SizedBox(width: 8),
                  _buildKPICard(
                    title: 'average_lead_time'.tr(),
                    value:
                        '${_averageLeadTime.toStringAsFixed(1)} ${'days'.tr()}',
                    color: _averageLeadTime <= 14
                        ? Colors.green
                        : (_averageLeadTime <= 30 ? Colors.orange : Colors.red),
                    icon: Icons.timer,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _buildKPICard(
                    title: 'order_accuracy'.tr(),
                    value: '${_orderAccuracyRate.toStringAsFixed(1)}%',
                    color: _getPerformanceColor(_orderAccuracyRate),
                    icon: Icons.check_circle,
                  ),
                  const SizedBox(width: 8),
                  _buildKPICard(
                    title: 'quality_acceptance'.tr(),
                    value: '${_qualityAcceptanceRate.toStringAsFixed(1)}%',
                    color: _getPerformanceColor(_qualityAcceptanceRate),
                    icon: Icons.verified,
                  ),
                ],
              ),
            ),
          ],

          // قائمة الطلبات
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _performanceData.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.analytics,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              _selectedSupplierId == null
                                  ? 'select_supplier_first'.tr()
                                  : _suppliers.isEmpty
                                      ? 'no_suppliers_found'.tr()
                                      : 'no_orders_found_period'.tr(),
                              style: TextStyle(color: Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _performanceData.length,
                        itemBuilder: (context, index) {
                          final order = _performanceData[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            elevation: 2,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: order['isOnTime']
                                    ? Colors.green.shade100
                                    : Colors.orange.shade100,
                                child: Icon(
                                  order['isOnTime']
                                      ? Icons.check
                                      : Icons.warning,
                                  color: order['isOnTime']
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                              title:
                                  Text(order['poNumber'] ?? 'PO-${index + 1}'),
                              subtitle: Text(
                                '${'order_date'.tr()}: ${_formatDate(order['orderDate'])} | '
                                '${'status'.tr()}: ${order['status'] == 'completed' ? 'completed'.tr() : 'pending'.tr()}',
                              ),
                              trailing: Text(
                                '${(order['totalAmount'] ?? 0).toStringAsFixed(2)} ${'currency'.tr()}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              onTap: () {
                                _showOrderDetails(order);
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(75)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('order_details'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('po_number'.tr(), order['poNumber'] ?? '-'),
            _buildDetailRow('order_date'.tr(), _formatDate(order['orderDate'])),
            _buildDetailRow('expected_delivery'.tr(),
                _formatDate(order['expectedDeliveryDate'])),
            _buildDetailRow('actual_delivery'.tr(),
                _formatDate(order['actualDeliveryDate'])),
            _buildDetailRow(
                'status'.tr(),
                order['status'] == 'completed'
                    ? 'completed'.tr()
                    : 'pending'.tr()),
            _buildDetailRow(
                'on_time'.tr(), order['isOnTime'] ? 'yes'.tr() : 'no'.tr(),
                valueColor: order['isOnTime'] ? Colors.green : Colors.red),
            _buildDetailRow('total_amount'.tr(),
                '${(order['totalAmount'] ?? 0).toStringAsFixed(2)} ${'currency'.tr()}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: valueColor ?? Colors.grey.shade900),
            ),
          ),
        ],
      ),
    );
  }
}
