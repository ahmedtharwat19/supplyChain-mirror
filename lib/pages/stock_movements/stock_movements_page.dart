// lib/pages/stock_movements/stock_movements_page.dart
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/pages/stock_movements/services/movement_utils.dart';
import 'package:puresip_purchasing/utils/user_local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Hive وConnectivity
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:puresip_purchasing/models/stock_movement.dart';
import 'package:puresip_purchasing/models/cached_data.dart';

class StockMovementsPage extends StatefulWidget {
  const StockMovementsPage({super.key});

  @override
  State<StockMovementsPage> createState() => _StockMovementsPageState();
}

class _StockMovementsPageState extends State<StockMovementsPage> {
  String? selectedCompanyId;
  String? selectedFactoryId;
  String? selectedItemId;
  String? selectedCategory;
  DateTime? startDate;
  DateTime? endDate;
  String sortOrder = 'desc';

  List<String> userCompanyIds = [];
  List<Map<String, dynamic>> companies = [];
  List<Map<String, dynamic>> factories = [];
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> allItems = [];
  Map<String, double> itemStocks = {};
  Map<String, String> itemNames = {};
  bool _isArabic = false;
  bool isLoading = true;
  bool isExporting = false;

  // صناديق Hive
  late Box<CachedData> _cacheBox;
  late Box<StockMovement> _movementsBox;

  // متغيرات المزامنة والاتصال
  bool _isSyncing = false;
  bool _isOnline = true;
  DateTime? _lastSyncTime;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  List<StockMovement> _localMovements = [];

  @override
  void initState() {
    super.initState();
    _initializeApp();

    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, now.day - 30);
    endDate = now;
  }

  Future<void> _initializeApp() async {
    await _initializeHive();

    // للويب: افترض الاتصال دائماً
    if (kIsWeb) {
      _isOnline = true;
    }

    await _initializePage();

    // للويب فقط: لا تستمع لتغيرات الاتصال
    if (!kIsWeb) {
      _startConnectivityListener();
    }
  }

  Future<void> _initializeHive() async {
    try {
      await Hive.initFlutter();

      // تسجيل adapters
      Hive.registerAdapter(StockMovementAdapter());
      Hive.registerAdapter(CachedDataAdapter());

      // فتح الصناديق
      _cacheBox = await Hive.openBox<CachedData>('app_cache');
      _movementsBox = await Hive.openBox<StockMovement>('stock_movements');

      safeDebugPrint('[HIVE] Hive initialized successfully');
    } catch (e) {
      safeDebugPrint('[HIVE ERROR] Initialization failed: $e');
    }
  }

  void _startConnectivityListener() {
    // للويب: لا حاجة لـ Connectivity
    if (kIsWeb) {
      _isOnline = true;
      safeDebugPrint('[CONNECTIVITY] Web - online by default');
      return;
    }

    // للتطبيقات فقط
    try {
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
        (List<ConnectivityResult> results) {
          final wasOnline = _isOnline;
          _isOnline =
              results.isNotEmpty && results[0] != ConnectivityResult.none;

          safeDebugPrint(
              '[CONNECTIVITY] Connection changed: $results, isOnline: $_isOnline');

          if (!wasOnline && _isOnline) {
            safeDebugPrint('[CONNECTIVITY] Back online, starting sync...');
            _syncWithFirebase();
          }

          if (mounted) {
            setState(() {});
          }
        },
        onError: (error) {
          safeDebugPrint('[CONNECTIVITY ERROR] $error');
          _isOnline = true; // افترض الاتصال في حالة الخطأ
          if (mounted) {
            setState(() {});
          }
        },
      );
    } catch (e) {
      safeDebugPrint('[CONNECTIVITY INIT ERROR] $e');
      _isOnline = true;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _initializePage() async {
    setState(() => isLoading = true);

    // تحميل من Hive أولاً (سريع)
    await _loadFromHive();

    // ثم المزامنة مع Firebase في الخلفية
    if (_isOnline) {
      _syncWithFirebase().then((_) {
        if (mounted) {
          setState(() => isLoading = false);
        }
      }).catchError((e) {
        safeDebugPrint('[INIT ERROR] Sync failed: $e');
        if (mounted) {
          setState(() => isLoading = false);
        }
      });
    } else {
      setState(() => isLoading = false);
    }

    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, now.day - 30);
    endDate = now;
  }

  // تحميل البيانات من Hive
  Future<void> _loadFromHive() async {
    try {
      safeDebugPrint('[HIVE] Starting to load data from Hive...');

      // تحميل الشركات
      await _loadCompaniesFromHive();

      // تحميل أسماء العناصر
      await _loadItemNamesFromHive();

      // تحميل المصانع إذا كانت هناك شركة محددة
      if (selectedCompanyId != null) {
        await _loadFactoriesFromHive();
      }

      safeDebugPrint('[HIVE] Successfully loaded data from Hive');
    } catch (e) {
      safeDebugPrint('[HIVE ERROR] Loading from Hive failed: $e');
    }
  }

// دالة محسنة لتحميل الشركات من Hive
  Future<void> _loadCompaniesFromHive() async {
    try {
      final cachedCompanies = _cacheBox.get('companies');
      if (cachedCompanies != null) {
        final companiesData = _convertHiveDataToList(cachedCompanies.data);
        setState(() {
          companies = companiesData;
          if (companies.isNotEmpty && selectedCompanyId == null) {
            selectedCompanyId = companies.first['id']?.toString();
          }
        });
        safeDebugPrint(
            '[HIVE] Loaded ${companies.length} companies from cache');
      }
    } catch (e) {
      safeDebugPrint('[HIVE ERROR] Loading companies: $e');
    }
  }

// دالة محسنة لتحميل المصانع من Hive
  Future<void> _loadFactoriesFromHive() async {
    if (selectedCompanyId == null) return;

    try {
      final cachedFactories = _cacheBox.get('factories_$selectedCompanyId');
      if (cachedFactories != null) {
        final factoriesData = _convertHiveDataToList(cachedFactories.data);
        setState(() {
          factories = factoriesData;
          if (factories.isNotEmpty && selectedFactoryId == null) {
            selectedFactoryId = factories.first['id']?.toString();
          }
        });
        safeDebugPrint(
            '[HIVE] Loaded ${factories.length} factories from cache');
      }
    } catch (e) {
      safeDebugPrint('[HIVE ERROR] Loading factories: $e');
    }
  }

// دالة محسنة لتحميل أسماء العناصر من Hive
  Future<void> _loadItemNamesFromHive() async {
    try {
      final cachedItems = _cacheBox.get('item_names');
      if (cachedItems != null) {
        final itemNamesData = _convertHiveDataToMap(cachedItems.data);
        setState(() {
          itemNames = itemNamesData
              .map((key, value) => MapEntry(key.toString(), value.toString()));
        });
        safeDebugPrint(
            '[HIVE] Loaded ${itemNames.length} item names from cache');
      }
    } catch (e) {
      safeDebugPrint('[HIVE ERROR] Loading item names: $e');
    }
  }

// دالة محسنة لتحميل المخزون من Hive
  Future<void> _loadInventoryFromHive() async {
    if (selectedFactoryId == null) return;

    try {
      final cachedInventory = _cacheBox.get('inventory_$selectedFactoryId');
      if (cachedInventory != null) {
        final inventoryData = _convertHiveDataToMap(cachedInventory.data);
        setState(() {
          // تحويل القيم إلى double بشكل آمن
          itemStocks = inventoryData.map((key, value) {
            final doubleValue = value is double
                ? value
                : value is int
                    ? value.toDouble()
                    : double.tryParse(value.toString()) ?? 0.0;
            return MapEntry(key.toString(), doubleValue);
          });
        });
        safeDebugPrint('[HIVE] Loaded inventory for $selectedFactoryId');
      }
    } catch (e) {
      safeDebugPrint('[HIVE ERROR] Loading inventory: $e');
    }
  }

  // دالة مساعدة لتحويل بيانات Hive إلى List<Map<String, dynamic>>
  List<Map<String, dynamic>> _convertHiveDataToList(dynamic data) {
    try {
      if (data is List) {
        return data.whereType<Map>().map((item) {
          final convertedMap = <String, dynamic>{};
          item.forEach((key, value) {
            convertedMap[key.toString()] = value;
          });
          return convertedMap;
        }).toList();
      }
      return [];
    } catch (e) {
      safeDebugPrint('[HIVE ERROR] Converting data to list: $e');
      return [];
    }
  }

