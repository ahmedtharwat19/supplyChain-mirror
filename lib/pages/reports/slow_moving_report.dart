// lib/pages/reports/slow_moving_report.dart
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
}