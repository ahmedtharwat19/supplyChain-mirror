// lib/pages/stock_movements/stock_movements_page.dart
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/pages/stock_movements/services/movement_utils.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';

class StockMovementsPage extends StatefulWidget {
  const StockMovementsPage({super.key});

  @override
  State<StockMovementsPage> createState() => _StockMovementsPageState();
}

class _StockMovementsPageState extends State<StockMovementsPage> {
  // ==================== الفلاتر ====================
  String? selectedCompanyId;
  String? selectedFactoryId;
  String? selectedItemId;
  String? selectedCategory;
  DateTime? startDate;
  DateTime? endDate;
  String sortOrder = 'desc';

  // ==================== البيانات ====================
  List<Map<String, dynamic>> companies = [];
  List<Map<String, dynamic>> factories = [];
  List<Map<String, dynamic>> allItems = [];
  List<Map<String, dynamic>> filteredItems = [];
  Map<String, double> itemStocks = {};
  Map<String, String> itemNames = {};

  // ==================== حالة الصفحة ====================
  bool _isLoadingFirstTime = true;
  bool _isLoadingMovements = false;
  bool _isArabic = false;
  List<String> userCompanyIds = [];

  // ==================== بيانات الحركات ====================
  List<Map<String, dynamic>> _movements = [];
  String _lastQueryKey = '';

  // ✅ مفاتيح التخزين المؤقت في SharedPreferences
  static const String _keyCompanies = 'stock_companies';
  static const String _keyFactoriesPrefix = 'stock_factories_';
  static const String _keyItemNames = 'stock_item_names';
  static const String _keyItemsForFactoryPrefix = 'stock_items_';
  static const String _keyStocksPrefix = 'stock_stocks_';
  static const String _keyMovementsPrefix = 'stock_movements_';
  static const String _keyLastUpdate = 'stock_last_update';

  @override
  void initState() {
    super.initState();
    _setupInitialDates();
    _loadFromCacheImmediately();
    _syncInBackground();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _setupInitialDates() {
    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, now.day - 30);
    endDate = now;
  }

  /// ✅ تحميل البيانات من SharedPreferences فوراً
  Future<void> _loadFromCacheImmediately() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // تحميل الشركات
      final companiesJson = prefs.getString(_keyCompanies);
      if (companiesJson != null) {
        final List<dynamic> decoded = json.decode(companiesJson);
        companies = decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        
        if (companies.isNotEmpty && selectedCompanyId == null) {
          selectedCompanyId = companies.first['id'] as String;
        }
      }

      // تحميل المصانع للشركة المحددة
      if (selectedCompanyId != null) {
        final factoriesJson = prefs.getString('$_keyFactoriesPrefix$selectedCompanyId');
        if (factoriesJson != null) {
          final List<dynamic> decoded = json.decode(factoriesJson);
          factories = decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
          
          if (factories.isNotEmpty && selectedFactoryId == null) {
            selectedFactoryId = factories.first['id'] as String;
          }
        }
      }

      // تحميل أسماء المنتجات
      final itemNamesJson = prefs.getString(_keyItemNames);
      if (itemNamesJson != null) {
        itemNames = Map<String, String>.from(json.decode(itemNamesJson));
      }

      // تحميل المنتجات للمصنع المحدد
      if (selectedFactoryId != null) {
        final itemsJson = prefs.getString('$_keyItemsForFactoryPrefix$selectedFactoryId');
        if (itemsJson != null) {
          final List<dynamic> decoded = json.decode(itemsJson);
          allItems = decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
          _filterItemsByCategory();
        }

        // تحميل المخزون
        final stocksJson = prefs.getString('$_keyStocksPrefix$selectedFactoryId');
        if (stocksJson != null) {
          final Map<String, dynamic> decoded = json.decode(stocksJson);
          itemStocks = decoded.map((k, v) => MapEntry(k, _toDouble(v)));
        }

        // تحميل الحركات
        final movementsJson = prefs.getString('$_keyMovementsPrefix$selectedFactoryId');
        if (movementsJson != null) {
          final List<dynamic> decoded = json.decode(movementsJson);
          _movements = decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        }
      }

      if (mounted) setState(() {});
      safeDebugPrint('[CACHE] Loaded from SharedPreferences');
    } catch (e) {
      safeDebugPrint('[CACHE LOAD ERROR] $e');
    } finally {
      if (mounted) setState(() => _isLoadingFirstTime = false);
    }
  }

