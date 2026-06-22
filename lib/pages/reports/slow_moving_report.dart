/* // lib/pages/reports/slow_moving_report.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';

class SlowMovingReport extends StatefulWidget {
  const SlowMovingReport({super.key});

  @override
  State<SlowMovingReport> createState() => _SlowMovingReportState();
}

class _SlowMovingReportState extends State<SlowMovingReport> {
  bool _isLoading = false;
  bool _isArabic = false;
  
  // فلاتر التقرير
  String? _selectedCompanyId;
  String? _selectedFactoryId;
  int _selectedDays = 90; // 90 يوم افتراضياً
  final List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _factories = [];
  final List<Map<String, dynamic>> _slowMovingItems = [];
  
  final List<int> _dayOptions = [30, 60, 90, 120, 180, 365];
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isArabic = context.locale.languageCode == 'ar';
  }
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    await _loadCompanies();
    await _loadFactories();
  }
  
  Future<void> _loadCompanies() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    
    final userCompanyIds = (userDoc.data()?['companyIds'] as List?)?.cast<String>() ?? [];
    
    for (final companyId in userCompanyIds) {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        _companies.add({
          'id': companyId,
          'name': _isArabic ? data['nameAr'] : data['nameEn'],
        });
      }
    }
    
    if (_companies.isNotEmpty && _selectedCompanyId == null) {
      setState(() {
        _selectedCompanyId = _companies.first['id'] as String;
      });
      await _loadFactories();
    }
  }
  
  Future<void> _loadFactories() async {
    if (_selectedCompanyId == null) return;
    
    _factories = [];
    final snapshot = await FirebaseFirestore.instance
        .collection('factories')
        .where('companyIds', arrayContains: _selectedCompanyId)
        .get();
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      _factories.add({
        'id': doc.id,
        'name': _isArabic ? data['nameAr'] : data['nameEn'],
      });
    }
    
    if (_factories.isNotEmpty && _selectedFactoryId == null) {
      setState(() {
        _selectedFactoryId = _factories.first['id'] as String;
      });
    }
  }
  
  Future<void> _generateReport() async {
    if (_selectedCompanyId == null || _selectedFactoryId == null) return;
    
    setState(() => _isLoading = true);
    _slowMovingItems.clear();
    
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: _selectedDays));
      
      // 1. جلب جميع الأصناف في المصنع
      final inventorySnapshot = await FirebaseFirestore.instance
          .collection('factories')
          .doc(_selectedFactoryId)
          .collection('inventory')
          .get();
      
      // 2. لكل صنف، جلب آخر حركة له
      for (final invDoc in inventorySnapshot.docs) {
        final itemId = invDoc.id;
        final currentStock = invDoc.data()['quantity'] ?? 0;
        
        // جلب آخر حركة للصنف
        final movementsSnapshot = await FirebaseFirestore.instance
            .collection('companies')
            .doc(_selectedCompanyId)
            .collection('stock_movements')
            .where('factoryId', isEqualTo: _selectedFactoryId)
            .where('itemId', isEqualTo: itemId)
            .orderBy('date', descending: true)
            .limit(1)
            .get();
        
        DateTime? lastMovementDate;
        String? lastMovementType;
        double? lastMovementQuantity;
        
        if (movementsSnapshot.docs.isNotEmpty) {
          final data = movementsSnapshot.docs.first.data();
          lastMovementDate = (data['date'] as Timestamp?)?.toDate();
          lastMovementType = data['type'];
          lastMovementQuantity = (data['quantity'] as num?)?.toDouble();
        }
        
        // حساب عدد الأيام منذ آخر حركة
        int daysSinceLastMovement = -1;
        if (lastMovementDate != null) {
          daysSinceLastMovement = DateTime.now().difference(lastMovementDate).inDays;
        }
        
        // إذا كان الصنف راكد (آخر حركة قبل تاريخ القطع أو ليس له حركات)
        if (lastMovementDate == null || lastMovementDate.isBefore(cutoffDate)) {
          // جلب اسم الصنف
          final itemDoc = await FirebaseFirestore.instance
              .collection('items')
              .doc(itemId)
              .get();
          
          final itemData = itemDoc.data();
          final itemName = _isArabic
              ? (itemData?['nameAr'] ?? itemData?['nameEn'] ?? itemId)
              : (itemData?['nameEn'] ?? itemData?['nameAr'] ?? itemId);
          
          final itemCategory = itemData?['category'] ?? 'raw_material';
          
          _slowMovingItems.add({
            'itemId': itemId,
            'itemName': itemName,
            'category': itemCategory,
            'currentStock': currentStock,
            'lastMovementDate': lastMovementDate,
            'lastMovementType': lastMovementType,
            'lastMovementQuantity': lastMovementQuantity,
            'daysSinceLastMovement': daysSinceLastMovement,
            'hasMovements': lastMovementDate != null,
          });
        }
      }
      
      // ترتيب النتائج (الأكثر ركوداً أولاً)
      _slowMovingItems.sort((a, b) {
        final aDays = a['daysSinceLastMovement'] ?? 9999;
        final bDays = b['daysSinceLastMovement'] ?? 9999;
        return bDays.compareTo(aDays);
      });
      
      setState(() {});
    } catch (e) {
      safeDebugPrint('Error generating report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_generating_report'.tr())),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  String _getCategoryText(String category) {
    if (category == 'raw_material') {
      return _isArabic ? 'مواد خام' : 'Raw Material';
    }
    return _isArabic ? 'مواد تعبئة' : 'Packaging';
  }
  
  Color _getRiskColor(int days) {
    if (days >= 180) return Colors.red;
    if (days >= 90) return Colors.orange;
    return Colors.yellow.shade700;
  }
  
  String _getRiskText(int days) {
    if (days >= 180) return _isArabic ? 'خطير جداً' : 'Critical';
    if (days >= 90) return _isArabic ? 'مرتفع' : 'High';
    if (days >= 60) return _isArabic ? 'متوسط' : 'Medium';
    return _isArabic ? 'منخفض' : 'Low';
  }
  
  @override
  Widget build(BuildContext context) {
    _isArabic = context.locale.languageCode == 'ar';
    
    return AppScaffold(
      title: 'slow_moving_report'.tr(),
      body: Column(
        children: [
          // شريط الفلاتر
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[100],
            child: Column(
              children: [
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
                            _selectedFactoryId = null;
                            _factories = [];
                          });
                          await _loadFactories();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedFactoryId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'factory'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: _factories.map((f) {
                          return DropdownMenuItem<String>(
                            value: f['id'],
                            child: Text(f['name']),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedFactoryId = val;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _selectedDays,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'inactivity_period'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: _dayOptions.map((days) {
                          return DropdownMenuItem<int>(
                            value: days,
                            child: Text('$days ${'days'.tr()}'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedDays = val!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _generateReport,
                        icon: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.search),
                        label: Text('generate_report'.tr()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // النتائج
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _slowMovingItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, size: 64, color: Colors.green.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'no_slow_moving_items'.tr(),
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'all_items_active'.tr(),
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _slowMovingItems.length,
                        itemBuilder: (context, index) {
                          final item = _slowMovingItems[index];
                          final days = item['daysSinceLastMovement'] ?? 0;
                          final hasMovements = item['hasMovements'];
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: _getRiskColor(days).withValues(alpha: 0.2),
                                child: Icon(
                                  Icons.inventory,
                                  color: _getRiskColor(days),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['itemName'],
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getRiskColor(days).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getRiskText(days),
                                      style: TextStyle(
                                        color: _getRiskColor(days),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${'category'.tr()}: ${_getCategoryText(item['category'])}'),
                                  Text('${'current_stock'.tr()}: ${item['currentStock']}'),
                                  if (hasMovements)
                                    Text('${'last_movement'.tr()}: ${item['lastMovementDate'] != null ? _formatDate(item['lastMovementDate']) : 'none'.tr()}'),
                                  Text('${'days_since_last_movement'.tr()}: ${days == -1 ? 'never'.tr() : '$days ${'days'.tr()}'}'),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (hasMovements) ...[
                                        _buildInfoRow(
                                          Icons.history,
                                          'last_movement_type'.tr(),
                                          item['lastMovementType'] ?? 'unknown',
                                        ),
                                        const SizedBox(height: 8),
                                        _buildInfoRow(
                                          Icons.production_quantity_limits,
                                          'last_movement_quantity'.tr(),
                                          item['lastMovementQuantity']?.toString() ?? '0',
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      _buildInfoRow(
                                        Icons.warning,
                                        'recommendation'.tr(),
                                        days >= 180
                                            ? (_isArabic ? 'يوصى بالتخلص أو إعادة التدوير' : 'Recommend disposal or recycling')
                                            : days >= 90
                                                ? (_isArabic ? 'يوصى بتخفيض السعر أو عروض ترويجية' : 'Recommend price reduction or promotions')
                                                : (_isArabic ? 'مراقبة المخزون ومراجعة الطلب' : 'Monitor inventory and review demand'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
        Expanded(child: Text(value, style: TextStyle(color: Colors.grey.shade700))),
      ],
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
} */


