/* import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class InventoryQueryPage extends StatefulWidget {
  const InventoryQueryPage({super.key});

  @override
  State<InventoryQueryPage> createState() => _InventoryQueryPageState();
}

class _InventoryQueryPageState extends State<InventoryQueryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  bool get _isArabic => context.locale.languageCode == 'ar';
  final List<Map<String, dynamic>> _inventoryResults = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchInventory(showAll: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

Future<void> _searchInventory({bool showAll = false}) async {
  if (_searchQuery.isEmpty && !showAll) {
    setState(() {
      _inventoryResults.clear();
    });
    return;
  }

  setState(() => _isLoading = true);
  _inventoryResults.clear();

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    safeDebugPrint('--- _searchInventory started ---');
    safeDebugPrint('User ID: ${user.uid}');

    // 1. بيانات المستخدم
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data();

    final userCompanyIds = (userData?['companyIds'] as List?)?.cast<String>() ?? [];
    final userFactoryIds = (userData?['factoryIds'] as List?)?.cast<String>() ?? [];

    safeDebugPrint('User companyIds: $userCompanyIds');
    safeDebugPrint('User factories: $userFactoryIds');

    // 2. الأصناف التي يملكها المستخدم
    final itemsSnapshot = await FirebaseFirestore.instance
        .collection('items')
        .where('userId', isEqualTo: user.uid)
        .get();

    final userProducts = <String, Map<String, dynamic>>{};
    for (var doc in itemsSnapshot.docs) {
      userProducts[doc.id] = doc.data();
    }

    safeDebugPrint('User products count: ${userProducts.length}');
    if (userProducts.isEmpty) {
      safeDebugPrint('No user products found.');
      setState(() {
        _inventoryResults.clear();
        _isLoading = false;
      });
      return;
    }

    // 3. تفحص كل مصنع مرتبط بالمستخدم
    for (final factoryId in userFactoryIds) {
      final factoryDoc = await FirebaseFirestore.instance.collection('factories').doc(factoryId).get();
      final factoryData = factoryDoc.data();
      if (factoryData == null) continue;

      final factoryCompanyIds = (factoryData['companyIds'] as List?)?.cast<String>() ?? [];

      if (!factoryCompanyIds.any((id) => userCompanyIds.contains(id))) {
        safeDebugPrint('Factory $factoryId ignored: no matching user company.');
        continue;
      }

      safeDebugPrint('Processing factory: $factoryId');

      // 4. جلب مخزون المصنع
      final inventorySnapshot = await FirebaseFirestore.instance
          .collection('factories/$factoryId/inventory')
          .get();

      safeDebugPrint('Inventory count in factory $factoryId: ${inventorySnapshot.docs.length}');

      for (final invDoc in inventorySnapshot.docs) {
        final itemId = invDoc.id;

        // فقط المنتجات التي يملكها المستخدم
        if (!userProducts.containsKey(itemId)) {
          safeDebugPrint('Inventory product $itemId ignored: not in user products.');
          continue;
        }

        final productData = userProducts[itemId]!;
        final inventoryData = invDoc.data();

        final productName = _isArabic
            ? (productData['nameAr'] ?? productData['nameEn'] ?? '')
            : (productData['nameEn'] ?? productData['nameAr'] ?? '');

        // فلترة البحث
        if (!showAll &&
            _searchQuery.isNotEmpty &&
            !productName.toLowerCase().contains(_searchQuery.toLowerCase())) {
          safeDebugPrint('Inventory product $itemId ignored: search query mismatch.');
          continue;
        }

        final factoryName = _isArabic
            ? (factoryData['nameAr'] ?? factoryData['nameEn'] ?? '')
            : (factoryData['nameEn'] ?? factoryData['nameAr'] ?? '');

        // جلب أسماء الشركات ذات الصلة
        final relevantCompanyNames = <String>[];
        for (final companyId in factoryCompanyIds) {
          if (userCompanyIds.contains(companyId)) {
            final companyDoc = await FirebaseFirestore.instance
                .collection('companies')
                .doc(companyId)
                .get();
            final companyData = companyDoc.data();
            if (companyData != null) {
              final companyName = _isArabic
                  ? (companyData['nameAr'] ?? companyData['nameEn'] ?? '')
                  : (companyData['nameEn'] ?? companyData['nameAr'] ?? '');
              if (companyName.isNotEmpty) relevantCompanyNames.add(companyName);
            }
          }
        }

        _inventoryResults.add({
          'itemId': itemId,
          'productName': productName,
          'quantity': inventoryData['quantity'] ?? 0,
          'factoryId': factoryId,
          'factoryName': factoryName,
          'companyNames': relevantCompanyNames,
          'lastUpdated': inventoryData['lastUpdated'],
        });

        safeDebugPrint('Added inventory result: ${_inventoryResults.last}');
      }
    }

    safeDebugPrint('Total inventory results: ${_inventoryResults.length}');
    safeDebugPrint('--- _searchInventory finished ---');
  } catch (e) {
    safeDebugPrint('Search error: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error_loading_data'.tr())),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  Widget _buildResultsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_inventoryResults.isEmpty && _searchQuery.isNotEmpty) {
      return Center(child: Text('no_results'.tr()));
    }

    if (_inventoryResults.isEmpty) {
      return Center(child: Text('search_products_hint'.tr()));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _inventoryResults.length,
      itemBuilder: (context, index) {
        final item = _inventoryResults[index];
        return _buildInventoryItem(item);
      },
    );
  }

  Widget _buildInventoryItem(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        title: Text(
          item['productName'] ?? 'Unknown Product',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${'quantity'.tr()}: ${item['quantity'] ?? 0}'),
            Text('${'factory'.tr()}: ${item['factoryName']}'),
            if (item['companyNames'] != null &&
                (item['companyNames'] as List).isNotEmpty)
              Text(
                  '${'companies'.tr()}: ${(item['companyNames'] as List).join(", ")}'),
            if (item['lastUpdated'] != null)
              Text(
                  '${'last_updated'.tr()}: ${_formatDate(item['lastUpdated'])}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.history, size: 20),
          onPressed: () =>
              _showStockHistory(item['itemId'], item['factoryId']),
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    try {
      if (date is Timestamp) {
        return DateFormat('yyyy-MM-dd HH:mm').format(date.toDate());
      }
      return 'Unknown date';
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'inventory_query'.tr(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'search_products'.tr(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _searchInventory(),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSubmitted: (value) => _searchInventory(),
            ),
            const SizedBox(height: 20),
            Expanded(child: _buildResultsList()),
          ],
        ),
      ),
    );
  }

  Future<void> _showStockHistory(String itemId, String factoryId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('stock_history'.tr()),
        content: FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collectionGroup('stock_movements')
              .where('itemId', isEqualTo: itemId)
              .where('factoryId', isEqualTo: factoryId)
              .orderBy('date', descending: true)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Text('no_stock_history'.tr());
            }

            final movements = snapshot.data!.docs;

            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: movements.length,
                itemBuilder: (context, index) {
                  final data = movements[index].data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text('${data['type']}: ${data['quantity']}'),
                    subtitle: Text(DateFormat('yyyy-MM-dd HH:mm')
                        .format((data['date'] as Timestamp).toDate())),
                    trailing: Text(data['referenceId'] ?? ''),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
 */

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class InventoryQueryPage extends StatefulWidget {
  const InventoryQueryPage({super.key});

  @override
  State<InventoryQueryPage> createState() => _InventoryQueryPageState();
}