/*   /// ✅ حفظ البيانات في SharedPreferences
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (companies.isNotEmpty) {
        await prefs.setString(_keyCompanies, json.encode(companies));
      }
      
      if (selectedCompanyId != null && factories.isNotEmpty) {
        await prefs.setString('$_keyFactoriesPrefix$selectedCompanyId', json.encode(factories));
      }
      
      if (itemNames.isNotEmpty) {
        await prefs.setString(_keyItemNames, json.encode(itemNames));
      }
      
      if (selectedFactoryId != null) {
        if (allItems.isNotEmpty) {
          await prefs.setString('$_keyItemsForFactoryPrefix$selectedFactoryId', json.encode(allItems));
        }
        if (itemStocks.isNotEmpty) {
          await prefs.setString('$_keyStocksPrefix$selectedFactoryId', json.encode(itemStocks));
        }
        if (_movements.isNotEmpty) {
          await prefs.setString('$_keyMovementsPrefix$selectedFactoryId', json.encode(_movements));
        }
      }
      
      // تحديث وقت آخر تحديث
      await prefs.setInt(_keyLastUpdate, DateTime.now().millisecondsSinceEpoch);
      
      safeDebugPrint('[CACHE] Data saved to SharedPreferences');
    } catch (e) {
      safeDebugPrint('[CACHE SAVE ERROR] $e');
    }
  }
 */
  /// ✅ مزامنة الخلفية من Firestore
  Future<void> _syncInBackground() async {
    try {
      await _loadUserCompanies();
      await _loadCompanies();
      await _loadFactories();
      await _loadAllItemNames();
      
      if (selectedFactoryId != null) {
        await _loadItemsForCurrentFactory();
        await _loadInventory();
        await _loadMovements();
      }
      
      await _saveToCache();
      safeDebugPrint('[SYNC] Background completed');
    } catch (e) {
      safeDebugPrint('[SYNC ERROR] $e');
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return 0.0;
  }

  Future<void> _loadUserCompanies() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists) {
        userCompanyIds = List<String>.from(userDoc.data()?['companyIds'] ?? []);
      }
    } catch (e) {
      safeDebugPrint('[ERROR] loadUserCompanies: $e');
    }
  }

// ✅ _loadCompanies — طلب واحد whereIn بدل loop
Future<void> _loadCompanies() async {
  if (userCompanyIds.isEmpty) return;

  final snapshot = await FirebaseFirestore.instance
      .collection('companies')
      .where(FieldPath.documentId, whereIn: userCompanyIds)
      .get();

  companies = snapshot.docs.map((doc) => {
    'id': doc.id,
    'nameAr': doc.data()['nameAr'] ?? doc.id,
    'nameEn': doc.data()['nameEn'] ?? doc.id,
  }).toList();

  if (companies.isNotEmpty && selectedCompanyId == null) {
    selectedCompanyId = companies.first['id'] as String;
  }
}

// ✅ _loadAllItemNames — فقط items المرتبطة بالمستخدم
Future<void> _loadAllItemNames() async {
  if (userCompanyIds.isEmpty) return;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final snapshot = await FirebaseFirestore.instance
      .collection('items')
      .where('userId', isEqualTo: user.uid)
      .get();

  for (final doc in snapshot.docs) {
    final data = doc.data();
    final nameAr = data['nameAr'] as String?;
    final nameEn = data['nameEn'] as String?;
    itemNames[doc.id] = _isArabic
        ? (nameAr ?? nameEn ?? doc.id)
        : (nameEn ?? nameAr ?? doc.id);
  }
}

// ✅ _saveToCache — تحويل Timestamp قبل الحفظ
Future<void> _saveToCache() async {
  try {
    final prefs = await SharedPreferences.getInstance();

    if (companies.isNotEmpty) {
      await prefs.setString(_keyCompanies, json.encode(companies));
    }

    if (selectedCompanyId != null && factories.isNotEmpty) {
      await prefs.setString(
          '$_keyFactoriesPrefix$selectedCompanyId', json.encode(factories));
    }

    if (itemNames.isNotEmpty) {
      await prefs.setString(_keyItemNames, json.encode(itemNames));
    }

    if (selectedFactoryId != null) {
      if (allItems.isNotEmpty) {
        await prefs.setString(
            '$_keyItemsForFactoryPrefix$selectedFactoryId', json.encode(allItems));
      }
      if (itemStocks.isNotEmpty) {
        await prefs.setString(
            '$_keyStocksPrefix$selectedFactoryId', json.encode(itemStocks));
      }
      if (_movements.isNotEmpty) {
        // ✅ تحويل Timestamp لـ String قبل JSON
        final serializable = _movements.map((m) {
          return m.map((key, value) {
            if (value is Timestamp) {
              return MapEntry(key, value.toDate().toIso8601String());
            }
            return MapEntry(key, value);
          });
        }).toList();

        await prefs.setString(
            '$_keyMovementsPrefix$selectedFactoryId', json.encode(serializable));
      }
    }

    await prefs.setInt(_keyLastUpdate, DateTime.now().millisecondsSinceEpoch);
    safeDebugPrint('[CACHE] Data saved to SharedPreferences');
  } catch (e) {
    safeDebugPrint('[CACHE SAVE ERROR] $e');
  }
}