// lib/pages/reports/slow_moving_report.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/reports_data_service.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:puresip_purchasing/widgets/reports_widgets.dart';

class SlowMovingReport extends StatefulWidget {
  const SlowMovingReport({super.key});

  @override
  State<SlowMovingReport> createState() => _SlowMovingReportState();
}

class _SlowMovingReportState extends State<SlowMovingReport> {
  final ReportsDataService _dataService = ReportsDataService();

  bool _isLoading = false;
  bool _isLoadingReport = false;

  String? _selectedCompanyId;
  String? _selectedFactoryId;
  int _selectedDays = 90;

  final List<Map<String, dynamic>> _companies = [];
  final List<Map<String, dynamic>> _factories = [];
  final List<Map<String, dynamic>> _slowMovingItems = [];

  final List<int> _dayOptions = [30, 60, 90, 120, 180, 365];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _loadCompanies();
    await _loadFactories();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadCompanies() async {
    final companies = await _dataService.getUserCompanies();
    if (!mounted) return;
    
    // ✅ تخزين البيانات الخام
    setState(() {
      _companies..clear()..addAll(companies.map((c) {
        return {
          'id': c['id'].toString(),
          'nameAr': c['nameAr']?.toString() ?? c['id'].toString(),
          'nameEn': c['nameEn']?.toString() ?? c['id'].toString(),
        };
      }).toList());
    });

    if (_companies.isNotEmpty && _selectedCompanyId == null) {
      _selectedCompanyId = _companies.first['id'] as String;
    }
  }