class _InventoryQueryPageState extends State<InventoryQueryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  bool get _isArabic => context.locale.languageCode == 'ar';
  final List<Map<String, dynamic>> _inventoryResults = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchInventory(showAll: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchInventory({bool showAll = false}) async {
    if (_searchQuery.isEmpty && !showAll) {
      setState(() {
        _inventoryResults.clear();
      });
      return;
    }

    setState(() => _isLoading = true);
    _inventoryResults.clear();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      safeDebugPrint('--- _searchInventory started ---');
      safeDebugPrint('User ID: ${user.uid}');

      // 1. بيانات المستخدم
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      final userCompanyIds = (userData?['companyIds'] as List?)?.cast<String>() ?? [];
      final userFactoryIds = (userData?['factoryIds'] as List?)?.cast<String>() ?? [];

      safeDebugPrint('User companyIds: $userCompanyIds');
      safeDebugPrint('User factories: $userFactoryIds');

      // 2. الأصناف التي يملكها المستخدم
      final itemsSnapshot = await FirebaseFirestore.instance
          .collection('items')
          .where('userId', isEqualTo: user.uid)
          .get();

      final userProducts = <String, Map<String, dynamic>>{};
      for (var doc in itemsSnapshot.docs) {
        userProducts[doc.id] = doc.data();
      }

      safeDebugPrint('User products count: ${userProducts.length}');
      if (userProducts.isEmpty) {
        safeDebugPrint('No user products found.');
        setState(() {
          _inventoryResults.clear();
          _isLoading = false;
        });
        return;
      }

      // 3. تفحص كل مصنع مرتبط بالمستخدم
      for (final factoryId in userFactoryIds) {
        final factoryDoc = await FirebaseFirestore.instance.collection('factories').doc(factoryId).get();
        final factoryData = factoryDoc.data();
        if (factoryData == null) continue;

        final factoryCompanyIds = (factoryData['companyIds'] as List?)?.cast<String>() ?? [];

        if (!factoryCompanyIds.any((id) => userCompanyIds.contains(id))) {
          safeDebugPrint('Factory $factoryId ignored: no matching user company.');
          continue;
        }

        safeDebugPrint('Processing factory: $factoryId');

        // 4. جلب مخزون المصنع
        final inventorySnapshot = await FirebaseFirestore.instance
            .collection('factories/$factoryId/inventory')
            .get();

        safeDebugPrint('Inventory count in factory $factoryId: ${inventorySnapshot.docs.length}');

        for (final invDoc in inventorySnapshot.docs) {
          final itemId = invDoc.id;

          // فقط المنتجات التي يملكها المستخدم
          if (!userProducts.containsKey(itemId)) {
            safeDebugPrint('Inventory product $itemId ignored: not in user products.');
            continue;
          }

          final productData = userProducts[itemId]!;
          final inventoryData = invDoc.data();

          final productName = _isArabic
              ? (productData['nameAr'] ?? productData['nameEn'] ?? '')
              : (productData['nameEn'] ?? productData['nameAr'] ?? '');

          // فلترة البحث
          if (!showAll &&
              _searchQuery.isNotEmpty &&
              !productName.toLowerCase().contains(_searchQuery.toLowerCase())) {
            safeDebugPrint('Inventory product $itemId ignored: search query mismatch.');
            continue;
          }

          final factoryName = _isArabic
              ? (factoryData['nameAr'] ?? factoryData['nameEn'] ?? '')
              : (factoryData['nameEn'] ?? factoryData['nameAr'] ?? '');

          // جلب أسماء الشركات ذات الصلة
          final relevantCompanyNames = <String>[];
          for (final companyId in factoryCompanyIds) {
            if (userCompanyIds.contains(companyId)) {
              final companyDoc = await FirebaseFirestore.instance
                  .collection('companies')
                  .doc(companyId)
                  .get();
              final companyData = companyDoc.data();
              if (companyData != null) {
                final companyName = _isArabic
                    ? (companyData['nameAr'] ?? companyData['nameEn'] ?? '')
                    : (companyData['nameEn'] ?? companyData['nameAr'] ?? '');
                if (companyName.isNotEmpty) relevantCompanyNames.add(companyName);
              }
            }
          }

          _inventoryResults.add({
            'itemId': itemId,
            'productName': productName,
            'quantity': inventoryData['quantity'] ?? 0,
            'factoryId': factoryId,
            'factoryName': factoryName,
            'companyNames': relevantCompanyNames,
            'lastUpdated': inventoryData['lastUpdated'],
          });

          safeDebugPrint('Added inventory result: ${_inventoryResults.last}');
        }
      }

      safeDebugPrint('Total inventory results: ${_inventoryResults.length}');
      safeDebugPrint('--- _searchInventory finished ---');
    } catch (e) {
      safeDebugPrint('Search error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_loading_data'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildResultsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_inventoryResults.isEmpty && _searchQuery.isNotEmpty) {
      return Center(child: Text('no_results'.tr()));
    }

    if (_inventoryResults.isEmpty) {
      return Center(child: Text('search_products_hint'.tr()));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _inventoryResults.length,
      itemBuilder: (context, index) {
        final item = _inventoryResults[index];
        return _buildInventoryItem(item);
      },
    );
  }

  Widget _buildInventoryItem(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Text(
          item['productName'] ?? 'unknown_product'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.inventory, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${'quantity'.tr()}: ${item['quantity'] ?? 0}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.factory, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${'factory'.tr()}: ${item['factoryName']}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                ),
              ],
            ),
            if (item['companyNames'] != null && (item['companyNames'] as List).isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.business, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${'companies'.tr()}: ${(item['companyNames'] as List).join(", ")}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                    ),
                  ),
                ],
              ),
            ],
            if (item['lastUpdated'] != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.update, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${'last_updated'.tr()}: ${_formatDate(item['lastUpdated'])}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.history, size: 24, color: Colors.blue),
              onPressed: () => _showStockHistory(item['itemId'], item['factoryId']),
              tooltip: 'view_history'.tr(),
            ),
            Text(
              'history'.tr(),
              style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    try {
      if (date is Timestamp) {
        return DateFormat('yyyy-MM-dd HH:mm').format(date.toDate());
      }
      return 'unknown_date'.tr();
    } catch (e) {
      return 'invalid_date'.tr();
    }
  }

  // دالة عرض تاريخ الحركات مع دعم الترجمة الكامل
  Future<void> _showStockHistory(String itemId, String factoryId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // إظهار مؤشر تحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // الحصول على companyIds من المستخدم والمصنع
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final userCompanyIds = (userData?['companyIds'] as List?)?.cast<String>() ?? [];

      final factoryDoc = await FirebaseFirestore.instance.collection('factories').doc(factoryId).get();
      final factoryData = factoryDoc.data();
      final factoryCompanyIds = (factoryData?['companyIds'] as List?)?.cast<String>() ?? [];

      // تحديد الشركات المشتركة بين المستخدم والمصنع
      final relevantCompanyIds = userCompanyIds.where((id) => factoryCompanyIds.contains(id)).toList();

      // إغلاق مؤشر التحميل
      if (mounted) {
        Navigator.pop(context);
      }

      if (relevantCompanyIds.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('no_access_to_stock_history'.tr())),
          );
        }
        return;
      }

      // جلب الحركات من جميع الشركات
      final List<QuerySnapshot> allSnapshots = [];
      for (final companyId in relevantCompanyIds) {
        final snapshot = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('stock_movements')
            .where('itemId', isEqualTo: itemId)
            .where('factoryId', isEqualTo: factoryId)
            .orderBy('date', descending: true)
            .get();
        allSnapshots.add(snapshot);
      }

      // جمع كل الحركات
      final allMovements = <QueryDocumentSnapshot>[];
      for (final snapshot in allSnapshots) {
        allMovements.addAll(snapshot.docs);
      }

      // عرض الـ Dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.history, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'stock_history'.tr(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 500,
            child: allMovements.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'no_stock_history'.tr(),
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: allMovements.length,
                    itemBuilder: (context, index) {
                      final doc = allMovements[index];
                      final data = doc.data() as Map<String, dynamic>;
                      
                      final movementType = data['type'] ?? 'unknown';
                      final quantity = data['quantity'] ?? 0;
                      final date = data['date'] as Timestamp?;
                      final referenceId = data['referenceId'];
                      final note = data['note'];
                      final userName = data['userName'];
                      final companyId = doc.reference.parent.parent?.id;
                      
                      final bool isAddition = movementType == 'in' || movementType == 'add' || movementType == 'increase';
                      final String typeText = isAddition ? 'add_stock'.tr() : 'remove_stock'.tr();
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ExpansionTile(
                          leading: Icon(
                            isAddition ? Icons.add_circle_outline : Icons.remove_circle_outline,
                            color: isAddition ? Colors.green : Colors.red,
                            size: 28,
                          ),
                          title: Text(
                            '$typeText: $quantity',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isAddition ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                          subtitle: date != null
                              ? Text(
                                  DateFormat('yyyy-MM-dd HH:mm:ss').format(date.toDate()),
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                )
                              : null,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (referenceId != null && referenceId.toString().isNotEmpty) ...[
                                    _buildInfoRow(Icons.receipt, 'reference_number'.tr(), referenceId.toString()),
                                    const Divider(),
                                  ],
                                  if (note != null && note.toString().isNotEmpty) ...[
                                    _buildInfoRow(Icons.note, 'notes'.tr(), note.toString()),
                                    const Divider(),
                                  ],
                                  if (userName != null && userName.toString().isNotEmpty) ...[
                                    _buildInfoRow(Icons.person, 'performed_by'.tr(), userName.toString()),
                                    const Divider(),
                                  ],
                                  if (companyId != null) ...[
                                    _buildInfoRow(Icons.business, 'company_id'.tr(), companyId),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              label: Text('close'.tr()),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        );
      }
    } catch (e) {
      // إغلاق مؤشر التحميل إذا كان مفتوحاً
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      safeDebugPrint('Error loading stock history: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_loading_history'.tr())),
        );
      }
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'inventory_query'.tr(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'search_products'.tr(),
                hintText: 'enter_product_name'.tr(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchInventory(showAll: true);
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
                ),
              ),
              onSubmitted: (value) => _searchInventory(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_inventoryResults.isNotEmpty)
                  Text(
                    '${'results_count'.tr()}: ${_inventoryResults.length}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                const Spacer(),
                if (_searchQuery.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _searchInventory(showAll: true),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text('show_all'.tr()),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildResultsList()),
          ],
        ),
      ),
    );
  }
}