/*   Future<void> _loadCompanies() async {
    if (userCompanyIds.isEmpty) return;
    
    companies = [];
    for (final companyId in userCompanyIds) {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        companies.add({
          'id': companyId,
          'nameAr': data['nameAr'] ?? companyId,
          'nameEn': data['nameEn'] ?? companyId,
        });
      }
    }
    
    if (companies.isNotEmpty && selectedCompanyId == null) {
      selectedCompanyId = companies.first['id'] as String;
    }
  }
 */
  
  Future<void> _loadFactories() async {
    if (selectedCompanyId == null) return;
    
    factories = [];
    final snapshot = await FirebaseFirestore.instance
        .collection('factories')
        .where('companyIds', arrayContains: selectedCompanyId)
        .get();
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      factories.add({
        'id': doc.id,
        'nameAr': data['nameAr'] ?? doc.id,
        'nameEn': data['nameEn'] ?? doc.id,
      });
    }
    
    if (factories.isNotEmpty && selectedFactoryId == null) {
      selectedFactoryId = factories.first['id'] as String;
    }
  }

/*   Future<void> _loadAllItemNames() async {
    final snapshot = await FirebaseFirestore.instance.collection('items').get();
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final nameAr = data['nameAr'] as String?;
      final nameEn = data['nameEn'] as String?;
      itemNames[doc.id] = _isArabic ? (nameAr ?? nameEn ?? doc.id) : (nameEn ?? nameAr ?? doc.id);
    }
  }
 */
  
  Future<void> _loadItemsForCurrentFactory() async {
    if (selectedCompanyId == null || selectedFactoryId == null) return;
    
    try {
      final movementsSnap = await FirebaseFirestore.instance
          .collection('companies')
          .doc(selectedCompanyId)
          .collection('stock_movements')
          .where('factoryId', isEqualTo: selectedFactoryId)
          .get();
      
      final Set<String> itemIds = {};
      for (final doc in movementsSnap.docs) {
        final itemId = doc.data()['itemId']?.toString();
        if (itemId != null && itemId.isNotEmpty) itemIds.add(itemId);
      }
      
      if (itemIds.isEmpty) {
        setState(() { allItems = []; filteredItems = []; });
        return;
      }
      
      final itemsSnapshot = await FirebaseFirestore.instance
          .collection('items')
          .where(FieldPath.documentId, whereIn: itemIds.toList())
          .get();
      
      final List<Map<String, dynamic>> itemsForFactory = [];
      for (final doc in itemsSnapshot.docs) {
        final data = doc.data();
        itemsForFactory.add({
          'id': doc.id,
          'nameAr': data['nameAr'] ?? doc.id,
          'nameEn': data['nameEn'] ?? doc.id,
          'category': data['category']?.toString() ?? 'raw_material',
        });
      }
      
      setState(() {
        allItems = itemsForFactory;
        _filterItemsByCategory();
      });
    } catch (e) {
      safeDebugPrint('[ERROR] loadItemsForCurrentFactory: $e');
    }
  }

  void _filterItemsByCategory() {
    if (selectedCategory == null || selectedCategory == 'all') {
      filteredItems = List.from(allItems);
    } else {
      filteredItems = allItems.where((item) => item['category'] == selectedCategory).toList();
    }
    
    if (filteredItems.isNotEmpty && (selectedItemId == null || !filteredItems.any((i) => i['id'] == selectedItemId))) {
      selectedItemId = filteredItems.first['id'] as String;
    } else if (filteredItems.isEmpty) {
      selectedItemId = null;
    }
  }

  Future<void> _loadInventory() async {
    if (selectedFactoryId == null) return;
    
    final snapshot = await FirebaseFirestore.instance
        .collection('factories')
        .doc(selectedFactoryId)
        .collection('inventory')
        .get();
    
    final stocks = <String, double>{};
    for (final doc in snapshot.docs) {
      final quantity = doc.data()['quantity'];
      stocks[doc.id] = _toDouble(quantity);
    }
    
    setState(() => itemStocks = stocks);
  }

  Future<void> _loadMovements() async {
    if (selectedCompanyId == null || selectedFactoryId == null) return;
    
    final queryKey = '${selectedCompanyId}_${selectedFactoryId}_${selectedItemId}_${startDate}_${endDate}_$sortOrder';
    if (_lastQueryKey == queryKey && !_isLoadingMovements) return;
    _lastQueryKey = queryKey;
    
    if (mounted) setState(() => _isLoadingMovements = true);
    
    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('companies')
          .doc(selectedCompanyId)
          .collection('stock_movements')
          .where('factoryId', isEqualTo: selectedFactoryId);
      
      if (selectedItemId != null && selectedItemId!.isNotEmpty) {
        query = query.where('itemId', isEqualTo: selectedItemId);
      }
      
      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!));
      }
      
      if (endDate != null) {
        final endOfDay = DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59);
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
      }
      
      query = query.orderBy('date', descending: sortOrder == 'desc');
      final snapshot = await query.get();
      
      final List<Map<String, dynamic>> movementsList = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        movementsList.add({
          'docId': doc.id,
          ...data,
        });
      }
      
      if (mounted) setState(() => _movements = movementsList);
      await _saveToCache();
    } catch (e) {
      safeDebugPrint('[ERROR] loadMovements: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMovements = false);
    }
  }

  // ==================== دوال التاريخ ====================
  void _setDateRange(DateTime newStart, DateTime newEnd) {
    setState(() { startDate = newStart; endDate = newEnd; });
    _loadMovements();
  }

  void _setLast7Days() => _setDateRange(DateTime.now().subtract(const Duration(days: 7)), DateTime.now());
  void _setLast30Days() => _setDateRange(DateTime.now().subtract(const Duration(days: 30)), DateTime.now());
  void _setLastMonth() => _setDateRange(DateTime.now().subtract(const Duration(days: 30)), DateTime.now());
  void _setLast3Months() => _setDateRange(DateTime.now().subtract(const Duration(days: 90)), DateTime.now());
  void _setLast6Months() => _setDateRange(DateTime.now().subtract(const Duration(days: 180)), DateTime.now());
  void _setLastYear() => _setDateRange(DateTime.now().subtract(const Duration(days: 365)), DateTime.now());
  void _setThisMonth() {
    final now = DateTime.now();
    _setDateRange(DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0));
  }
  void _setThisYear() {
    final now = DateTime.now();
    _setDateRange(DateTime(now.year, 1, 1), DateTime(now.year, 12, 31));
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => startDate = picked);
      _loadMovements();
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => endDate = picked);
      _loadMovements();
    }
  }

  void _showDateOptionsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: Text('select_month_year'.tr()),
              onTap: () { Navigator.pop(context); _selectMonthYear(context); },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_month),
              title: Text('select_year'.tr()),
              onTap: () { Navigator.pop(context); _selectYear(context); },
            ),
            ListTile(
              leading: const Icon(Icons.date_range),
              title: Text('select_custom_range'.tr()),
              onTap: () { Navigator.pop(context); _selectCustomDateRange(context); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectMonthYear(BuildContext context) async {
    final now = DateTime.now();
    DateTime picked = await showDatePicker(
      context: context,
      initialDate: DateTime(startDate?.year ?? now.year, startDate?.month ?? now.month),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    ) ?? now;
    final start = DateTime(picked.year, picked.month, 1);
    final end = DateTime(picked.year, picked.month + 1, 0);
    _setDateRange(start, end);
  }

  Future<void> _selectYear(BuildContext context) async {
    final now = DateTime.now();
    final int? year = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('select_year'.tr()),
        content: SizedBox(
          height: 200,
          width: 200,
          child: YearPicker(
            selectedDate: DateTime(startDate?.year ?? now.year, 1, 1),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            onChanged: (date) => Navigator.pop(ctx, date.year),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('cancel'.tr()))],
      ),
    );
    if (year != null) _setDateRange(DateTime(year, 1, 1), DateTime(year, 12, 31));
  }

  // أضف هذه الدالة في الـ State
DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}


  Future<void> _selectCustomDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: startDate ?? DateTime.now().subtract(const Duration(days: 30)),
        end: endDate ?? DateTime.now(),
      ),
    );
    if (picked != null) _setDateRange(picked.start, picked.end);
  }

  String _formatDate(DateTime date) => '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

  Widget _buildQuickDateButton(String labelKey, VoidCallback onPressed) => ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: Colors.grey[200],
      foregroundColor: Colors.black87,
    ),
    child: Text(labelKey.tr(), style: const TextStyle(fontSize: 11)),
  );

  // ==================== عرض الحركات ====================
  Widget _buildMovementsList() {
    if (_movements.isEmpty && !_isLoadingMovements && !_isLoadingFirstTime) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('no_movements'.tr()),
            const SizedBox(height: 8),
            Text('try_changing_filters'.tr(), style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // تجميع الحركات حسب المنتج
    final Map<String, List<Map<String, dynamic>>> groupedMovements = {};
    for (final m in _movements) {
      final itemId = m['itemId']?.toString() ?? '';
      final quantity = _toDouble(m['quantity']);
      final type = m['type']?.toString() ?? 'unknown';
      final date = _parseDate(m['date']) ?? DateTime.now();
      //final date = (m['date'] as Timestamp?)?.toDate() ?? DateTime.now();
      final info = MovementUtils.getMovementTypeInfo(type, quantity);
      
      groupedMovements.putIfAbsent(itemId, () => []).add({
        'date': date,
        'in': _toDouble(info['in']),
        'out': _toDouble(info['out']),
        'type_text': info['type_text'],
      });
    }

    return RefreshIndicator(
      onRefresh: _loadMovements,
      child: ListView.builder(
        itemCount: groupedMovements.length,
        itemBuilder: (context, index) {
          final itemId = groupedMovements.keys.elementAt(index);
          final movements = groupedMovements[itemId]!;
          final itemName = itemNames[itemId] ?? 'unknown_product'.tr();
          final currentStock = itemStocks[itemId] ?? 0.0;

          final item = allItems.firstWhere((i) => i['id'] == itemId, orElse: () => {'category': 'raw_material'});
          final itemCategory = item['category'] ?? 'raw_material';
          final categoryText = _isArabic
              ? (itemCategory == 'raw_material' ? 'مواد خام' : 'مواد تعبئة وتغليف')
              : (itemCategory == 'raw_material' ? 'Raw Material' : 'Packaging Material');

          movements.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
          
          double netMovement = 0;
          for (final m in movements) {
            netMovement += (_toDouble(m['in']) - _toDouble(m['out']));
          }
          
          double openingBalance = currentStock - netMovement;
          double runningBalance = openingBalance;
          
          final List<Map<String, dynamic>> movementsWithBalance = [];
          for (final m in movements) {
            runningBalance = runningBalance + _toDouble(m['in']) - _toDouble(m['out']);
            movementsWithBalance.add({...m, 'balance': runningBalance});
          }
          
          final displayMovements = sortOrder == 'desc' ? movementsWithBalance.reversed.toList() : movementsWithBalance;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 4),
                        Text(
                          categoryText,
                          style: TextStyle(
                            fontSize: 12,
                            color: itemCategory == 'raw_material' ? Colors.blue.shade700 : Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildBalanceColumn('opening_balance'.tr(), openingBalance, Colors.blue),
                            _buildBalanceColumn('closing_balance'.tr(), runningBalance, Colors.green),
                            _buildBalanceColumn('current_stock'.tr(), currentStock, Colors.orange),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 16,
                      columns: [
                        const DataColumn(label: Text('#')),
                        DataColumn(label: Text('date'.tr())),
                        DataColumn(label: Text('movement_type'.tr())),
                        DataColumn(label: Text('incoming'.tr())),
                        DataColumn(label: Text('outgoing'.tr())),
                        DataColumn(label: Text('balance'.tr())),
                      ],
                      rows: List.generate(displayMovements.length, (i) {
                        final m = displayMovements[i];
                        final inVal = _toDouble(m['in']);
                        final outVal = _toDouble(m['out']);
                        final balanceVal = _toDouble(m['balance']);
                        return DataRow(cells: [
                          DataCell(Text((i + 1).toString())),
                          DataCell(Text(_formatDate(m['date'] as DateTime))),
                          DataCell(Text(m['type_text'] as String)),
                          DataCell(Text(inVal > 0 ? inVal.toStringAsFixed(2) : '-')),
                          DataCell(Text(outVal > 0 ? outVal.toStringAsFixed(2) : '-')),
                          DataCell(Text(balanceVal.toStringAsFixed(2))),
                        ]);
                      }),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceColumn(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(value.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
      ],
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isArabicNow = context.locale.languageCode == 'ar';
    if (_isArabic != isArabicNow) {
      _isArabic = isArabicNow;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    _isArabic = context.locale.languageCode == 'ar';
    
    if (_isLoadingFirstTime) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return AppScaffold(
      title: 'stock_movements_title'.tr(),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[100],
            child: Column(
              children: [
                // الصف 1: الشركة والمصنع
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedCompanyId,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: 'company'.tr(), border: const OutlineInputBorder()),
                        items: companies.map<DropdownMenuItem<String>>((c) {
                          return DropdownMenuItem<String>(
                            value: c['id'] as String,
                            child: Text(_isArabic ? c['nameAr'] as String : c['nameEn'] as String),
                          );
                        }).toList(),
                        onChanged: (val) async {
                          setState(() {
                            selectedCompanyId = val;
                            selectedFactoryId = null;
                            selectedItemId = null;
                            selectedCategory = null;
                            factories = [];
                            allItems = [];
                            filteredItems = [];
                            _movements = [];
                          });
                          if (val != null) {
                            await _loadFactories();
                            if (factories.isNotEmpty) {
                              selectedFactoryId = factories.first['id'] as String;
                              await _loadItemsForCurrentFactory();
                              await _loadInventory();
                              await _loadMovements();
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedFactoryId,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: 'factory'.tr(), border: const OutlineInputBorder()),
                        items: factories.map<DropdownMenuItem<String>>((f) {
                          return DropdownMenuItem<String>(
                            value: f['id'] as String,
                            child: Text(_isArabic ? f['nameAr'] as String : f['nameEn'] as String),
                          );
                        }).toList(),
                        onChanged: (val) async {
                          setState(() {
                            selectedFactoryId = val;
                            selectedItemId = null;
                            selectedCategory = null;
                            allItems = [];
                            filteredItems = [];
                            _movements = [];
                          });
                          if (val != null) {
                            await _loadItemsForCurrentFactory();
                            await _loadInventory();
                            await _loadMovements();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // الصف 2: الفئة والمنتج والترتيب
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: 'category'.tr(), border: const OutlineInputBorder()),
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(value: null, child: Text('all')),
                          DropdownMenuItem<String>(value: 'raw_material', child: Text('raw_material'.tr())),
                          DropdownMenuItem<String>(value: 'packaging', child: Text('packaging'.tr())),
                        ],
                        onChanged: (val) {
                          setState(() => selectedCategory = val);
                          _filterItemsByCategory();
                          _loadMovements();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedItemId,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: 'product'.tr(), border: const OutlineInputBorder()),
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(value: null, child: Text('all')),
                          ...filteredItems.map<DropdownMenuItem<String>>((i) {
                            return DropdownMenuItem<String>(
                              value: i['id'] as String,
                              child: Text(_isArabic ? i['nameAr'] as String : i['nameEn'] as String),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() => selectedItemId = val);
                          _loadMovements();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: sortOrder,
                        items: const [
                          DropdownMenuItem<String>(value: 'desc', child: Text('desc')),
                          DropdownMenuItem<String>(value: 'asc', child: Text('asc')),
                        ],
                        onChanged: (val) {
                          setState(() => sortOrder = val!);
                          _loadMovements();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // الصف 3: التواريخ
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _selectStartDate(context),
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(startDate != null ? _formatDate(startDate!) : 'start_date'.tr()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _selectEndDate(context),
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(endDate != null ? _formatDate(endDate!) : 'end_date'.tr()),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.tune),
                          onPressed: () => _showDateOptionsDialog(context),
                          tooltip: 'advanced_options'.tr(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildQuickDateButton('last_7_days', _setLast7Days),
                          _buildQuickDateButton('last_30_days', _setLast30Days),
                          _buildQuickDateButton('last_month', _setLastMonth),
                          _buildQuickDateButton('last_3_months', _setLast3Months),
                          _buildQuickDateButton('last_6_months', _setLast6Months),
                          _buildQuickDateButton('last_year', _setLastYear),
                          _buildQuickDateButton('this_month', _setThisMonth),
                          _buildQuickDateButton('this_year', _setThisYear),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // زر التحديث
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoadingMovements ? null : _loadMovements,
                        icon: _isLoadingMovements
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh),
                        label: Text(_isLoadingMovements ? 'refreshing'.tr() : 'refresh'.tr()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingMovements && _movements.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _buildMovementsList(),
          ),
        ],
      ),
    );
  }
}