  Future<void> _loadFactories() async {
    if (_selectedCompanyId == null) return;

    final factories = await _dataService.getFactoriesForCompany(
      _selectedCompanyId!,
    );
    if (!mounted) return;
    
    // ✅ تخزين البيانات الخام
    setState(() {
      _factories..clear()..addAll(factories.map((f) {
        return {
          'id': f['id'].toString(),
          'nameAr': f['nameAr']?.toString() ?? f['id'].toString(),
          'nameEn': f['nameEn']?.toString() ?? f['id'].toString(),
        };
      }).toList());
    });

    if (_factories.isNotEmpty && _selectedFactoryId == null) {
      _selectedFactoryId = _factories.first['id'] as String;
    }
  }

  Future<void> _generateReport() async {
    if (_selectedCompanyId == null || _selectedFactoryId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('select_factory_first'.tr())),
        );
      }
      return;
    }

    setState(() => _isLoadingReport = true);
    _slowMovingItems.clear();

    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: _selectedDays));

      // 1. جلب مخزون المصنع كله
      final inventoryMap = await _dataService.getFactoryInventory(
        _selectedFactoryId!,
      );

      if (inventoryMap.isEmpty) {
        if (mounted) setState(() => _isLoadingReport = false);
        return;
      }

      // 2. جلب أسماء الأصناف
      final itemsMap = await _dataService.getItemsMap();

      // 3. جلب حركات المصنع منذ تاريخ القطع
      final movementsDocs = await _dataService.getStockMovements(
        companyId: _selectedCompanyId!,
        factoryId: _selectedFactoryId!,
        startDate: cutoffDate,
      );

      // 4. بناء خريطة آخر حركة لكل صنف
      final lastMovementMap = <String, Map<String, dynamic>>{};
      for (final doc in movementsDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final itemId = data['itemId']?.toString() ?? '';
        if (itemId.isEmpty) continue;

        if (!lastMovementMap.containsKey(itemId)) {
          final date = (data['date'] as Timestamp?)?.toDate();
          lastMovementMap[itemId] = {
            'date': date,
            'type': data['type'],
            'quantity': (data['quantity'] as num?)?.toDouble() ?? 0,
          };
        }
      }

      // 5. معالجة البيانات
      for (final entry in inventoryMap.entries) {
        final itemId = entry.key;
        final inventoryData = entry.value;
        final currentStock = (inventoryData['quantity'] as num?)?.toDouble() ?? 0;

        final lastMovement = lastMovementMap[itemId];
        final lastMovementDate = lastMovement?['date'] as DateTime?;
        final hasMovements = lastMovementDate != null;

        if (!hasMovements || lastMovementDate.isBefore(cutoffDate)) {
          final itemData = itemsMap[itemId];
          final itemName = itemData?['name'] ?? itemId;

          final daysSinceLastMovement = hasMovements
              ? DateTime.now().difference(lastMovementDate).inDays
              : -1;

          String riskLevel;
          if (daysSinceLastMovement >= 180) {
            riskLevel = 'critical';
          } else if (daysSinceLastMovement >= 90) {
            riskLevel = 'high';
          } else if (daysSinceLastMovement >= 60) {
            riskLevel = 'medium';
          } else {
            riskLevel = 'low';
          }

          _slowMovingItems.add({
            'itemId': itemId,
            'itemName': itemName,
            'category': itemData?['category'] ?? 'raw_material',
            'currentStock': currentStock,
            'lastMovementDate': lastMovementDate,
            'lastMovementType': lastMovement?['type'],
            'lastMovementQuantity': lastMovement?['quantity'],
            'daysSinceLastMovement': daysSinceLastMovement,
            'hasMovements': hasMovements,
            'riskLevel': riskLevel,
          });
        }
      }

      _slowMovingItems.sort((a, b) {
        final aDays = a['daysSinceLastMovement'] ?? 9999;
        final bDays = b['daysSinceLastMovement'] ?? 9999;
        return bDays.compareTo(aDays);
      });

      if (mounted) setState(() {});
    } catch (e) {
      safeDebugPrint('Error generating report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_generating_report'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingReport = false);
    }
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.yellow.shade700;
      default:
        return Colors.green;
    }
  }

  // ✅ دالة مساعدة لتحميل الزر
  Widget _buildLoadingIndicator() {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ تحديد اللغة الحالية في الـ build
    final isArabic = context.locale.languageCode == 'ar';

    // ✅ تحويل البيانات إلى الشكل المطلوب مع الاسم حسب اللغة
    final companyItems = _companies.map((c) {
      return {
        'id': c['id'],
        'name': isArabic 
            ? (c['nameAr'] ?? c['nameEn'] ?? c['id'])
            : (c['nameEn'] ?? c['nameAr'] ?? c['id']),
      };
    }).toList();

    final factoryItems = _factories.map((f) {
      return {
        'id': f['id'],
        'name': isArabic 
            ? (f['nameAr'] ?? f['nameEn'] ?? f['id'])
            : (f['nameEn'] ?? f['nameAr'] ?? f['id']),
      };
    }).toList();

    final filterBar = ReportFilterBar(
      companies: companyItems,
      factories: factoryItems,
      selectedCompanyId: _selectedCompanyId,
      selectedFactoryId: _selectedFactoryId,
      onCompanyChanged: (val) async {
        setState(() {
          _selectedCompanyId = val;
          _selectedFactoryId = null;
          _factories.clear();
          _slowMovingItems.clear();
        });
        await _loadFactories();
      },
      onFactoryChanged: (val) {
        setState(() {
          _selectedFactoryId = val;
          _slowMovingItems.clear();
        });
      },
      isLoading: _isLoading,
      extraFilters: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _selectedDays,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'inactivity_period'.tr(),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              items: _dayOptions.map((days) {
                return DropdownMenuItem<int>(
                  value: days,
                  child: Text('$days ${'days'.tr()}'),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedDays = val!);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isLoadingReport ? null : _generateReport,
              icon: _isLoadingReport
                  ? _buildLoadingIndicator()
                  : const Icon(Icons.search),
              label: Text('generate_report'.tr()),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 50),
              ),
            ),
          ),
        ],
      ),
    );

    return AppScaffold(
      title: 'slow_moving_report'.tr(),
      body: Column(
        children: [
          filterBar,
          Expanded(
            child: _isLoading || _isLoadingReport
                ? const Center(child: CircularProgressIndicator())
                : _slowMovingItems.isEmpty
                    ? ReportEmptyState(
                        icon: Icons.check_circle,
                        title: 'no_slow_moving_items'.tr(),
                        subtitle: 'all_items_active'.tr(),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _slowMovingItems.length,
                        itemBuilder: (context, index) {
                          final item = _slowMovingItems[index];
                          final days = item['daysSinceLastMovement'] as int;
                          final riskLevel = item['riskLevel'] as String;
                          final hasMovements = item['hasMovements'] as bool;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: _getRiskColor(riskLevel).withAlpha(50),
                                child: Icon(
                                  Icons.inventory,
                                  color: _getRiskColor(riskLevel),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['itemName'],
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getRiskColor(riskLevel).withAlpha(50),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'risk_level_$riskLevel'.tr(),
                                      style: TextStyle(
                                        color: _getRiskColor(riskLevel),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${'category'.tr()}: ${'category_${item['category']}'.tr()}'),
                                  Text('${'current_stock'.tr()}: ${item['currentStock']}'),
                                  if (hasMovements)
                                    Text('${'last_movement'.tr()}: ${formatDate(item['lastMovementDate'])}'),
                                  Text(
                                    '${'days_since_last_movement'.tr()}: ${days == -1 ? 'never'.tr() : '$days ${'days'.tr()}'}',
                                  ),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (hasMovements) ...[
                                        Row(
                                          children: [
                                            Icon(Icons.history, size: 16, color: Colors.grey.shade600),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${'last_movement_type'.tr()}: ${item['lastMovementType'] ?? 'unknown'}',
                                              style: TextStyle(color: Colors.grey.shade700),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.production_quantity_limits, size: 16, color: Colors.grey.shade600),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${'last_movement_quantity'.tr()}: ${item['lastMovementQuantity']?.toString() ?? '0'}',
                                              style: TextStyle(color: Colors.grey.shade700),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.warning, size: 16, color: _getRiskColor(riskLevel)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'slow_moving_recommendation_$riskLevel'.tr(),
                                              style: TextStyle(color: Colors.grey.shade700),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}