// دالة مساعدة محسنة لتحويل بيانات Hive إلى Map<String, dynamic>
  Map<String, dynamic> _convertHiveDataToMap(dynamic data) {
    try {
      if (data is Map) {
        final convertedMap = <String, dynamic>{};
        data.forEach((key, value) {
          convertedMap[key.toString()] = value;
        });
        return convertedMap;
      }
      return {};
    } catch (e) {
      safeDebugPrint('[HIVE ERROR] Converting data to map: $e');
      return {};
    }
  }

  // المزامنة مع Firebase
  Future<void> _syncWithFirebase() async {
    if (_isSyncing || !_isOnline) return;

    setState(() => _isSyncing = true);

    try {
      safeDebugPrint('[SYNC] Starting sync with Firebase...');

      // 1. جلب أحدث البيانات من Firebase
      await _fetchLatestFromFirebase();

      // 2. تحديث Hive بالبيانات الجديدة
      await _updateHiveWithFirebaseData();

      safeDebugPrint('[SYNC] Sync completed successfully at ${DateTime.now()}');
    } catch (e) {
      safeDebugPrint('[SYNC ERROR] Sync failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_getTranslation('sync_failed', 'Sync failed'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _lastSyncTime = DateTime.now();
        });
      }
    }
  }

  Future<void> _fetchLatestFromFirebase() async {
    safeDebugPrint('[SYNC] Fetching latest data from Firebase...');

    await _loadUserCompaniesFromFirestore();
    await _loadItemNames();

    if (selectedCompanyId != null) {
      await _loadCompaniesWithMovements();
      if (selectedFactoryId != null) {
        await _loadFactoriesWithMovements();
        await _loadItemsWithMovements();
        await _loadInventory();
        await _loadMovementsFromFirebase();
      }
    }
  }

  Future<void> _loadMovementsFromFirebase() async {
    if (selectedCompanyId == null || selectedFactoryId == null) return;

    try {
      final query = _buildMovementsQuery();
      safeDebugPrint('[SYNC] Executing movements query...');

      final snapshot = await query.get();
      safeDebugPrint(
          '[SYNC] Found ${snapshot.docs.length} movements in Firebase');

      if (snapshot.docs.isNotEmpty) {
        final movements = snapshot.docs.map((doc) {
          return StockMovement.fromFirestore(doc);
        }).toList();

        // حفظ الحركات في Hive
        for (final movement in movements) {
          if (movement.id != null && movement.id!.isNotEmpty) {
            await _movementsBox.put(movement.id, movement);
          }
        }

        safeDebugPrint('[SYNC] Saved ${movements.length} movements to Hive');

        // تحديث الحركات المحلية
        setState(() {
          _localMovements = movements;
        });
      } else {
        safeDebugPrint('[SYNC] No movements found for the current filters');
      }
    } catch (e) {
      safeDebugPrint('[SYNC ERROR] Loading movements from Firebase: $e');
    }
  }

  Future<void> _updateHiveWithFirebaseData() async {
    // حفظ الشركات
    if (companies.isNotEmpty) {
      await _cacheBox.put(
          'companies',
          CachedData(
            key: 'companies',
            data: companies,
            lastUpdated: DateTime.now(),
            dataType: 'companies',
          ));
    }

    // حفظ أسماء العناصر
    if (itemNames.isNotEmpty) {
      await _cacheBox.put(
          'item_names',
          CachedData(
            key: 'item_names',
            data: itemNames,
            lastUpdated: DateTime.now(),
            dataType: 'items',
          ));
    }

    // حفظ المصانع لكل شركة
    for (final company in companies) {
      final companyFactories = await _getFactoriesForCompany(company['id']);
      if (companyFactories.isNotEmpty) {
        await _cacheBox.put(
            'factories_${company['id']}',
            CachedData(
              key: 'factories_${company['id']}',
              data: companyFactories,
              lastUpdated: DateTime.now(),
              dataType: 'factories',
            ));
      }
    }

    // حفظ المخزون
    if (selectedFactoryId != null && itemStocks.isNotEmpty) {
      await _cacheBox.put(
          'inventory_$selectedFactoryId',
          CachedData(
            key: 'inventory_$selectedFactoryId',
            data: itemStocks,
            lastUpdated: DateTime.now(),
            dataType: 'inventory',
          ));
    }
  }

  Future<List<Map<String, dynamic>>> _getFactoriesForCompany(
      String companyId) async {
    try {
      final facSnaps = await FirebaseFirestore.instance
          .collection('factories')
          .where('companyIds', arrayContains: companyId)
          .get();

      return facSnaps.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'nameAr': data['nameAr'] ?? doc.id,
          'nameEn': data['nameEn'] ?? doc.id,
        };
      }).toList();
    } catch (e) {
      safeDebugPrint('[ERROR] Getting factories for company: $e');
      return [];
    }
  }

  // الدوال الحالية من الكود الأصلي
  Future<void> _loadUserCompaniesFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        final companies = (data['companyIds'] as List?)?.cast<String>() ?? [];

        setState(() {
          userCompanyIds = companies;
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('userCompanyIds', companies);

        if (companies.isNotEmpty) {
          await _loadCompaniesWithMovements();
        }
      }
    } catch (e) {
      safeDebugPrint('[ERROR] Failed to load companies from Firestore: $e');
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy/MM/dd').format(date);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isArabicNow = context.locale.languageCode == 'ar';
    if (_isArabic != isArabicNow) {
      _isArabic = isArabicNow;
      _loadItemNames();
      setState(() {});
    }
  }

  Future<void> _loadCompaniesWithMovements() async {
    safeDebugPrint(
        '[DEBUG] Starting _loadCompaniesWithMovements with userCompanyIds: $userCompanyIds');

    if (userCompanyIds.isEmpty) {
      safeDebugPrint('[DEBUG] No company IDs available');
      await _loadUserCompaniesFromFirestore();

      if (userCompanyIds.isEmpty) {
        safeDebugPrint('[DEBUG] Still no company IDs after retry');
        return;
      }
    }

    try {
      final companiesWithMovements = <Map<String, dynamic>>[];

      for (final companyId in userCompanyIds) {
        final movementsSnapshot = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('stock_movements')
            .limit(1)
            .get();

        if (movementsSnapshot.docs.isNotEmpty) {
          final companyDoc = await FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .get();

          if (companyDoc.exists) {
            final companyData = companyDoc.data()!;
            companiesWithMovements.add({
              'id': companyId,
              'nameAr': companyData['nameAr'] ?? companyId,
              'nameEn': companyData['nameEn'] ?? companyId,
            });
          }
        }
      }

      setState(() {
        companies = companiesWithMovements;
        selectedCompanyId = companies.isNotEmpty ? companies[0]['id'] : null;
      });

      if (selectedCompanyId != null) {
        await _loadFactoriesWithMovements();
      }
    } catch (e, stack) {
      safeDebugPrint('[ERROR] Failed to load companies with movements: $e');
      safeDebugPrint(stack.toString());
    }
  }

  Future<void> _loadFactoriesWithMovements() async {
    if (selectedCompanyId == null) return;

    try {
      final factoriesWithMovements = <Map<String, dynamic>>[];

      final facSnaps = await FirebaseFirestore.instance
          .collection('factories')
          .where('companyIds', arrayContains: selectedCompanyId)
          .get();

      for (final factoryDoc in facSnaps.docs) {
        final factoryId = factoryDoc.id;

        final movementsSnapshot = await FirebaseFirestore.instance
            .collection('companies')
            .doc(selectedCompanyId)
            .collection('stock_movements')
            .where('factoryId', isEqualTo: factoryId)
            .limit(1)
            .get();

        if (movementsSnapshot.docs.isNotEmpty) {
          final factoryData = factoryDoc.data();
          factoriesWithMovements.add({
            'id': factoryId,
            'nameAr': factoryData['nameAr'] ?? factoryId,
            'nameEn': factoryData['nameEn'] ?? factoryId,
          });
        }
      }

      setState(() {
        factories = factoriesWithMovements;
        selectedFactoryId = factories.isNotEmpty ? factories[0]['id'] : null;
        selectedCategory = null;
        selectedItemId = null;
        items = [];
        allItems = [];
      });

      if (selectedFactoryId != null) {
        await _loadItemsWithMovements();
      }
    } catch (e) {
      safeDebugPrint('[ERROR] Failed to load factories with movements: $e');
    }
  }

  Future<void> _loadItemsWithMovements() async {
    if (selectedCompanyId == null || selectedFactoryId == null) return;

    try {
      final itemsWithMovements = <Map<String, dynamic>>[];

      final movementsSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(selectedCompanyId)
          .collection('stock_movements')
          .where('factoryId', isEqualTo: selectedFactoryId)
          .get();

      final itemIds = <String>{};
      for (final movement in movementsSnapshot.docs) {
        final itemId = movement.data()['itemId']?.toString();
        if (itemId != null) {
          itemIds.add(itemId);
        }
      }

      for (final itemId in itemIds) {
        try {
          final itemDoc = await FirebaseFirestore.instance
              .collection('items')
              .doc(itemId)
              .get();

          if (itemDoc.exists) {
            final itemData = itemDoc.data()!;
            final itemCategory =
                itemData['category']?.toString() ?? 'raw_material';

            itemsWithMovements.add({
              'id': itemId,
              'nameAr': itemData['nameAr'] ?? itemId,
              'nameEn': itemData['nameEn'] ?? itemId,
              'category': itemCategory,
            });
          }
        } catch (e) {
          safeDebugPrint('[ERROR] Loading item $itemId: $e');
        }
      }

      setState(() {
        allItems = itemsWithMovements;
        _filterItemsByCategory();
      });

      await _loadInventory();
    } catch (e) {
      safeDebugPrint('[ERROR] Failed to load items with movements: $e');
    }
  }

  void _filterItemsByCategory() {
    if (selectedCategory == null || selectedCategory == 'all') {
      setState(() {
        items = List.from(allItems);
      });
    } else {
      setState(() {
        items = allItems
            .where((item) => item['category'] == selectedCategory)
            .toList();
      });
    }

    if (items.isNotEmpty) {
      setState(() {
        selectedItemId = items[0]['id'];
      });
    } else {
      setState(() {
        selectedItemId = null;
      });
    }
  }

  Future<void> _loadInventory() async {
    if (selectedFactoryId == null) return;

    try {
      final invSnap = await FirebaseFirestore.instance
          .collection('factories')
          .doc(selectedFactoryId!)
          .collection('inventory')
          .get();

      final stocks = <String, double>{};
      for (var doc in invSnap.docs) {
        try {
          final data = doc.data();
          final quantity = data['quantity'];
          stocks[doc.id] = (quantity is double
              ? quantity
              : (quantity is num ? quantity.toDouble() : 0));
        } catch (e) {
          safeDebugPrint('[ERROR] Processing inventory item ${doc.id}: $e');
        }
      }
      setState(() => itemStocks = stocks);
    } catch (e) {
      safeDebugPrint('[ERROR] Loading inventory: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_loading_inventory'.tr())),
        );
      }
    }
  }

  Future<void> _loadItemNames() async {
    try {
      final cachedNames = await UserLocalStorage.getItemNames();
      if (cachedNames.isNotEmpty) {
        setState(() {
          itemNames = cachedNames;
        });
        return;
      }

      final itemsSnap = await FirebaseFirestore.instance
          .collection('items')
          .get()
          .timeout(const Duration(seconds: 30));

      final names = <String, String>{};
      for (var doc in itemsSnap.docs) {
        final data = doc.data();
        names[doc.id] = _isArabic
            ? (data['nameAr'] ?? 'Unknown'.tr())
            : (data['nameEn'] ?? 'Unknown'.tr());
      }

      await UserLocalStorage.saveItemNames(names);

      setState(() {
        itemNames = names;
      });
    } catch (e) {
      safeDebugPrint('[ERROR] Loading item names: $e');
      final cachedNames = await UserLocalStorage.getItemNames();
      setState(() {
        itemNames = cachedNames;
      });
    }
  }

  Query<Map<String, dynamic>> _buildMovementsQuery() {
    if (selectedCompanyId == null || selectedFactoryId == null) {
      safeDebugPrint('[QUERY] Company or Factory not selected');
      return FirebaseFirestore.instance.collection('dummy').limit(0);
    }

    safeDebugPrint(
        '[QUERY] Building query for company: $selectedCompanyId, factory: $selectedFactoryId');

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('companies')
        .doc(selectedCompanyId!)
        .collection('stock_movements')
        .where('factoryId', isEqualTo: selectedFactoryId);

    if (selectedItemId != null) {
      safeDebugPrint('[QUERY] Filtering by item: $selectedItemId');
      query = query.where('itemId', isEqualTo: selectedItemId);
    }

    if (startDate != null) {
      safeDebugPrint('[QUERY] Start date: $startDate');
      query = query.where('date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!));
    }
    if (endDate != null) {
      final endOfDay =
          DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59);
      safeDebugPrint('[QUERY] End date: $endOfDay');
      query = query.where('date',
          isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
    }

    query = query.orderBy('date', descending: sortOrder == 'desc');

    return query;
  }

  Widget _buildMovementsTable(List<QueryDocumentSnapshot> docs) {
    final movements =
        docs.map((doc) => StockMovement.fromFirestore(doc)).toList();
    return _buildMovementsTableFromList(movements);
  }

  Widget _buildMovementsTableFromList(List<StockMovement> movements) {
    final Map<String, List<Map<String, dynamic>>> itemMovements = {};

    for (var movement in movements) {
      try {
        final movementInfo =
            MovementUtils.getMovementTypeInfo(movement.type, movement.quantity);

        if (!itemMovements.containsKey(movement.itemId)) {
          itemMovements[movement.itemId] = [];
        }

        itemMovements[movement.itemId]!.add({
          'date': movement.dateAsDateTime,
          'type': movement.type,
          'in': movementInfo['in'],
          'out': movementInfo['out'],
          'type_text': movementInfo['type_text'],
          'quantity': movement.quantity,
          'documentId': movement.id,
        });
      } catch (e) {
        safeDebugPrint('[ERROR] Processing movement: $e');
      }
    }

    if (!mounted) {
      return const SizedBox.shrink();
    }

    return ListView.separated(
      itemCount: itemMovements.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (!mounted) {
          return const SizedBox.shrink();
        }

        final itemId = itemMovements.keys.elementAt(index);
        final movements = itemMovements[itemId]!;
        final itemName = itemNames[itemId] ?? 'Unknown Item'.tr();
        final currentStock = itemStocks[itemId] ?? 0;

        movements.sort((a, b) => a['date'].compareTo(b['date']));

        double netMovement = 0;
        for (var movement in movements) {
          netMovement += movement['in'] - movement['out'];
        }

        double openingBalance = currentStock - netMovement;

        double runningBalance = openingBalance;
        final movementsWithBalance = [];

        for (var movement in movements) {
          runningBalance = runningBalance + movement['in'] - movement['out'];
          movementsWithBalance.add({
            ...movement,
            'balance': runningBalance,
          });
        }

        final closingBalance = runningBalance;

        final displayMovements = sortOrder == 'desc'
            ? movementsWithBalance.reversed.toList()
            : movementsWithBalance;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // رأس البطاقة - معلومات الصنف
                _buildItemHeader(
                    itemName, openingBalance, closingBalance, currentStock),
                const SizedBox(height: 16),

                // الجدول المحسن
                _buildEnhancedTable(
                    displayMovements.cast<Map<String, dynamic>>()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemHeader(String itemName, double openingBalance,
      double closingBalance, double currentStock) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // اسم الصنف
          Expanded(
            child: Text(
              '${'item'.tr()}: $itemName',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // الأرصدة
          Row(
            children: [
              _buildBalanceItem(
                  'opening_balance'.tr(), openingBalance, Colors.blue),
              const SizedBox(width: 16),
              _buildBalanceItem(
                  'closing_balance'.tr(), closingBalance, Colors.green),
              const SizedBox(width: 16),
              _buildBalanceItem(
                  'current_stock'.tr(), currentStock, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceItem(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedTable(List<Map<String, dynamic>> movements) {
    // إنشاء ScrollController منفصل للجدول
    final ScrollController scrollController = ScrollController();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Scrollbar(
        controller: scrollController, // إضافة controller هنا
        thumbVisibility: true, // لجعل Scrollbar مرئي دائماً
        child: SingleChildScrollView(
          controller: scrollController, // ربط نفس الـ controller
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width - 32,
            ),
            child: DataTable(
              columnSpacing: 20,
              horizontalMargin: 16,
              dataRowMinHeight: 50,
              dataRowMaxHeight: 50,
              headingRowHeight: 50,
              headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
              columns: [
                DataColumn(
                  label: Container(
                    width: 60,
                    alignment: Alignment.center,
                    child: Text(
                      '#',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                DataColumn(
                  label: Container(
                    width: 120,
                    alignment: Alignment.center,
                    child: Text(
                      'date'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                DataColumn(
                  label: Container(
                    width: 150,
                    alignment: Alignment.center,
                    child: Text(
                      'movement_type'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                DataColumn(
                  label: Container(
                    width: 100,
                    alignment: Alignment.center,
                    child: Text(
                      'in'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Container(
                    width: 100,
                    alignment: Alignment.center,
                    child: Text(
                      'out'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Container(
                    width: 120,
                    alignment: Alignment.center,
                    child: Text(
                      'balance'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                  numeric: true,
                ),
              ],
              rows: List<DataRow>.generate(movements.length, (index) {
                final movement = movements[index];
                final bool isEven = index % 2 == 0;

                // استخراج القيم بشكل آمن
                final date = movement['date'] as DateTime? ?? DateTime.now();
                final typeText = movement['type_text']?.toString() ?? 'Unknown';
                final inValue = (movement['in'] as num?)?.toDouble() ?? 0.0;
                final outValue = (movement['out'] as num?)?.toDouble() ?? 0.0;
                final balance =
                    (movement['balance'] as num?)?.toDouble() ?? 0.0;

                return DataRow(
                  color: WidgetStateProperty.all(
                    isEven ? Colors.white : Colors.grey[50]!,
                  ),
                  cells: [
                    DataCell(
                      Container(
                        width: 60,
                        alignment: Alignment.center,
                        child: Text(
                          (index + 1).toString(),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        width: 120,
                        alignment: Alignment.center,
                        child: Text(
                          _formatDate(date),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        width: 150,
                        alignment: Alignment.center,
                        child: Tooltip(
                          message: typeText,
                          child: Text(
                            typeText,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        width: 100,
                        alignment: Alignment.center,
                        child: Text(
                          inValue > 0 ? inValue.toStringAsFixed(2) : '-',
                          style: TextStyle(
                            color:
                                inValue > 0 ? Colors.green[700] : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        width: 100,
                        alignment: Alignment.center,
                        child: Text(
                          outValue > 0 ? outValue.toStringAsFixed(2) : '-',
                          style: TextStyle(
                            color: outValue > 0 ? Colors.red[700] : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        width: 120,
                        alignment: Alignment.center,
                        child: Text(
                          balance.toStringAsFixed(2),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: balance >= 0
                                ? Colors.blue[700]
                                : Colors.red[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  String _getTranslation(String key, String fallback) {
    try {
      final translation = key.tr();
      return translation == key ? fallback : translation;
    } catch (e) {
      return fallback;
    }
  }

  Widget _buildSyncStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _isSyncing
          ? Colors.blue[50]
          : _isOnline
              ? Colors.green[50]
              : Colors.orange[50],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _isSyncing
                    ? Icons.sync
                    : _isOnline
                        ? Icons.wifi
                        : Icons.wifi_off,
                size: 16,
                color: _isSyncing
                    ? Colors.blue
                    : _isOnline
                        ? Colors.green
                        : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                _isSyncing
                    ? _getTranslation('syncing', 'Syncing...')
                    : _isOnline
                        ? _getTranslation('online', 'Online')
                        : _getTranslation('offline', 'Offline'),
                style: TextStyle(
                  fontSize: 12,
                  color: _isSyncing
                      ? Colors.blue
                      : _isOnline
                          ? Colors.green
                          : Colors.orange,
                ),
              ),
            ],
          ),
          if (_lastSyncTime != null && !_isSyncing)
            Text(
              '${_getTranslation('last_sync', 'Last sync')} ${DateFormat('HH:mm').format(_lastSyncTime!)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          IconButton(
            icon: const Icon(Icons.sync, size: 18),
            onPressed: _isSyncing || !_isOnline ? null : _syncWithFirebase,
            tooltip: _getTranslation('sync_now', 'Sync Now'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

// أضف هذا فوق الجدول في _buildMovementsTableFromList
/* Widget _buildSearchAndFilters() {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: 'search_movements'.tr(),
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              // تطبيق البحث
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: () {
            // عرض خيارات تصفية إضافية
          },
        ),
      ],
    ),
  );
}
 */
  Widget _buildOfflineMovements() {
    if (_localMovements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_getTranslation('offline_mode', 'Offline Mode')),
            const SizedBox(height: 8),
            Text(_getTranslation('no_cached_data', 'No cached data available')),
          ],
        ),
      );
    }

    return _buildMovementsTableFromList(_localMovements);
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? startDate! : endDate!,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<Map<String, dynamic>> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(
        labelText: label.tr(),
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('all'.tr()),
        ),
        ...items.map((item) {
          return DropdownMenuItem<String>(
            value: item['id'],
            child: Text(_isArabic ? item['nameAr'] : item['nameEn']),
          );
        }),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildFilterControls() {
    return Column(
      children: [
        // الصف الأول: الشركة والمصنع
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                label: 'select_company',
                value: selectedCompanyId,
                items: companies,
                onChanged: (val) async {
                  setState(() {
                    selectedCompanyId = val;
                    selectedFactoryId = null;
                    selectedItemId = null;
                    selectedCategory = null;
                    factories = [];
                    items = [];
                    allItems = [];
                  });
                  if (val != null) {
                    await _loadFactoriesFromHive();
                    if (_isOnline) await _loadFactoriesWithMovements();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDropdown(
                label: 'select_factory',
                value: selectedFactoryId,
                items: factories,
                onChanged: (val) async {
                  setState(() {
                    selectedFactoryId = val;
                    selectedItemId = null;
                    selectedCategory = null;
                    items = [];
                    allItems = [];
                  });
                  if (val != null) {
                    await _loadInventoryFromHive();
                    if (_isOnline) {
                      await _loadItemsWithMovements();
                      await _loadInventory();
                    }
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // باقي عناصر التحكم
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: selectedCategory,
                decoration: InputDecoration(
                  labelText: 'category'.tr(),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text('all_categories'.tr()),
                  ),
                  DropdownMenuItem<String>(
                    value: 'raw_material',
                    child: Text('raw_materials'.tr()),
                  ),
                  DropdownMenuItem<String>(
                    value: 'packaging',
                    child: Text('packaging'.tr()),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    selectedCategory = val;
                  });
                  _filterItemsByCategory();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDropdown(
                label: 'select_item',
                value: selectedItemId,
                items: items,
                onChanged: (val) => setState(() => selectedItemId = val),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<String>(
                isExpanded: true,
                value: sortOrder,
                items: [
                  DropdownMenuItem(
                    value: 'desc',
                    child: Text('newest_first'.tr()),
                  ),
                  DropdownMenuItem(
                    value: 'asc',
                    child: Text('oldest_first'.tr()),
                  ),
                ],
                onChanged: (val) => setState(() => sortOrder = val!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _selectDate(context, true),
                child: Text(
                  startDate != null
                      ? '${'from'.tr()} ${DateFormat('yyyy/MM/dd').format(startDate!)}'
                      : 'select_start_date'.tr(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _selectDate(context, false),
                child: Text(
                  endDate != null
                      ? '${'to'.tr()} ${DateFormat('yyyy/MM/dd').format(endDate!)}'
                      : 'select_end_date'.tr(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildMovementsContent() {
    if (!_isOnline) {
      // وضع Offline - استخدام بيانات Hive فقط
      return _buildOfflineMovements();
    } else {
      // وضع Online - استخدام Stream من Firebase
      return StreamBuilder<QuerySnapshot>(
        stream: _buildMovementsQuery().snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('error_loading_data'.tr()));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return _buildEmptyState();
          }

          return _buildMovementsTable(docs);
        },
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory_2, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('no_movements_found'.tr(),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('adjust_filters_or_try_again'.tr(), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('loading_data'.tr()),
            ],
          ),
        ),
      );
    }

    if (userCompanyIds.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('stock_movements'.tr())),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.business, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('no_companies_assigned'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('contact_admin_for_companies'.tr(),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return AppScaffold(
      title: 'stock_movements'.tr(),
      body: Column(
        children: [
          // شريط حالة المزامنة والاتصال
          _buildSyncStatusBar(),

          // محتوى الصفحة
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // عناصر التحكم في التصفية
                  _buildFilterControls(),

                  // الجدول
                  Expanded(
                    child: _buildMovementsContent(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _cacheBox.close();
    _movementsBox.close();
    super.dispose();
  }
}

/* // lib/pages/stock_movements/stock_movements_page.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:puresip_purchasing/utils/user_local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
//import 'package:flutter/system.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../stock_movements/services/movement_utils.dart';
import 'package:puresip_purchasing/debug_helper.dart';
// للويب فقط - استيراد مكتبات dart:html بشكل مشروط
import 'package:universal_html/html.dart' as html;

// استيراد حزم PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class StockMovementsPage extends StatefulWidget {
  const StockMovementsPage({super.key});

  @override
  State<StockMovementsPage> createState() => _StockMovementsPageState();
}

class _StockMovementsPageState extends State<StockMovementsPage> {
  String? selectedCompanyId;
  String? selectedFactoryId;
  String? selectedItemId;
  String? selectedCategory;
  DateTime? startDate;
  DateTime? endDate;
  String sortOrder = 'desc';

  List<String> userCompanyIds = [];
  List<Map<String, dynamic>> companies = [];
  List<Map<String, dynamic>> factories = [];
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> allItems = []; // تخزين جميع العناصر
  Map<String, double> itemStocks = {};
  Map<String, String> itemNames = {};
  bool _isArabic = false;
  bool isLoading = true;
  bool isExporting = false;

  // خطوط PDF
  pw.Font? _cachedCairoRegular;
  pw.Font? _cachedCairoBold;

@override
void initState() {
  super.initState();
  _initializePage();
  _loadUserCompaniesFromFirestore();
  _loadUserCompanyIds();

  final now = DateTime.now();
  startDate = DateTime(now.year, now.month, now.day - 30);
  endDate = now;

  // التحميل المسبق للبيانات
  _preloadData();
}

Future<void> _preloadData() async {
  try {
    // تحميل أسماء العناصر مسبقاً
    await _loadItemNames();
    
    // تحميل الشركات والمصانع مسبقاً
    if (userCompanyIds.isNotEmpty) {
      await _loadCompaniesWithMovements();
      if (selectedCompanyId != null) {
        await _loadFactoriesWithMovements();
        if (selectedFactoryId != null) {
          await _loadItemsWithMovements();
          await _loadInventory();
        }
      }
    }
    
    setState(() => isLoading = false);
  } catch (e) {
    safeDebugPrint('[ERROR] Preloading data failed: $e');
    setState(() => isLoading = false);
  }
}



  // دالة لتحميل خط Cairo Regular
  Future<pw.Font> _loadCairoRegular() async {
    if (_cachedCairoRegular != null) return _cachedCairoRegular!;

    try {
      final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      _cachedCairoRegular = pw.Font.ttf(fontData);
      return _cachedCairoRegular!;
    } catch (e) {
      safeDebugPrint('Error loading Cairo Regular font: $e');
      return pw.Font.courier();
    }
  }

  // دالة لتحميل خط Cairo Bold
  Future<pw.Font> _loadCairoBold() async {
    if (_cachedCairoBold != null) return _cachedCairoBold!;

    try {
      final fontData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
      _cachedCairoBold = pw.Font.ttf(fontData);
      return _cachedCairoBold!;
    } catch (e) {
      safeDebugPrint('Error loading Cairo Bold font: $e');
      return pw.Font.courierBold();
    }
  }

  Future<void> _loadUserCompaniesFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        final companies = (data['companyIds'] as List?)?.cast<String>() ?? [];

        setState(() {
          userCompanyIds = companies;
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('userCompanyIds', companies);

        if (companies.isNotEmpty) {
          await _loadCompaniesWithMovements();
        }
      }
    } catch (e) {
      safeDebugPrint('[ERROR] Failed to load companies from Firestore: $e');
    }
  }

  Future<void> _initializePage() async {
   // updateAllStockMovements;
    safeDebugPrint('[DEBUG] Starting _initializePage');

    final prefs = await SharedPreferences.getInstance();
    final cachedIds = prefs.getStringList('userCompanyIds');

    if (cachedIds != null && cachedIds.isNotEmpty) {
      setState(() {
        userCompanyIds = cachedIds;
      });
      await _loadCompaniesWithMovements();
    }

    await _loadItemNames();
    setState(() => isLoading = false);
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy/MM/dd').format(date);
  }

  Future<void> _loadUserCompanyIds() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        userCompanyIds = [];
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        userCompanyIds = (data['companyIds'] as List?)?.cast<String>() ?? [];
        safeDebugPrint(
            '[DEBUG] userCompanyIds loaded from Firestore: $userCompanyIds');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('userCompanyIds', userCompanyIds);
      } else {
        userCompanyIds = [];
        safeDebugPrint('[DEBUG] User document not found');
      }
    } catch (e) {
      safeDebugPrint('[ERROR] Failed to load userCompanyIds: $e');
      userCompanyIds = [];
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isArabicNow = context.locale.languageCode == 'ar';
    if (_isArabic != isArabicNow) {
      _isArabic = isArabicNow;
      _loadItemNames();
      setState(() {});
    }
  }

  Future<void> _checkUserCompanies() async {
    setState(() => isLoading = true);
    await _loadUserCompaniesFromFirestore();
    setState(() => isLoading = false);
  }

  // دالة جديدة: تحميل الشركات التي تحتوي على حركات للمستخدم
  Future<void> _loadCompaniesWithMovements() async {
    safeDebugPrint(
        '[DEBUG] Starting _loadCompaniesWithMovements with userCompanyIds: $userCompanyIds');

    if (userCompanyIds.isEmpty) {
      safeDebugPrint('[DEBUG] No company IDs available');
      await _loadUserCompaniesFromFirestore();

      if (userCompanyIds.isEmpty) {
        safeDebugPrint('[DEBUG] Still no company IDs after retry');
        return;
      }
    }

    try {
      // جلب الشركات التي تحتوي على حركات مخزون
      final companiesWithMovements = <Map<String, dynamic>>[];

      for (final companyId in userCompanyIds) {
        final movementsSnapshot = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('stock_movements')
            .limit(1)
            .get();

        if (movementsSnapshot.docs.isNotEmpty) {
          final companyDoc = await FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .get();

          if (companyDoc.exists) {
            final companyData = companyDoc.data()!;
            companiesWithMovements.add({
              'id': companyId,
              'nameAr': companyData['nameAr'] ?? companyId,
              'nameEn': companyData['nameEn'] ?? companyId,
            });
          }
        }
      }

      setState(() {
        companies = companiesWithMovements;
        selectedCompanyId = companies.isNotEmpty ? companies[0]['id'] : null;
      });

      if (selectedCompanyId != null) {
        await _loadFactoriesWithMovements();
      }
    } catch (e, stack) {
      safeDebugPrint('[ERROR] Failed to load companies with movements: $e');
      safeDebugPrint(stack.toString());
    }
  }

  // دالة جديدة: تحميل المصانع التي تحتوي على حركات للشركة المحددة
  Future<void> _loadFactoriesWithMovements() async {
    if (selectedCompanyId == null) return;

    try {
      final factoriesWithMovements = <Map<String, dynamic>>[];

      // جلب جميع المصانع المرتبطة بالشركة
      final facSnaps = await FirebaseFirestore.instance
          .collection('factories')
          .where('companyIds', arrayContains: selectedCompanyId)
          .get();

      for (final factoryDoc in facSnaps.docs) {
        final factoryId = factoryDoc.id;

        // التحقق من وجود حركات لهذا المصنع في الشركة المحددة
        final movementsSnapshot = await FirebaseFirestore.instance
            .collection('companies')
            .doc(selectedCompanyId)
            .collection('stock_movements')
            .where('factoryId', isEqualTo: factoryId)
            .limit(1)
            .get();

        if (movementsSnapshot.docs.isNotEmpty) {
          final factoryData = factoryDoc.data();
          factoriesWithMovements.add({
            'id': factoryId,
            'nameAr': factoryData['nameAr'] ?? factoryId,
            'nameEn': factoryData['nameEn'] ?? factoryId,
          });
        }
      }

      setState(() {
        factories = factoriesWithMovements;
        selectedFactoryId = factories.isNotEmpty ? factories[0]['id'] : null;
        selectedCategory = null;
        selectedItemId = null;
        items = [];
        allItems = [];
      });

      if (selectedFactoryId != null) {
        await _loadItemsWithMovements();
      }
    } catch (e) {
      safeDebugPrint('[ERROR] Failed to load factories with movements: $e');
    }
  }

  // دالة جديدة: تحميل المنتجات التي تحتوي على حركات للمصنع المحدد
  Future<void> _loadItemsWithMovements() async {
    if (selectedCompanyId == null || selectedFactoryId == null) return;

    try {
      final itemsWithMovements = <Map<String, dynamic>>[];

      // جلب جميع المنتجات التي لها حركات في المصنع المحدد
      final movementsSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(selectedCompanyId)
          .collection('stock_movements')
          .where('factoryId', isEqualTo: selectedFactoryId)
          .get();

      // تجميع معرفات المنتجات الفريدة
      final itemIds = <String>{};
      for (final movement in movementsSnapshot.docs) {
        final itemId = movement.data()['itemId']?.toString();
        if (itemId != null) {
          itemIds.add(itemId);
        }
      }

      // جلب تفاصيل جميع المنتجات أولاً
      for (final itemId in itemIds) {
        try {
          final itemDoc = await FirebaseFirestore.instance
              .collection('items')
              .doc(itemId)
              .get();

          if (itemDoc.exists) {
            final itemData = itemDoc.data()!;
            final itemCategory =
                itemData['category']?.toString() ?? 'raw_material';

            itemsWithMovements.add({
              'id': itemId,
              'nameAr': itemData['nameAr'] ?? itemId,
              'nameEn': itemData['nameEn'] ?? itemId,
              'category': itemCategory,
            });
          }
        } catch (e) {
          safeDebugPrint('[ERROR] Loading item $itemId: $e');
        }
      }

      // حفظ جميع العناصر ثم تطبيق الفلترة
      setState(() {
        allItems = itemsWithMovements;
        _filterItemsByCategory();
      });

      await _loadInventory();
    } catch (e) {
      safeDebugPrint('[ERROR] Failed to load items with movements: $e');
    }
  }

  // دالة جديدة: تصفية العناصر بناءً على الفئة المحددة
  void _filterItemsByCategory() {
    if (selectedCategory == null || selectedCategory == 'all') {
      setState(() {
        items = List.from(allItems);
      });
    } else {
      setState(() {
        items = allItems
            .where((item) => item['category'] == selectedCategory)
            .toList();
      });
    }

    // تحديث العنصر المحدد
    if (items.isNotEmpty) {
      setState(() {
        selectedItemId = items[0]['id'];
      });
    } else {
      setState(() {
        selectedItemId = null;
      });
    }
  }

  Future<void> _loadInventory() async {
    if (selectedFactoryId == null) return;

    try {
      final invSnap = await FirebaseFirestore.instance
          .collection('factories')
          .doc(selectedFactoryId!)
          .collection('inventory')
          .get();

      final stocks = <String, double>{};
      for (var doc in invSnap.docs) {
        try {
          final data = doc.data();
          final quantity = data['quantity'];
          stocks[doc.id] = (quantity is double
              ? quantity
              : (quantity is num ? quantity.toDouble() : 0));
        } catch (e) {
          safeDebugPrint('[ERROR] Processing inventory item ${doc.id}: $e');
        }
      }
      setState(() => itemStocks = stocks);
    } catch (e) {
      safeDebugPrint('[ERROR] Loading inventory: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_loading_inventory'.tr())),
        );
      }
    }
  }

Future<void> _loadItemNames() async {
  try {
    // استخدام التخزين المؤقت لتجنب إعادة التحميل
    final cachedNames = await UserLocalStorage.getItemNames();
    if (cachedNames.isNotEmpty) {
      setState(() {
        itemNames = cachedNames;
      });
      return;
    }

    final itemsSnap = await FirebaseFirestore.instance
        .collection('items')
        .get()
        .timeout(const Duration(seconds: 30));

    final names = <String, String>{};
    for (var doc in itemsSnap.docs) {
      final data = doc.data();
      names[doc.id] = _isArabic
          ? (data['nameAr'] ?? 'Unknown'.tr())
          : (data['nameEn'] ?? 'Unknown'.tr());
    }
    
    // حفظ في التخزين المؤقت
    await UserLocalStorage.saveItemNames(names);
    
    setState(() {
      itemNames = names;
    });
  } catch (e) {
    safeDebugPrint('[ERROR] Loading item names: $e');
    // استخدام البيانات المخزنة مؤقتاً إذا فشل التحميل
    final cachedNames = await UserLocalStorage.getItemNames();
    setState(() {
      itemNames = cachedNames;
    });
  }
}


Widget _buildMovementsTable(List<QueryDocumentSnapshot> docs) {
  // تجميع البيانات حسب المنتج
  final Map<String, List<Map<String, dynamic>>> itemMovements = {};

  for (var doc in docs) {
    try {
      final data = doc.data() as Map<String, dynamic>;
      
      final itemId = data['itemId']?.toString() ?? '';
      final type = data['type']?.toString() ?? 'unknown';
      
      // تحويل الكمية إلى double بشكل آمن
      double quantity = 0;
      final quantityValue = data['quantity'];
      if (quantityValue is int) {
        quantity = quantityValue.toDouble();
      } else if (quantityValue is double) {
        quantity = quantityValue;
      } else if (quantityValue is String) {
        quantity = double.tryParse(quantityValue) ?? 0;
      } else if (quantityValue is num) {
        quantity = quantityValue.toDouble();
      }
      
      final timestamp = data['date'] as Timestamp?;
      final date = timestamp != null ? timestamp.toDate() : DateTime.now();

      final movementInfo = MovementUtils.getMovementTypeInfo(type, quantity);

      if (!itemMovements.containsKey(itemId)) {
        itemMovements[itemId] = [];
      }

      // إضافة الحركة
      itemMovements[itemId]!.add({
        'date': date,
        'type': type,
        'in': movementInfo['in'],
        'out': movementInfo['out'],
        'type_text': movementInfo['type_text'],
        'quantity': quantity,
        'documentId': doc.id,
      });
    } catch (e) {
      safeDebugPrint('[ERROR] Processing movement: $e');
    }
  }

  if (!mounted) {
    return const SizedBox.shrink();
  }

  return ListView.builder(
    itemCount: itemMovements.length,
    itemBuilder: (context, index) {
      if (!mounted) {
        return const SizedBox.shrink();
      }

      final itemId = itemMovements.keys.elementAt(index);
      final movements = itemMovements[itemId]!;
      final itemName = itemNames[itemId] ?? 'Unknown Item'.tr();
      final currentStock = itemStocks[itemId] ?? 0;

      // ترتيب الحركات من الأقدم إلى الأحدث لحساب الرصيد بشكل صحيح
      movements.sort((a, b) => a['date'].compareTo(b['date']));
      
      // حساب الرصيد أول الفترة (من المخزون الحالي والحركات)
      // يجب أن يكون حساب الرصيد أول المدة من البيانات التاريخية وليس المخزون الحالي
      
      // أولاً: حساب صافي الحركات خلال الفترة
      double netMovement = 0;
      for (var movement in movements) {
        netMovement += movement['in'] - movement['out'];
      }
      
      // الرصيد أول الفترة = الرصيد الحالي - صافي الحركات خلال الفترة
      double openingBalance = currentStock - netMovement;
      
      double runningBalance = openingBalance;
      final movementsWithBalance = [];
      
      for (var movement in movements) {
        runningBalance = runningBalance + movement['in'] - movement['out'];
        movementsWithBalance.add({
          ...movement,
          'balance': runningBalance,
        });
      }
      
      final closingBalance = runningBalance;

      // تطبيق الترتيب المطلوب (أحدث أولاً أو أقدم أولاً)
      final displayMovements = sortOrder == 'desc' 
          ? movementsWithBalance.reversed.toList()
          : movementsWithBalance;

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // عنوان المنتج والرصيد الحالي
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '${'item'.tr()}: $itemName',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${'opening_balance'.tr()}: ${openingBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: openingBalance >= 0 ? Colors.blue : Colors.red,
                        ),
                      ),
                      Text(
                        '${'closing_balance'.tr()}: ${closingBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: closingBalance >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                      Text(
                        '${'current_stock'.tr()}: ${currentStock.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // جدول الحركات مع تمرير مزدوج
              SizedBox(
                height: 300,
                child: Scrollbar(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 16,
                        dataRowMinHeight: 40,
                        dataRowMaxHeight: 60,
                        headingRowHeight: 40,
                        columns: [
                          const DataColumn(
                              label: Text('#',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              numeric: true),
                          DataColumn(
                            label: Text('date'.tr(),
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          DataColumn(
                            label: Text('movement_type'.tr(),
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          DataColumn(
                              label: Text('in'.tr(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green)),
                              numeric: true),
                          DataColumn(
                              label: Text('out'.tr(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red)),
                              numeric: true),
                          DataColumn(
                              label: Text('balance'.tr(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue)),
                              numeric: true),
                        ],
                        rows: List<DataRow>.generate(displayMovements.length, (index) {
                          final movement = displayMovements[index];
                          return DataRow(
                            cells: [
                              DataCell(Text((index + 1).toString())),
                              DataCell(Text(_formatDate(movement['date']))),
                              DataCell(Text(movement['type_text'])),
                              DataCell(Text(
                                movement['in'] > 0
                                    ? movement['in'].toStringAsFixed(2)
                                    : '-',
                                style: TextStyle(
                                  color: movement['in'] > 0
                                      ? Colors.green
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              )),
                              DataCell(Text(
                                movement['out'] > 0
                                    ? movement['out'].toStringAsFixed(2)
                                    : '-',
                                style: TextStyle(
                                  color: movement['out'] > 0
                                      ? Colors.red
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              )),
                              DataCell(Text(
                                movement['balance'].toStringAsFixed(2),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: movement['balance'] >= 0 ? Colors.blue : Colors.red,
                                ),
                              )),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  Query<Map<String, dynamic>> _buildMovementsQuery() {
    if (selectedCompanyId == null || selectedFactoryId == null) {
      return FirebaseFirestore.instance.collection('dummy').limit(1);
    }

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('companies')
        .doc(selectedCompanyId!)
        .collection('stock_movements')
        .where('factoryId', isEqualTo: selectedFactoryId);

    if (selectedItemId != null) {
      query = query.where('itemId', isEqualTo: selectedItemId);
    }

    if (startDate != null) {
      query = query.where('date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!));
    }
    if (endDate != null) {
      final endOfDay =
          DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59);
      query = query.where('date',
          isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
    }

    query = query.orderBy('date', descending: sortOrder == 'desc');

    return query;
  }

  Future<void> _exportToPdf(List<QueryDocumentSnapshot> docs) async {
    if (!mounted) return;

    setState(() => isExporting = true);

    try {
      final cairoRegular = await _loadCairoRegular();
      final cairoBold = await _loadCairoBold();

      final pdf = pw.Document();
      final now = DateTime.now();
      final fileName = 'stock_movements_${now.millisecondsSinceEpoch}.pdf';

      final company = companies.firstWhere(
        (c) => c['id'] == selectedCompanyId,
        orElse: () => {'nameAr': 'Unknown', 'nameEn': 'Unknown'},
      );

      final factory = factories.firstWhere(
        (f) => f['id'] == selectedFactoryId,
        orElse: () => {'nameAr': 'Unknown', 'nameEn': 'Unknown'},
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          theme: pw.ThemeData.withFont(base: cairoRegular),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection:
                  _isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text(
                      'stock_movements_report'.tr(),
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        font: cairoBold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  _buildPdfInfoRow(
                      'company'.tr(),
                      _isArabic ? company['nameAr'] : company['nameEn'],
                      cairoRegular),
                  _buildPdfInfoRow(
                      'factory'.tr(),
                      _isArabic ? factory['nameAr'] : factory['nameEn'],
                      cairoRegular),
                  if (selectedCategory != null)
                    _buildPdfInfoRow(
                        'category'.tr(),
                        selectedCategory == 'raw_material'
                            ? 'raw_materials'.tr()
                            : 'packaging'.tr(),
                        cairoRegular),
                  _buildPdfInfoRow('generated_on'.tr(),
                      DateFormat('yyyy/MM/dd HH:mm').format(now), cairoRegular),
                  _buildPdfInfoRow(
                      'date_range'.tr(),
                      '${DateFormat('yyyy/MM/dd').format(startDate!)} - ${DateFormat('yyyy/MM/dd').format(endDate!)}',
                      cairoRegular),
                  pw.SizedBox(height: 20),
                  if (docs.isNotEmpty)
                    _buildPdfTable(docs, cairoRegular, cairoBold)
                  else
                    pw.Center(
                      child: pw.Text(
                        'no_data_available'.tr(),
                        style: pw.TextStyle(font: cairoRegular),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );

      await _saveAndSharePdf(pdf, fileName);
    } catch (e) {
      safeDebugPrint('[ERROR] PDF export failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('pdf_export_failed'.tr())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isExporting = false);
      }
    }
  }


  pw.Widget _buildPdfTable(
    List<QueryDocumentSnapshot> docs, pw.Font regularFont, pw.Font boldFont) {
  // تجميع الحركات حسب المنتج مع حساب الرصيد
  final Map<String, Map<String, dynamic>> itemMovementsData = {};

  for (var doc in docs) {
    try {
      final docData = doc.data() as Map<String, dynamic>;
      final itemId = docData['itemId']?.toString() ?? '';
      final type = docData['type']?.toString() ?? 'unknown';
      
      double quantity = 0;
      final quantityValue = docData['quantity'];
      if (quantityValue is int) {
        quantity = quantityValue.toDouble();
      } else if (quantityValue is double) {
        quantity = quantityValue;
      } else if (quantityValue is String) {
        quantity = double.tryParse(quantityValue) ?? 0;
      }
      
      final movementInfo = MovementUtils.getMovementTypeInfo(type, quantity);
      final timestamp = docData['date'] as Timestamp?;
      final date = timestamp != null ? _formatDate(timestamp.toDate()) : '';

      if (!itemMovementsData.containsKey(itemId)) {
        itemMovementsData[itemId] = {
          'name': itemNames[itemId] ?? 'Unknown',
          'movements': [],
          'currentStock': itemStocks[itemId] ?? 0,
        };
      }

      itemMovementsData[itemId]!['movements']!.add({
        'date': date,
        'type': type,
        'in': movementInfo['in'],
        'out': movementInfo['out'],
        'type_text': movementInfo['type_text'],
        'quantity': quantity,
      });
    } catch (e) {
      safeDebugPrint('[ERROR] Building PDF table: $e');
    }
  }

  // حساب الأرصدة لكل منتج
  for (final itemId in itemMovementsData.keys) {
    final movements = itemMovementsData[itemId]!['movements'] as List;
    final currentStock = itemMovementsData[itemId]!['currentStock'] as double;
    
    // حساب صافي الحركات خلال الفترة
    double netMovement = 0;
    for (var movement in movements) {
      netMovement += movement['in'] - movement['out'];
    }
    
    // الرصيد أول الفترة = الرصيد الحالي - صافي الحركات خلال الفترة
    double openingBalance = currentStock - netMovement;
    
    // حساب الرصيد آخر الفترة
    double runningBalance = openingBalance;
    for (var movement in movements) {
      runningBalance = runningBalance + movement['in'] - movement['out'];
      movement['balance'] = runningBalance;
    }
    
    itemMovementsData[itemId]!['openingBalance'] = openingBalance;
    itemMovementsData[itemId]!['closingBalance'] = runningBalance;
  }

  return pw.Column(
    children: [
      for (final itemId in itemMovementsData.keys)
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // عنوان المنتج والأرصدة
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${'item'.tr()}: ${itemMovementsData[itemId]!['name']}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                    font: boldFont,
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      '${'opening_balance'.tr()}: ${itemMovementsData[itemId]!['openingBalance'].toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                        font: boldFont,
                        color: (itemMovementsData[itemId]!['openingBalance'] as double) >= 0 
                            ? PdfColors.blue 
                            : PdfColors.red,
                      ),
                    ),
                    pw.Text(
                      '${'closing_balance'.tr()}: ${itemMovementsData[itemId]!['closingBalance'].toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                        font: boldFont,
                        color: (itemMovementsData[itemId]!['closingBalance'] as double) >= 0 
                            ? PdfColors.green 
                            : PdfColors.red,
                      ),
                    ),
                    pw.Text(
                      '${'current_stock'.tr()}: ${itemMovementsData[itemId]!['currentStock'].toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                        font: boldFont,
                        color: PdfColors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),

            // جدول الحركات لهذا المنتج
            pw.Table(
              border: const pw.TableBorder(
                left: pw.BorderSide(),
                right: pw.BorderSide(),
                top: pw.BorderSide(),
                bottom: pw.BorderSide(),
                horizontalInside: pw.BorderSide(),
                verticalInside: pw.BorderSide(),
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.5),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
                5: const pw.FlexColumnWidth(1.2),
              },
              children: [
                // رأس الجدول
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildPdfHeaderCell('#', boldFont),
                    _buildPdfHeaderCell('date'.tr(), boldFont),
                    _buildPdfHeaderCell('movement_type'.tr(), boldFont),
                    _buildPdfHeaderCell('in'.tr(), boldFont),
                    _buildPdfHeaderCell('out'.tr(), boldFont),
                    _buildPdfHeaderCell('balance'.tr(), boldFont),
                  ],
                ),
                // بيانات الجدول
                ..._buildItemTableRows(
                    (itemMovementsData[itemId]!['movements'] as List).cast<Map<String, dynamic>>(), regularFont),
              ],
            ),
            pw.SizedBox(height: 16),
          ],
        ),
    ],
  );
}


List<pw.TableRow> _buildItemTableRows(
    List<Map<String, dynamic>> movements, pw.Font font) {
  final List<pw.TableRow> rows = [];

  // ترتيب الحركات حسب التاريخ
  movements.sort((a, b) => a['date'].compareTo(b['date']));

  int index = 1;
  for (final movement in movements) {
    final balance = movement['balance'] as double;
    
    rows.add(
      pw.TableRow(
        children: [
          _buildPdfDataCell((index++).toString(), font),
          _buildPdfDataCell(movement['date'], font),
          _buildPdfDataCell(movement['type_text'], font),
          _buildPdfDataCell(
            movement['in'] > 0 ? movement['in'].toStringAsFixed(2) : '-', 
            font,
            color: movement['in'] > 0 ? PdfColors.green : PdfColors.grey
          ),
          _buildPdfDataCell(
            movement['out'] > 0 ? movement['out'].toStringAsFixed(2) : '-', 
            font,
            color: movement['out'] > 0 ? PdfColors.red : PdfColors.grey
          ),
          _buildPdfDataCell(
            balance.toStringAsFixed(2), 
            font,
            color: balance >= 0 ? PdfColors.blue : PdfColors.red
          ),
        ],
      ),
    );
  }

  return rows;
}

  pw.Widget _buildPdfInfoRow(String label, String value, pw.Font font) {
    return pw.Row(
      children: [
        pw.Text(
          '$label: ',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font),
        ),
        pw.Text(value, style: pw.TextStyle(font: font)),
      ],
    );
  }

  pw.Padding _buildPdfHeaderCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
          font: font,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Padding _buildPdfDataCell(String text, pw.Font font,
    {pw.TextAlign align = pw.TextAlign.center, PdfColor? color}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 9, 
        font: font,
        color: color,
      ),
      textAlign: align,
    ),
  );
}

  Future<void> _saveAndSharePdf(pw.Document pdf, String fileName) async {
    try {
      final bytes = await pdf.save();

      if (kIsWeb) {
        // للويب - استخدام مكتبة universal_html
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement()
          ..href = url
          ..style.display = 'none'
          ..download = fileName;
        html.document.body?.append(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      } else {
        // للتطبيقات - حفظ ومشاركة
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        // ignore: deprecated_member_use
        await Share.shareXFiles([XFile(file.path)]);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('pdf_export_success'.tr())),
        );
      }
    } catch (e) {
      safeDebugPrint('Error saving/sharing PDF: $e');
      rethrow;
    }
  }



/* Future<void> updateAllStockMovements() async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final String companyId = selectedCompanyId!; // ID الشركة
  final CollectionReference stockMovementsRef = firestore
      .collection('companies')
      .doc(companyId)
      .collection('stock_movements');

  try {
    final QuerySnapshot snapshot = await stockMovementsRef.get();

    for (final DocumentSnapshot doc in snapshot.docs) {
      await doc.reference.update({
        'batchId': 'batch_xyz',
        'isSynced': true,
        'newBalance': 120,
        'previousBalance': 0,
      });
    }

    safeDebugPrint('تم تحديث جميع الوثائق بنجاح.');
  } catch (e) {
    safeDebugPrint('حدث خطأ أثناء التحديث: $e');
  }
}
 */
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? startDate! : endDate!,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
  if (isLoading) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('loading_data'.tr()),
          ],
        ),
      ),
    );
  }
    if (userCompanyIds.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('stock_movements'.tr())),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.business, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('no_companies_assigned'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('contact_admin_for_companies'.tr(),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _checkUserCompanies(),
                child: Text('refresh'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    return AppScaffold(
      title: 'stock_movements'.tr(),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // الصف الأول: الشركة والمصنع
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: 'select_company',
                    value: selectedCompanyId,
                    items: companies,
                    onChanged: (val) async {
                      setState(() {
                        selectedCompanyId = val;
                        selectedFactoryId = null;
                        selectedItemId = null;
                        selectedCategory = null;
                        factories = [];
                        items = [];
                        allItems = [];
                      });
                      if (val != null) await _loadFactoriesWithMovements();
                  //    updateAllStockMovements();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDropdown(
                    label: 'select_factory',
                    value: selectedFactoryId,
                    items: factories,
                    onChanged: (val) async {
                      setState(() {
                        selectedFactoryId = val;
                        selectedItemId = null;
                        selectedCategory = null;
                        items = [];
                        allItems = [];
                      });
                      if (val != null) await _loadItemsWithMovements();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // الصف الثاني: الفئة والمنتج والترتيب
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'category'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text('all_categories'.tr()),
                      ),
                      DropdownMenuItem<String>(
                        value: 'raw_material',
                        child: Text('raw_materials'.tr()),
                      ),
                      DropdownMenuItem<String>(
                        value: 'packaging',
                        child: Text('packaging'.tr()),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        selectedCategory = val;
                      });
                      _filterItemsByCategory();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDropdown(
                    label: 'select_item',
                    value: selectedItemId,
                    items: items,
                    onChanged: (val) => setState(() => selectedItemId = val),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: sortOrder,
                    items: [
                      DropdownMenuItem(
                        value: 'desc',
                        child: Text('newest_first'.tr()),
                      ),
                      DropdownMenuItem(
                        value: 'asc',
                        child: Text('oldest_first'.tr()),
                      ),
                    ],
                    onChanged: (val) => setState(() => sortOrder = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _selectDate(context, true),
                    child: Text(
                      startDate != null
                          ? '${'from'.tr()} ${DateFormat('yyyy/MM/dd').format(startDate!)}'
                          : 'select_start_date'.tr(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _selectDate(context, false),
                    child: Text(
                      endDate != null
                          ? '${'to'.tr()} ${DateFormat('yyyy/MM/dd').format(endDate!)}'
                          : 'select_end_date'.tr(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (selectedCompanyId != null && selectedFactoryId != null)
              ElevatedButton.icon(
                onPressed: isExporting
                    ? null
                    : () async {
                        final snapshot = await _buildMovementsQuery().get();
                        if (snapshot.docs.isNotEmpty) {
                          await _exportToPdf(snapshot.docs);
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('no_data_to_export'.tr())),
                            );
                          }
                        }
                      },
                icon: isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(isExporting ? 'exporting'.tr() : 'export_pdf'.tr()),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _buildMovementsQuery().snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('error_loading_data'.tr()));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inventory_2,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text('no_movements_found'.tr(),
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          Text('adjust_filters_or_try_again'.tr(),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    );
                  }

                  return _buildMovementsTable(docs);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<Map<String, dynamic>> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(
        labelText: label.tr(),
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('all'.tr()),
        ),
        ...items.map((item) {
          return DropdownMenuItem<String>(
            value: item['id'],
            child: Text(_isArabic ? item['nameAr'] : item['nameEn']),
          );
        }),
      ],
      onChanged: onChanged,
    );
  }
}

 */
/* pw.Widget _buildPdfTable(
    List<QueryDocumentSnapshot> docs, pw.Font regularFont, pw.Font boldFont) {
  // تجميع الحركات حسب المنتج مع حساب الرصيد
  final Map<String, Map<String, dynamic>> itemMovementsData = {};

  for (var doc in docs) {
    try {
      final docData = doc.data() as Map<String, dynamic>;
      final itemId = docData['itemId']?.toString() ?? '';
      final type = docData['type']?.toString() ?? 'unknown';
      
      double quantity = 0;
      final quantityValue = docData['quantity'];
      if (quantityValue is int) {
        quantity = quantityValue.toDouble();
      } else if (quantityValue is double) {
        quantity = quantityValue;
      } else if (quantityValue is String) {
        quantity = double.tryParse(quantityValue) ?? 0;
      }
      
      final movementInfo = MovementUtils.getMovementTypeInfo(type, quantity);
      final timestamp = docData['date'] as Timestamp?;
      final date = timestamp != null ? _formatDate(timestamp.toDate()) : '';

      if (!itemMovementsData.containsKey(itemId)) {
        itemMovementsData[itemId] = {
          'name': itemNames[itemId] ?? 'Unknown',
          'movements': [],
          'openingBalance': 0.0,
          'closingBalance': 0.0,
        };
      }

      itemMovementsData[itemId]!['movements']!.add({
        'date': date,
        'type': type,
        'in': movementInfo['in'],
        'out': movementInfo['out'],
        'type_text': movementInfo['type_text'],
      });
    } catch (e) {
      safeDebugPrint('[ERROR] Building PDF table: $e');
    }
  }

  // حساب الأرصدة لكل منتج
  for (final itemId in itemMovementsData.keys) {
    final movements = itemMovementsData[itemId]!['movements'] as List;
    final currentStock = itemStocks[itemId] ?? 0;
    
    // حساب الرصيد أول الفترة
    double openingBalance = currentStock;
    for (var movement in movements) {
      openingBalance = openingBalance - movement['in'] + movement['out'];
    }
    
    // حساب الرصيد آخر الفترة
    double runningBalance = openingBalance;
    for (var movement in movements) {
      runningBalance = runningBalance + movement['in'] - movement['out'];
      movement['balance'] = runningBalance;
    }
    
    itemMovementsData[itemId]!['openingBalance'] = openingBalance;
    itemMovementsData[itemId]!['closingBalance'] = runningBalance;
  }

  return pw.Column(
    children: [
      for (final itemId in itemMovementsData.keys)
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // عنوان المنتج والأرصدة
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${'item'.tr()}: ${itemMovementsData[itemId]!['name']}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                    font: boldFont,
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      '${'opening_balance'.tr()}: ${itemMovementsData[itemId]!['openingBalance'].toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                        font: boldFont,
                      ),
                    ),
                    pw.Text(
                      '${'closing_balance'.tr()}: ${itemMovementsData[itemId]!['closingBalance'].toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                        font: boldFont,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),

            // جدول الحركات لهذا المنتج
            pw.Table(
              border: const pw.TableBorder(
                left: pw.BorderSide(),
                right: pw.BorderSide(),
                top: pw.BorderSide(),
                bottom: pw.BorderSide(),
                horizontalInside: pw.BorderSide(),
                verticalInside: pw.BorderSide(),
              ),
              columnWidths: _isArabic
                  ? {
                      0: const pw.FlexColumnWidth(1.5),
                      1: const pw.FlexColumnWidth(1),
                      2: const pw.FlexColumnWidth(1),
                      3: const pw.FlexColumnWidth(1),
                      4: const pw.FlexColumnWidth(1),
                      5: const pw.FlexColumnWidth(0.5),
                    }
                  : {
                      0: const pw.FlexColumnWidth(0.5),
                      1: const pw.FlexColumnWidth(1),
                      2: const pw.FlexColumnWidth(1),
                      3: const pw.FlexColumnWidth(1),
                      4: const pw.FlexColumnWidth(1),
                      5: const pw.FlexColumnWidth(1.5),
                    },
              children: [
                // رأس الجدول
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: _isArabic
                      ? [
                          _buildPdfHeaderCell('balance'.tr(), boldFont),
                          _buildPdfHeaderCell('out'.tr(), boldFont),
                          _buildPdfHeaderCell('in'.tr(), boldFont),
                          _buildPdfHeaderCell('movement_type'.tr(), boldFont),
                          _buildPdfHeaderCell('date'.tr(), boldFont),
                          _buildPdfHeaderCell('#', boldFont),
                        ]
                      : [
                          _buildPdfHeaderCell('#', boldFont),
                          _buildPdfHeaderCell('date'.tr(), boldFont),
                          _buildPdfHeaderCell('movement_type'.tr(), boldFont),
                          _buildPdfHeaderCell('in'.tr(), boldFont),
                          _buildPdfHeaderCell('out'.tr(), boldFont),
                          _buildPdfHeaderCell('balance'.tr(), boldFont),
                        ],
                ),
                // بيانات الجدول
                ..._buildItemTableRows(
                    (itemMovementsData[itemId]!['movements'] as List).cast<Map<String, dynamic>>(), regularFont),
              ],
            ),
            pw.SizedBox(height: 16),
          ],
        ),
    ],
  );
}
 */
/*   pw.Widget _buildPdfTable(
      List<QueryDocumentSnapshot> docs, pw.Font regularFont, pw.Font boldFont) {
    // تجميع الحركات حسب المنتج
    final Map<String, List<Map<String, dynamic>>> itemMovements = {};

    for (var doc in docs) {
      try {
        final docData = doc.data() as Map<String, dynamic>;
        final itemId = docData['itemId']?.toString() ?? '';
        final type = docData['type']?.toString() ?? 'unknown';
        final movementInfo = MovementUtils.getMovementTypeInfo(
            type, (docData['quantity'] ?? 0) as double);
        final timestamp = docData['date'] as Timestamp?;
        final date = timestamp != null ? _formatDate(timestamp.toDate()) : '';

        if (!itemMovements.containsKey(itemId)) {
          itemMovements[itemId] = [];
        }

        itemMovements[itemId]!.add({
          'date': date,
          'type': type,
          'in': movementInfo['in'],
          'out': movementInfo['out'],
          'type_text': movementInfo['type_text'],
        });
      } catch (e) {
        safeDebugPrint('[ERROR] Building PDF table: $e');
      }
    }

    return pw.Column(
      children: [
        for (final itemId in itemMovements.keys)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // عنوان المنتج
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  '${'item'.tr()}: ${itemNames[itemId] ?? 'Unknown'}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                    font: boldFont,
                  ),
                ),
              ),

              // جدول الحركات لهذا المنتج
              pw.Table(
                border: const pw.TableBorder(
                  left: pw.BorderSide(),
                  right: pw.BorderSide(),
                  top: pw.BorderSide(),
                  bottom: pw.BorderSide(),
                  horizontalInside: pw.BorderSide(),
                  verticalInside: pw.BorderSide(),
                ),
                columnWidths: _isArabic
                    ? {
                        0: const pw.FlexColumnWidth(1.5),
                        1: const pw.FlexColumnWidth(1),
                        2: const pw.FlexColumnWidth(1),
                        3: const pw.FlexColumnWidth(1),
                        4: const pw.FlexColumnWidth(1),
                        5: const pw.FlexColumnWidth(0.5),
                      }
                    : {
                        0: const pw.FlexColumnWidth(0.5),
                        1: const pw.FlexColumnWidth(1),
                        2: const pw.FlexColumnWidth(1),
                        3: const pw.FlexColumnWidth(1),
                        4: const pw.FlexColumnWidth(1),
                        5: const pw.FlexColumnWidth(1.5),
                      },
                children: [
                  // رأس الجدول
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey200),
                    children: _isArabic
                        ? [
                            _buildPdfHeaderCell('balance'.tr(), boldFont),
                            _buildPdfHeaderCell('out'.tr(), boldFont),
                            _buildPdfHeaderCell('in'.tr(), boldFont),
                            _buildPdfHeaderCell('movement_type'.tr(), boldFont),
                            _buildPdfHeaderCell('date'.tr(), boldFont),
                            _buildPdfHeaderCell('#', boldFont),
                          ]
                        : [
                            _buildPdfHeaderCell('#', boldFont),
                            _buildPdfHeaderCell('date'.tr(), boldFont),
                            _buildPdfHeaderCell('movement_type'.tr(), boldFont),
                            _buildPdfHeaderCell('in'.tr(), boldFont),
                            _buildPdfHeaderCell('out'.tr(), boldFont),
                            _buildPdfHeaderCell('balance'.tr(), boldFont),
                          ],
                  ),
                  // بيانات الجدول
                  ..._buildItemTableRows(itemMovements[itemId]!, regularFont),
                ],
              ),
              pw.SizedBox(height: 16),
            ],
          ),
      ],
    );
  }
 */
/*   List<pw.TableRow> _buildItemTableRows(
      List<Map<String, dynamic>> movements, pw.Font font) {
    final List<pw.TableRow> rows = [];

    // حساب الرصيد التدريجي
    double runningBalance = 0;
    final movementsWithBalance = movements.map((movement) {
      runningBalance =
          (runningBalance - movement['out'] + movement['in']).toDouble();
      return {
        ...movement,
        'balance': runningBalance,
      };
    }).toList();

    int index = 1;
    for (final movement in movementsWithBalance) {
      rows.add(
        pw.TableRow(
          children: _isArabic
              ? [
                  _buildPdfDataCell(movement['balance'].toString(), font),
                  _buildPdfDataCell(movement['out'].toString(), font),
                  _buildPdfDataCell(movement['in'].toString(), font),
                  _buildPdfDataCell(movement['type_text'], font),
                  _buildPdfDataCell(movement['date'], font),
                  _buildPdfDataCell((index++).toString(), font),
                ]
              : [
                  _buildPdfDataCell((index++).toString(), font),
                  _buildPdfDataCell(movement['date'], font),
                  _buildPdfDataCell(movement['type_text'], font),
                  _buildPdfDataCell(movement['in'].toString(), font),
                  _buildPdfDataCell(movement['out'].toString(), font),
                  _buildPdfDataCell(movement['balance'].toString(), font),
                ],
        ),
      );
    }

    return rows;
  }
 */

/*   Future<void> _loadItemNames() async {
    final itemsSnap =
        await FirebaseFirestore.instance.collection('items').get();

    final names = <String, String>{};
    for (var doc in itemsSnap.docs) {
      final data = doc.data();
      names[doc.id] = _isArabic
          ? (data['nameAr'] ?? 'Unknown'.tr())
          : (data['nameEn'] ?? 'Unknown'.tr());
    }
    setState(() {
      itemNames = names;
    });
  } */

/*   Widget _buildMovementsTable(List<QueryDocumentSnapshot> docs) {
    // تجميع البيانات حسب المنتج
    final Map<String, List<Map<String, dynamic>>> itemMovements = {};

    for (var doc in docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;

        // استخدام itemId بدلاً من itemId (التصحيح الرئيسي)
        final itemId = data['itemId']?.toString() ?? '';
        final type = data['type']?.toString() ?? 'unknown';

        // تحويل الكمية إلى double بشكل آمن
        double quantity = 0;
        final quantityValue = data['quantity'];
        if (quantityValue is int) {
          quantity = quantityValue.toDouble();
        } else if (quantityValue is double) {
          quantity = quantityValue;
        } else if (quantityValue is String) {
          quantity = double.tryParse(quantityValue) ?? 0;
        } else if (quantityValue is num) {
          quantity = quantityValue.toDouble();
        }

        final timestamp = data['date'] as Timestamp?;
        final date = timestamp != null ? timestamp.toDate() : DateTime.now();

        final movementInfo = MovementUtils.getMovementTypeInfo(type, quantity);

        if (!itemMovements.containsKey(itemId)) {
          itemMovements[itemId] = [];
        }

        // إضافة الحركة
        itemMovements[itemId]!.add({
          'date': date,
          'type': type,
          'in': movementInfo['in'],
          'out': movementInfo['out'],
          'type_text': movementInfo['type_text'],
          'quantity': quantity,
        });
      } catch (e) {
        safeDebugPrint('[ERROR] Processing movement: $e');
        // طباعة تفاصيل المستند للمساعدة في التصحيح
        safeDebugPrint('Document data: ${doc.data()}');

        // تحليل الخطأ بشكل أكثر تفصيلاً
        if (e is TypeError) {
          safeDebugPrint('Type error details: ${e.toString()}');
          final data = doc.data() as Map<String, dynamic>;
          safeDebugPrint('itemId type: ${data['itemId']?.runtimeType}');
          safeDebugPrint('type type: ${data['type']?.runtimeType}');
          safeDebugPrint('quantity type: ${data['quantity']?.runtimeType}');
          safeDebugPrint('date type: ${data['date']?.runtimeType}');
        }
      }
    }

    // إذا تم التخلص من الـ Widget، نرجع widget فارغ
    if (!mounted) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      itemCount: itemMovements.length,
      itemBuilder: (context, index) {
        // تحقق مرة أخرى في كل مرة يتم فيها بناء عنصر
        if (!mounted) {
          return const SizedBox.shrink();
        }

        final itemId = itemMovements.keys.elementAt(index);
        final movements = itemMovements[itemId]!;
        final itemName = itemNames[itemId] ?? 'Unknown Item'.tr();
        final currentStock = itemStocks[itemId] ?? 0;

        // إصلاح حساب الرصيد: يجب أن نبدأ من الصفر ونضيف الحركات بالترتيب الزمني
        double runningBalance = 0;
        final movementsWithBalance = [];

        // ترتيب الحركات من الأقدم إلى الأحدث لحساب الرصيد بشكل صحيح
        movements.sort((a, b) => a['date'].compareTo(b['date']));

        for (var movement in movements) {
          runningBalance = runningBalance + movement['in'] - movement['out'];
          movementsWithBalance.add({
            ...movement,
            'balance': runningBalance,
          });
        }

        // عكس القائمة لعرض الأحدث أولاً مع الحفاظ على الرصيد الصحيح
        final reversedMovements = movementsWithBalance.reversed.toList();

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // عنوان المنتج والرصيد الحالي
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '${'item'.tr()}: $itemName',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${'current_balance'.tr()}: $currentStock',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // جدول الحركات مع تمرير مزدوج
                SizedBox(
                  height: 300, // ارتفاع ثابت للجدول
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 16,
                          dataRowMinHeight: 40,
                          dataRowMaxHeight: 60,
                          headingRowHeight: 40,
                          columns: [
                            const DataColumn(
                                label: Text('#',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                numeric: true),
                            DataColumn(
                              label: Text('date'.tr(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              tooltip: 'movement_date'.tr(),
                            ),
                            DataColumn(
                              label: Text('movement_type'.tr(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              tooltip: 'type_of_movement'.tr(),
                            ),
                            DataColumn(
                                label: Text('in'.tr(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green)),
                                numeric: true,
                                tooltip: 'quantity_in'.tr()),
                            DataColumn(
                                label: Text('out'.tr(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red)),
                                numeric: true,
                                tooltip: 'quantity_out'.tr()),
                            DataColumn(
                                label: Text('balance'.tr(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue)),
                                numeric: true,
                                tooltip: 'running_balance'.tr()),
                          ],
                          rows: List<DataRow>.generate(reversedMovements.length,
                              (index) {
                            final movement = reversedMovements[index];
                            return DataRow(
                              cells: [
                                DataCell(Text((index + 1).toString())),
                                DataCell(Text(_formatDate(movement['date']))),
                                DataCell(Text(movement['type_text'])),
                                DataCell(Text(
                                  movement['in'] > 0
                                      ? movement['in'].toStringAsFixed(2)
                                      : '-',
                                  style: TextStyle(
                                    color: movement['in'] > 0
                                        ? Colors.green
                                        : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )),
                                DataCell(Text(
                                  movement['out'] > 0
                                      ? movement['out'].toStringAsFixed(2)
                                      : '-',
                                  style: TextStyle(
                                    color: movement['out'] > 0
                                        ? Colors.red
                                        : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )),
                                DataCell(Text(
                                  movement['balance'].toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                )),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
 */

/* Widget _buildMovementsTable(List<QueryDocumentSnapshot> docs) {
  // تجميع البيانات حسب المنتج
  final Map<String, List<Map<String, dynamic>>> itemMovements = {};

  for (var doc in docs) {
    try {
      final data = doc.data() as Map<String, dynamic>;
      
      final itemId = data['itemId']?.toString() ?? '';
      final type = data['type']?.toString() ?? 'unknown';
      
      // تحويل الكمية إلى double بشكل آمن
      double quantity = 0;
      final quantityValue = data['quantity'];
      if (quantityValue is int) {
        quantity = quantityValue.toDouble();
      } else if (quantityValue is double) {
        quantity = quantityValue;
      } else if (quantityValue is String) {
        quantity = double.tryParse(quantityValue) ?? 0;
      } else if (quantityValue is num) {
        quantity = quantityValue.toDouble();
      }
      
      final timestamp = data['date'] as Timestamp?;
      final date = timestamp != null ? timestamp.toDate() : DateTime.now();

      final movementInfo = MovementUtils.getMovementTypeInfo(type, quantity);

      if (!itemMovements.containsKey(itemId)) {
        itemMovements[itemId] = [];
      }

      // إضافة الحركة
      itemMovements[itemId]!.add({
        'date': date,
        'type': type,
        'in': movementInfo['in'],
        'out': movementInfo['out'],
        'type_text': movementInfo['type_text'],
        'quantity': quantity,
        'documentId': doc.id, // حفظ معرف المستند للترتيب
      });
    } catch (e) {
      safeDebugPrint('[ERROR] Processing movement: $e');
    }
  }

  if (!mounted) {
    return const SizedBox.shrink();
  }

  return ListView.builder(
    itemCount: itemMovements.length,
    itemBuilder: (context, index) {
      if (!mounted) {
        return const SizedBox.shrink();
      }

      final itemId = itemMovements.keys.elementAt(index);
      final movements = itemMovements[itemId]!;
      final itemName = itemNames[itemId] ?? 'Unknown Item'.tr();
      final currentStock = itemStocks[itemId] ?? 0;

      // ترتيب الحركات من الأقدم إلى الأحدث لحساب الرصيد بشكل صحيح
      movements.sort((a, b) => a['date'].compareTo(b['date']));
      
      // حساب الرصيد أول الفترة (من المخزون الحالي والحركات)
      double openingBalance = currentStock;
      for (var movement in movements) {
        openingBalance = openingBalance - movement['in'] + movement['out'];
      }
      
      double runningBalance = openingBalance;
      final movementsWithBalance = [];
      
      for (var movement in movements) {
        runningBalance = runningBalance + movement['in'] - movement['out'];
        movementsWithBalance.add({
          ...movement,
          'balance': runningBalance,
        });
      }
      
      final closingBalance = runningBalance;

      // تطبيق الترتيب المطلوب (أحدث أولاً أو أقدم أولاً)
      final displayMovements = sortOrder == 'desc' 
          ? movementsWithBalance.reversed.toList()
          : movementsWithBalance;

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // عنوان المنتج والرصيد الحالي
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '${'item'.tr()}: $itemName',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${'opening_balance'.tr()}: ${openingBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        '${'closing_balance'.tr()}: ${closingBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // جدول الحركات مع تمرير مزدوج
              SizedBox(
                height: 300,
                child: Scrollbar(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 16,
                        dataRowMinHeight: 40,
                        dataRowMaxHeight: 60,
                        headingRowHeight: 40,
                        columns: [
                          const DataColumn(
                              label: Text('#',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              numeric: true),
                          DataColumn(
                            label: Text('date'.tr(),
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          DataColumn(
                            label: Text('movement_type'.tr(),
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          DataColumn(
                              label: Text('in'.tr(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green)),
                              numeric: true),
                          DataColumn(
                              label: Text('out'.tr(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red)),
                              numeric: true),
                          DataColumn(
                              label: Text('balance'.tr(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue)),
                              numeric: true),
                        ],
                        rows: List<DataRow>.generate(displayMovements.length, (index) {
                          final movement = displayMovements[index];
                          return DataRow(
                            cells: [
                              DataCell(Text((index + 1).toString())),
                              DataCell(Text(_formatDate(movement['date']))),
                              DataCell(Text(movement['type_text'])),
                              DataCell(Text(
                                movement['in'] > 0
                                    ? movement['in'].toStringAsFixed(2)
                                    : '-',
                                style: TextStyle(
                                  color: movement['in'] > 0
                                      ? Colors.green
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              )),
                              DataCell(Text(
                                movement['out'] > 0
                                    ? movement['out'].toStringAsFixed(2)
                                    : '-',
                                style: TextStyle(
                                  color: movement['out'] > 0
                                      ? Colors.red
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              )),
                              DataCell(Text(
                                movement['balance'].toStringAsFixed(2),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              )),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
 */

/*   pw.Padding _buildPdfDataCell(String text, pw.Font font,
      {pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, font: font),
        textAlign: align,
      ),
    );
  }
 */
