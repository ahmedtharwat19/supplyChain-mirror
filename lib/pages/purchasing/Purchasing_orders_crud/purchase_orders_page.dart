/* //import 'dart:convert';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:puresip_purchasing/services/firestore_service.dart';
import 'package:puresip_purchasing/utils/pdf_exporter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:puresip_purchasing/widgets/hover_add_button.dart';
import 'package:universal_html/html.dart' as html;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class PurchaseOrdersPage extends StatefulWidget {
  const PurchaseOrdersPage({super.key});

  @override
  State<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> {
  String searchQuery = '';
  bool isLoading = true;
  String? userName;
  final List<Map<String, dynamic>> _allOrders = [];
  final List<Map<String, dynamic>> _filteredOrders = [];
  bool _isSearching = false;
  int _userCompaniesCount = 1;
  String _currentSortOption = 'dateDesc';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _userCompanies = [];
  String? _selectedCompanyId;
  final FirestoreService _firestoreService = FirestoreService();

  //bool get isArabic => Localizations.localeOf(context).languageCode == 'ar';
  late bool _isArabic;

  @override
  void initState() {
    super.initState();
    //_initData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isDataLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isDataLoaded) {
      _isDataLoaded = true;
      setState(() {
        _isArabic = context.locale.languageCode ==
            'ar'; // Localizations.localeOf(context).languageCode == 'ar';
      });
      safeDebugPrint("Current language is Arabic? $_isArabic");
      _initData(); // الدالة التي كانت تُستدعى في initState
    }
  }

  Future<void> _initData() async {
    //   _isArabic = Localizations.localeOf(context).languageCode == 'ar';
    await loadUserInfo();
    await _loadUserCompaniesCount();
    await _loadAllOrders();
    await _loadUserCompanies();
  }

  Future<void> loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final email = user.email ?? '';
      final name = user.displayName ?? '';
      setState(() {
        userName = name.isNotEmpty ? name : email.split('@')[0];
      });
    }
  }

// ── كاش في الذاكرة لأسماء الشركات والموردين ──
  final Map<String, String> _companyNameCache = {};
  final Map<String, String> _supplierNameCache = {};

  Future<void> _loadUserCompaniesCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ✅ اقرأ من SharedPreferences أولاً
    final prefs = await SharedPreferences.getInstance();
    final cachedCount = prefs.getInt('userCompaniesCount');
    if (cachedCount != null) {
      setState(() => _userCompaniesCount = cachedCount);
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = userDoc.data() ?? {};
    final companyIds = List<String>.from(data['companyIds'] ?? []);

    await prefs.setInt('userCompaniesCount', companyIds.length);
    setState(() => _userCompaniesCount = companyIds.length);

    // ✅ نفس الطلب يخدم _loadUserCompanies أيضاً — لا طلب ثانٍ
    await _loadUserCompaniesFromIds(companyIds);
  }

  Future<void> _loadUserCompanies() async {
    // ✅ إذا تم التحميل من _loadUserCompaniesCount لا تكرر
    if (_userCompanies.isNotEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final companyIds = List<String>.from(userDoc.data()?['companyIds'] ?? []);
    await _loadUserCompaniesFromIds(companyIds);
  }

  Future<void> _loadUserCompaniesFromIds(List<String> companyIds) async {
    if (companyIds.isEmpty) return;

    // ✅ طلب واحد whereIn بدل N طلبات
    final snapshot = await FirebaseFirestore.instance
        .collection('companies')
        .where(FieldPath.documentId, whereIn: companyIds)
        .get();

    _userCompanies = snapshot.docs.map((doc) {
      final name = _isArabic
          ? doc.data()['nameAr'] ?? doc.id
          : doc.data()['nameEn'] ?? doc.id;
      // ✅ حفظ في كاش الذاكرة
      _companyNameCache[doc.id] = name;
      return {'id': doc.id, 'name': name};
    }).toList();
  }

  Future<void> _loadAllOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (mounted) setState(() => isLoading = true);

    try {
      // ── 1. اقرأ من SharedPreferences أولاً ──
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cachedOrders');
      final cacheTime = prefs.getInt('cachedOrdersTime') ?? 0;
      final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTime;

      if (cachedJson != null && cacheAge < 300000) {
        // أقل من 5 دقائق

        final List decoded = json.decode(cachedJson);
        _allOrders
          ..clear()
          ..addAll(decoded.cast<Map<String, dynamic>>());
        _filterOrders(searchQuery);
        if (mounted) setState(() => isLoading = false);
        // ✅ حدّث في الخلفية
        _fetchOrdersFromFirestore(user.uid, prefs, background: true);
        return;
      }

      // ── 2. Firestore إذا الكاش قديم أو غير موجود ──
      await _fetchOrdersFromFirestore(user.uid, prefs, background: false);
    } catch (e) {
      safeDebugPrint('Error loading orders: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchOrdersFromFirestore(String userId, SharedPreferences prefs,
      {required bool background}) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('purchase_orders')
          .where('userId', isEqualTo: userId)
          .orderBy('orderDate', descending: true)
          .get();

      // ── جمع كل companyIds و supplierIds الفريدة ──
      final companyIds = <String>{};
      final supplierIds = <String>{};
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        if (data['companyId'] != null) companyIds.add(data['companyId']);
        if (data['supplierId'] != null) supplierIds.add(data['supplierId']);
      }

      // ── جلب الأسماء غير الموجودة في الكاش بطلبين فقط ──
      final missingCompanies =
          companyIds.where((id) => !_companyNameCache.containsKey(id)).toList();
      final missingSuppliers = supplierIds
          .where((id) => !_supplierNameCache.containsKey(id))
          .toList();

      await Future.wait([
        if (missingCompanies.isNotEmpty)
          FirebaseFirestore.instance
              .collection('companies')
              .where(FieldPath.documentId, whereIn: missingCompanies)
              .get()
              .then((snap) {
            for (final doc in snap.docs) {
              _companyNameCache[doc.id] = _isArabic
                  ? doc.data()['nameAr'] ?? doc.id
                  : doc.data()['nameEn'] ?? doc.id;
            }
          }),
        if (missingSuppliers.isNotEmpty)
          FirebaseFirestore.instance
              .collection('vendors')
              .where(FieldPath.documentId, whereIn: missingSuppliers)
              .get()
              .then((snap) {
            for (final doc in snap.docs) {
              _supplierNameCache[doc.id] = _isArabic
                  ? doc.data()['nameAr'] ?? doc.id
                  : doc.data()['nameEn'] ?? doc.id;
            }
          }),
      ]);

// ── بناء القائمة النهائية ──
      final orders = querySnapshot.docs.map((doc) {
        final data = doc.data();

        // ✅ تحويل Timestamps لـ String قبل JSON
        final serializable = data.map((key, value) {
          if (value is Timestamp) {
            return MapEntry(key, value.toDate().toIso8601String());
          }
          return MapEntry(key, value);
        });

        return {
          ...serializable,
          'id': doc.id,
          'companyName': _companyNameCache[data['companyId']] ?? '',
          'supplierName': _supplierNameCache[data['supplierId']] ?? '',
        };
      }).toList();

// ── حفظ في الكاش ──
      try {
        await prefs.setString('cachedOrders', json.encode(orders));
        await prefs.setInt(
            'cachedOrdersTime', DateTime.now().millisecondsSinceEpoch);
      } catch (e) {
        safeDebugPrint('Cache save error: $e');
      }

      if (mounted) {
        _allOrders
          ..clear()
          ..addAll(orders);
        _filterOrders(searchQuery);
        setState(() => isLoading = false);
      }
    } catch (e) {
      safeDebugPrint('Firestore fetch error: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

/*   Future<void> _loadUserCompanies() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final List companyIds = doc.data()?['companyIds'] ?? [];

    final futures = companyIds.map((id) async {
      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(id)
          .get();
      return {
        'id': id,
        'name':
            _isArabic ? companyDoc['nameAr'] ?? id : companyDoc['nameEn'] ?? id,
      };
    }).toList();

    _userCompanies = await Future.wait(futures);
  }

  Future<void> _loadUserCompaniesCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final cachedCount = prefs.getInt('userCompaniesCount');

    if (cachedCount != null) {
      setState(() => _userCompaniesCount = cachedCount);
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final companyIds = (userDoc.data()?['companyIds'] as List?)?.length ?? 1;
    await prefs.setInt('userCompaniesCount', companyIds);
    setState(() => _userCompaniesCount = companyIds);
    //safeDebugPrint('User companies count: $_userCompaniesCount');
  }
 */

/*   Future<String> _getCompanyName(String companyId, bool isArabic) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();

      if (isArabic) {
        return doc.data()?['nameAr'] ?? companyId;
      } else {
        return doc.data()?['nameEn'] ?? companyId;
      }
    } catch (e) {
      return companyId;
    }
  }

  Future<String> _getSupplierName(String supplierId, bool isArabic) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(supplierId)
          .get();
      if (isArabic) {
        return doc.data()?['nameAr'] ?? supplierId;
      } else {
        return doc.data()?['nameEn'] ?? supplierId;
      }
    } catch (e) {
      return supplierId;
    }
  }
 */

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

/*   Future<void> _loadAllOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    if (mounted) setState(() => isLoading = true);

    try {
      // إلغاء التخزين المؤقت completamente
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cachedOrders'); // احذف الكاش القديم

      Query query = FirebaseFirestore.instance
          .collection('purchase_orders')
          .where('userId', isEqualTo: user.uid)
          .orderBy('orderDate', descending: true); // الترتيب الافتراضي

      final querySnapshot = await query.get();

      if (!mounted) return;

      final orders = querySnapshot.docs;
      final futures = orders.map((doc) async {
        final data = doc.data() as Map<String, dynamic>;
        final companyId = data['companyId'] as String? ?? '';
        final supplierId = data['supplierId'] as String? ?? '';

        final company = await _getCompanyName(companyId, _isArabic);
        final supplier = await _getSupplierName(supplierId, _isArabic);

        return {
          ...data,
          'id': doc.id,
          'companyName': company,
          'supplierName': supplier,
        };
      }).toList();

      _allOrders.clear();
      _allOrders.addAll(await Future.wait<Map<String, dynamic>>(futures));

      _filterOrders(searchQuery);
    } catch (e) {
      safeDebugPrint('Error loading orders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_loading_orders'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
 */

  Future<void> _refreshAfterUpdate() async {
    if (mounted) {
      setState(() => isLoading = true);
      await Future.delayed(const Duration(milliseconds: 500)); // انتظر قليلاً
      await _loadAllOrders();
    }
  }

  void _sortOrders() {
    _allOrders.sort((a, b) {
      try {
        Timestamp aDate;
        Timestamp bDate;

        // معالجة aDate
        if (a['orderDate'] is Timestamp) {
          aDate = a['orderDate'] as Timestamp;
        } else if (a['orderDate'] is int) {
          aDate = Timestamp.fromMillisecondsSinceEpoch(a['orderDate']);
        } else {
          aDate = Timestamp.now();
        }

        // معالجة bDate
        if (b['orderDate'] is Timestamp) {
          bDate = b['orderDate'] as Timestamp;
        } else if (b['orderDate'] is int) {
          bDate = Timestamp.fromMillisecondsSinceEpoch(b['orderDate']);
        } else {
          bDate = Timestamp.now();
        }

        switch (_currentSortOption) {
          case 'dateDesc':
            return bDate.compareTo(aDate);
          case 'dateAsc':
            return aDate.compareTo(bDate);
          case 'amountDesc':
            return (b['totalAmountAfterTax'] as num)
                .compareTo(a['totalAmountAfterTax'] as num);
          case 'amountAsc':
            return (a['totalAmountAfterTax'] as num)
                .compareTo(b['totalAmountAfterTax'] as num);
          default:
            return 0;
        }
      } catch (e) {
        safeDebugPrint('Error sorting orders: $e');
        return 0;
      }
    });
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = _searchController.text.toLowerCase();
      _filterOrders(searchQuery);
    });
  }

  void _filterOrders(String query) {
    _filteredOrders.clear();
    _filteredOrders.addAll(_allOrders.where((order) {
      final matchesQuery = [
        (order['poNumber'] ?? '').toString().toLowerCase(),
        (order['supplierName'] ?? '').toString().toLowerCase(),
        (order['companyName'] ?? '').toString().toLowerCase(),
        (order['status'] ?? '').toString().toLowerCase(),
      ].any((field) => field.contains(query.toLowerCase()));

      final matchesCompany = _selectedCompanyId == null ||
          order['companyId'] == _selectedCompanyId;

      return matchesQuery && matchesCompany;
    }));
  }

  void _showCompanySelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: Text('show_all'.tr()),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedCompanyId = null;
                  _filterOrders(searchQuery);
                });
              },
            ),
            ..._userCompanies.map((company) => ListTile(
                  leading: const Icon(Icons.business),
                  title: Text(company['name']),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedCompanyId = company['id'];
                      _filterOrders(searchQuery);
                    });
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('sort_by_date_desc'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentSortOption = 'dateDesc';
                    _sortOrders();
                    _filterOrders(searchQuery);
                  });
                },
              ),
              ListTile(
                title: Text('sort_by_date_asc'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentSortOption = 'dateAsc';
                    _sortOrders();
                    _filterOrders(searchQuery);
                  });
                },
              ),
              ListTile(
                title: Text('sort_by_amount_desc'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentSortOption = 'amountDesc';
                    _sortOrders();
                    _filterOrders(searchQuery);
                  });
                },
              ),
              ListTile(
                title: Text('sort_by_amount_asc'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentSortOption = 'amountAsc';
                    _sortOrders();
                    _filterOrders(searchQuery);
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

/*   void _editOrder(Map<String, dynamic> order) {
    context.push('/purchase/${order['id']}');
  } */

  void _editOrder(Map<String, dynamic> order) async {
    safeDebugPrint('✏️ Editing order: ${order['poNumber']}');

    final result = await context.push(
      '/purchase/${order['id']}',
      extra: order,
    );

    safeDebugPrint('🔍 Result from edit page: $result');

    if (result == true && mounted) {
      safeDebugPrint('🔄 Order was updated, refreshing list...');
      setState(() => isLoading = true);
      await _loadAllOrders();
      _filterOrders(searchQuery);
      setState(() => isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('order_updated_successfully'.tr()),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      safeDebugPrint('ℹ️ Order was not updated or result is false');
    }
  }

  Future<void> _exportOrder(Map<String, dynamic> order) async {
    setState(() => _isSearching = true);
    try {
      final companyData = await FirebaseFirestore.instance
          .collection('companies')
          .doc(order['companyId'])
          .get();

      final supplierData = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(order['supplierId'])
          .get();

      // تحديث order بعد تعديل العناصر
      //   order['items'] = orderItems;
      final companyDataMap = companyData.data() ?? {};
      final base64Logo = companyDataMap['logoBase64'] as String?;

      final pdf = await PdfExporter.generatePurchaseOrderPdf(
        orderId: order['id'],
        orderData: order,
        supplierData: supplierData.data() ?? {},
        companyData: companyData.data() ?? {},
        itemData: {
          'items': order['items'],
        }, //itemsDataMap,
        base64Logo: base64Logo,
        isArabic: _isArabic,
      );

      final bytes = await pdf.save();

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..download = 'order_${order['poNumber'] ?? order['id']}.pdf'
          ..style.display = 'none';

        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getTemporaryDirectory();
        final file =
            File('${dir.path}/order_${order['poNumber'] ?? order['id']}.pdf');
        await file.writeAsBytes(bytes);
        await Printing.sharePdf(
          bytes: bytes,
          filename: 'order_${order['poNumber'] ?? order['id']}.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'export_error'.tr()}: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      safeDebugPrint('PDF Export Error: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _confirmDeleteOrder(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_delete'.tr()),
        content: Text('delete_order_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              safeDebugPrint(
                  '🧪 Trying to delete order with ID: ${order['id']}');

              _deleteOrder(order);
            },
            child:
                Text('delete'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteOrder(Map<String, dynamic> order) async {
    try {
      await FirebaseFirestore.instance
          .collection('purchase_orders')
          .doc(order['id'])
          .delete();
      safeDebugPrint('🧪 Trying to delete order with ID: ${order['id']}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('order_deleted'.tr())),
        );
        _loadAllOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('delete_error'.tr())),
        );
      }
    }
  }

  Future<void> _updateOrderStatus(
    String orderId,
    String companyId,
    String newStatus,
    List<dynamic> items,
    String factoryId,
  ) async {
    try {
      safeDebugPrint('=== STARTING ORDER STATUS UPDATE ===');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final orderRef =
          FirebaseFirestore.instance.collection('purchase_orders').doc(orderId);

      // تحديث الحالة
      safeDebugPrint('📝 Updating order status to: $newStatus');
      await orderRef.update({
        'status': newStatus,
        'isDelivered': newStatus == 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ✅ استخدم الدالة المشتركة لتحديث المخزون
      if (newStatus == 'completed') {
        safeDebugPrint('📦 Processing inventory via FirestoreService...');
        await _firestoreService.processStockDelivery(
          companyId: companyId,
          factoryId: factoryId,
          orderId: orderId,
          userId: user.uid,
          items: items,
        );
      }

      safeDebugPrint('🎉 Order status updated successfully');

      await _refreshAfterUpdate();
    } catch (e, stackTrace) {
      safeDebugPrint('❌ ERROR updating order status: $e');
      safeDebugPrint('🔍 Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('update_error'.tr())),
        );
      }
    }
  }

/*   Future<void> _updateOrderStatus(
    String orderId,
    String companyId,
    String newStatus,
    List<dynamic> items,
    String factoryId,
  ) async {
    try {
      safeDebugPrint('=== STARTING ORDER STATUS UPDATE ===');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final orderRef =
          FirebaseFirestore.instance.collection('purchase_orders').doc(orderId);

      // 1. تحديث الحقل الرئيسي
      safeDebugPrint('📝 Updating order status to: $newStatus');
      await orderRef.update(
          {'status': newStatus, 'isDelivered' : true,'updatedAt': FieldValue.serverTimestamp()});

      // 2. معالجة المخزون فقط إذا تم التسليم
      if (newStatus == 'completed') {
        safeDebugPrint('📦 Processing inventory for completed order');

        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          final itemId = itemMap['itemId']?.toString();
          final quantity = _parseQuantity(itemMap['quantity']);

          if (itemId == null || itemId.isEmpty || quantity <= 0) continue;

          try {
            // تسجيل حركة المخزن
            await FirebaseFirestore.instance
                .collection('companies/$companyId/stock_movements')
                .add({
              'type': 'purchase',
              'itemId': itemId,
              'quantity': quantity,
              'date': FieldValue.serverTimestamp(),
              'referenceId': orderId,
              'userId': user.uid,
              'factoryId': factoryId,
            });

            // تحديث المخزون
            final stockRef = FirebaseFirestore.instance
                .collection('factories/$factoryId/inventory')
                .doc(itemId);

            await stockRef.set({
              'quantity': FieldValue.increment(quantity),
              'lastUpdated': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (e) {
            safeDebugPrint('❌ Error processing item $itemId: $e');
          }
        }
      }

      safeDebugPrint('🎉 Order status updated successfully');

      // 3. إعادة تحميل البيانات بعد التحديث
      await _refreshAfterUpdate();
    } catch (e, stackTrace) {
      safeDebugPrint('❌ ERROR updating order status: $e');
      safeDebugPrint('🔍 Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('update_error'.tr())),
        );
      }
    }
  }
 */
// دالة مساعدة لتحويل الكمية
/*   double _parseQuantity(dynamic quantity) {
    try {
      if (quantity == null) return 0.0;
      if (quantity is int) return quantity.toDouble();
      if (quantity is double) return quantity;
      if (quantity is String) return double.tryParse(quantity) ?? 0.0;
      return 0.0;
    } catch (e) {
      safeDebugPrint('Error parsing quantity: $quantity, error: $e');
      return 0.0;
    }
  }
 */

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final netPayable = NumberFormat.currency(
      symbol: '',
      decimalDigits: 2,
    ).format(order['netPayable'] ?? 0);

    //  bool isDelivered = order['status'] == 'completed';
    DateTime orderDate;
    try {
      if (order['orderDate'] is Timestamp) {
        orderDate = (order['orderDate'] as Timestamp).toDate();
      } else if (order['orderDate'] is int) {
        orderDate = DateTime.fromMillisecondsSinceEpoch(order['orderDate']);
      } else {
        orderDate = DateTime.now(); // قيمة افتراضية
      }
    } catch (e) {
      orderDate = DateTime.now();
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getStatusColor(order['status']).withAlpha(76),
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // onTap: () => context.push('/purchase/${order['id']}'),
        onTap: () => context.push(
          '/purchase/${order['id']}', // أو إذا كان order['id']، فتأكد أنها Map
          extra: order, // هذا تمرير كائن كامل
        ),

        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order['poNumber'] ?? '${order['id']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order['status']),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (order['status'] ?? 'pending').toString().toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (_userCompaniesCount > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.business, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order['companyName'] ?? '',
                          style: TextStyle(color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order['supplierName'] ?? '',
                        style: TextStyle(color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16, thickness: 1),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateFormat('yyyy-MM-dd').format(orderDate),
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '$netPayable ${'currency'.tr()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              if (order['status'] == 'pending')
                SwitchListTile(
                  title: Text('delivered'.tr()),
                  value: order['status'] == 'completed',
                  onChanged: (val) async {
                    // إضافة تأكيد قبل التغيير
                    if (val) {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('confirm_delivery'.tr()),
                          content: Text('confirm_mark_delivered'.tr()),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('cancel'.tr()),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text('confirm'.tr()),
                            ),
                          ],
                        ),
                      );

                      if (confirmed != true) return;
                    }

                    await _updateOrderStatus(
                      order['id'],
                      order['companyId'],
                      val ? 'completed' : 'pending',
                      order['items'],
                      order['factoryId'],
                    );

                    if (mounted) {
                      await _loadAllOrders(); // إعادة تحميل البيانات
                    }
                  },
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (order['status'] == 'pending')
                    IconButton(
                      icon:
                          const Icon(Icons.edit, size: 20, color: Colors.blue),
                      tooltip: 'edit'.tr(),
                      onPressed: () => _editOrder(order),
                    ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf,
                        size: 20, color: Colors.green),
                    tooltip: 'export_pdf'.tr(),
                    onPressed: () => _exportOrder(order),
                  ),
                  if (order['status'] == 'pending')
                    IconButton(
                      icon:
                          const Icon(Icons.delete, size: 20, color: Colors.red),
                      tooltip: 'delete'.tr(),
                      onPressed: () => _confirmDeleteOrder(order),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return AppScaffold(
        title: 'purchase_orders'.tr(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    safeDebugPrint('User companies count: $_userCompaniesCount');

    return Directionality(
      textDirection: Directionality.of(context),
      child: AppScaffold(
        title: 'purchase_orders'.tr(),
        actions: [
          HoverAddButton(
            onPressed: () async {
              final result = await context.push('/add-purchase-order');
              if (result == true && mounted) await _loadAllOrders();
              _filterOrders(searchQuery);
            },
            tooltip: 'add_purchase_order'.tr(),
            iconColor: Colors.white,
            iconSize: 28,
          ),
        ],
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8), // const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'search'.tr(),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: 'search_hint'.tr(),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_userCompaniesCount > 1)
                    IconButton(
                      icon: const Icon(Icons.business),
                      tooltip: 'multiple_companies'.tr(),
                      onPressed: _showCompanySelector,
                    ),
                  IconButton(
                    icon: const Icon(Icons.sort),
                    onPressed: _showSortOptions,
                    tooltip: 'sort_options'.tr(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredOrders.isEmpty
                      ? Center(child: Text('no_match_search'.tr()))
                      : RefreshIndicator(
                          onRefresh: _loadAllOrders,
                          child: ListView.builder(
                            itemCount: _filteredOrders.length,
                            itemBuilder: (ctx, index) {
                              final order = _filteredOrders[index];
                              return _buildOrderCard(order);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
 */

/* 
//import 'dart:convert';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:puresip_purchasing/services/firestore_service.dart';
import 'package:puresip_purchasing/utils/pdf_exporter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:puresip_purchasing/widgets/hover_add_button.dart';
import 'package:universal_html/html.dart' as html;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/utils/delivery_note_pdf.dart';

class PurchaseOrdersPage extends StatefulWidget {
  const PurchaseOrdersPage({super.key});

  @override
  State<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> {
  String searchQuery = '';
  bool isLoading = true;
  String? userName;
  final List<Map<String, dynamic>> _allOrders = [];
  final List<Map<String, dynamic>> _filteredOrders = [];
  bool _isSearching = false;
  int _userCompaniesCount = 1;
  String _currentSortOption = 'dateDesc';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _userCompanies = [];
  String? _selectedCompanyId;
  final FirestoreService _firestoreService = FirestoreService();

  late bool _isArabic;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isDataLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isDataLoaded) {
      _isDataLoaded = true;
      setState(() {
        _isArabic = context.locale.languageCode == 'ar';
      });
      safeDebugPrint("Current language is Arabic? $_isArabic");
      _initData();
    }
  }

  Future<void> _initData() async {
    await loadUserInfo();
    await _loadUserCompaniesCount();
    await _loadAllOrders();
    await _loadUserCompanies();
  }

  Future<void> loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final email = user.email ?? '';
      final name = user.displayName ?? '';
      setState(() {
        userName = name.isNotEmpty ? name : email.split('@')[0];
      });
    }
  }

  // ── كاش في الذاكرة لأسماء الشركات والموردين ──
  final Map<String, String> _companyNameCache = {};
  final Map<String, String> _supplierNameCache = {};

  Future<void> _loadUserCompaniesCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final cachedCount = prefs.getInt('userCompaniesCount');
    if (cachedCount != null) {
      setState(() => _userCompaniesCount = cachedCount);
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = userDoc.data() ?? {};
    final companyIds = List<String>.from(data['companyIds'] ?? []);

    await prefs.setInt('userCompaniesCount', companyIds.length);
    setState(() => _userCompaniesCount = companyIds.length);

    await _loadUserCompaniesFromIds(companyIds);
  }

  Future<void> _loadUserCompanies() async {
    if (_userCompanies.isNotEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final companyIds = List<String>.from(userDoc.data()?['companyIds'] ?? []);
    await _loadUserCompaniesFromIds(companyIds);
  }

  Future<void> _loadUserCompaniesFromIds(List<String> companyIds) async {
    if (companyIds.isEmpty) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('companies')
        .where(FieldPath.documentId, whereIn: companyIds)
        .get();

    _userCompanies = snapshot.docs.map((doc) {
      final name = _isArabic
          ? doc.data()['nameAr'] ?? doc.id
          : doc.data()['nameEn'] ?? doc.id;
      _companyNameCache[doc.id] = name;
      return {'id': doc.id, 'name': name};
    }).toList();
  }

  Future<void> _loadAllOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (mounted) setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cachedOrders');
      final cacheTime = prefs.getInt('cachedOrdersTime') ?? 0;
      final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTime;

      if (cachedJson != null && cacheAge < 300000) {
        final List decoded = json.decode(cachedJson);
        _allOrders
          ..clear()
          ..addAll(decoded.cast<Map<String, dynamic>>());
        _filterOrders(searchQuery);
        if (mounted) setState(() => isLoading = false);
        _fetchOrdersFromFirestore(user.uid, prefs, background: true);
        return;
      }

      await _fetchOrdersFromFirestore(user.uid, prefs, background: false);
    } catch (e) {
      safeDebugPrint('Error loading orders: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchOrdersFromFirestore(String userId, SharedPreferences prefs,
      {required bool background}) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('purchase_orders')
          .where('userId', isEqualTo: userId)
          .orderBy('orderDate', descending: true)
          .get();

      final companyIds = <String>{};
      final supplierIds = <String>{};
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        if (data['companyId'] != null) companyIds.add(data['companyId']);
        if (data['supplierId'] != null) supplierIds.add(data['supplierId']);
      }

      final missingCompanies =
          companyIds.where((id) => !_companyNameCache.containsKey(id)).toList();
      final missingSuppliers = supplierIds
          .where((id) => !_supplierNameCache.containsKey(id))
          .toList();

      await Future.wait([
        if (missingCompanies.isNotEmpty)
          FirebaseFirestore.instance
              .collection('companies')
              .where(FieldPath.documentId, whereIn: missingCompanies)
              .get()
              .then((snap) {
            for (final doc in snap.docs) {
              _companyNameCache[doc.id] = _isArabic
                  ? doc.data()['nameAr'] ?? doc.id
                  : doc.data()['nameEn'] ?? doc.id;
            }
          }),
        if (missingSuppliers.isNotEmpty)
          FirebaseFirestore.instance
              .collection('vendors')
              .where(FieldPath.documentId, whereIn: missingSuppliers)
              .get()
              .then((snap) {
            for (final doc in snap.docs) {
              _supplierNameCache[doc.id] = _isArabic
                  ? doc.data()['nameAr'] ?? doc.id
                  : doc.data()['nameEn'] ?? doc.id;
            }
          }),
      ]);

      final orders = querySnapshot.docs.map((doc) {
        final data = doc.data();

        final serializable = data.map((key, value) {
          if (value is Timestamp) {
            return MapEntry(key, value.toDate().toIso8601String());
          }
          return MapEntry(key, value);
        });

        return {
          ...serializable,
          'id': doc.id,
          'companyName': _companyNameCache[data['companyId']] ?? '',
          'supplierName': _supplierNameCache[data['supplierId']] ?? '',
        };
      }).toList();

      try {
        await prefs.setString('cachedOrders', json.encode(orders));
        await prefs.setInt(
            'cachedOrdersTime', DateTime.now().millisecondsSinceEpoch);
      } catch (e) {
        safeDebugPrint('Cache save error: $e');
      }

      if (mounted) {
        _allOrders
          ..clear()
          ..addAll(orders);
        _filterOrders(searchQuery);
        setState(() => isLoading = false);
      }
    } catch (e) {
      safeDebugPrint('Firestore fetch error: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<Map<String, dynamic>?> _showDeliveryNoteDialog() async {
    final controller = TextEditingController(
      text: 'DN-${DateFormat('yyyyMMdd').format(DateTime.now())}-01',
    );
    final dateController = TextEditingController(
      text: DateFormat('dd-MM-yyyy').format(DateTime.now()),
    );
    final notesController = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('delivery_note_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: controller,
                decoration: InputDecoration(labelText: 'delivery_number'.tr())),
            TextField(
                controller: dateController,
                decoration: InputDecoration(labelText: 'delivery_date'.tr())),
            TextField(
                controller: notesController,
                decoration: InputDecoration(labelText: 'notes'.tr()),
                maxLines: 2),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text('cancel'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(ctx, {
              'deliveryNumber': controller.text,
              'deliveryDate': dateController.text,
              'notes': notesController.text,
            }),
            child: Text('print'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshAfterUpdate() async {
    if (mounted) {
      setState(() => isLoading = true);
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadAllOrders();
    }
  }

  void _sortOrders() {
    _allOrders.sort((a, b) {
      try {
        Timestamp aDate;
        Timestamp bDate;

        if (a['orderDate'] is Timestamp) {
          aDate = a['orderDate'] as Timestamp;
        } else if (a['orderDate'] is int) {
          aDate = Timestamp.fromMillisecondsSinceEpoch(a['orderDate']);
        } else {
          aDate = Timestamp.now();
        }

        if (b['orderDate'] is Timestamp) {
          bDate = b['orderDate'] as Timestamp;
        } else if (b['orderDate'] is int) {
          bDate = Timestamp.fromMillisecondsSinceEpoch(b['orderDate']);
        } else {
          bDate = Timestamp.now();
        }

        switch (_currentSortOption) {
          case 'dateDesc':
            return bDate.compareTo(aDate);
          case 'dateAsc':
            return aDate.compareTo(bDate);
          case 'amountDesc':
            return (b['totalAmountAfterTax'] as num)
                .compareTo(a['totalAmountAfterTax'] as num);
          case 'amountAsc':
            return (a['totalAmountAfterTax'] as num)
                .compareTo(b['totalAmountAfterTax'] as num);
          default:
            return 0;
        }
      } catch (e) {
        safeDebugPrint('Error sorting orders: $e');
        return 0;
      }
    });
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = _searchController.text.toLowerCase();
      _filterOrders(searchQuery);
    });
  }

  void _filterOrders(String query) {
    _filteredOrders.clear();
    _filteredOrders.addAll(_allOrders.where((order) {
      final matchesQuery = [
        (order['poNumber'] ?? '').toString().toLowerCase(),
        (order['supplierName'] ?? '').toString().toLowerCase(),
        (order['companyName'] ?? '').toString().toLowerCase(),
        (order['status'] ?? '').toString().toLowerCase(),
      ].any((field) => field.contains(query.toLowerCase()));

      final matchesCompany = _selectedCompanyId == null ||
          order['companyId'] == _selectedCompanyId;

      return matchesQuery && matchesCompany;
    }));
  }

  void _showCompanySelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: Text('show_all'.tr()),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedCompanyId = null;
                  _filterOrders(searchQuery);
                });
              },
            ),
            ..._userCompanies.map((company) => ListTile(
                  leading: const Icon(Icons.business),
                  title: Text(company['name']),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedCompanyId = company['id'];
                      _filterOrders(searchQuery);
                    });
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('sort_by_date_desc'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentSortOption = 'dateDesc';
                    _sortOrders();
                    _filterOrders(searchQuery);
                  });
                },
              ),
              ListTile(
                title: Text('sort_by_date_asc'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentSortOption = 'dateAsc';
                    _sortOrders();
                    _filterOrders(searchQuery);
                  });
                },
              ),
              ListTile(
                title: Text('sort_by_amount_desc'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentSortOption = 'amountDesc';
                    _sortOrders();
                    _filterOrders(searchQuery);
                  });
                },
              ),
              ListTile(
                title: Text('sort_by_amount_asc'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentSortOption = 'amountAsc';
                    _sortOrders();
                    _filterOrders(searchQuery);
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _editOrder(Map<String, dynamic> order) async {
    safeDebugPrint('✏️ Editing order: ${order['poNumber']}');

    final result = await context.push(
      '/purchase/${order['id']}',
      extra: order,
    );

    safeDebugPrint('🔍 Result from edit page: $result');

    if (result == true && mounted) {
      safeDebugPrint('🔄 Order was updated, refreshing list...');
      setState(() => isLoading = true);
      await _loadAllOrders();
      _filterOrders(searchQuery);
      setState(() => isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('order_updated_successfully'.tr()),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      safeDebugPrint('ℹ️ Order was not updated or result is false');
    }
  }

  Future<void> _exportOrder(Map<String, dynamic> order) async {
    setState(() => _isSearching = true);
    try {
      final companyData = await FirebaseFirestore.instance
          .collection('companies')
          .doc(order['companyId'])
          .get();

      final supplierData = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(order['supplierId'])
          .get();

      final companyDataMap = companyData.data() ?? {};
      final base64Logo = companyDataMap['logoBase64'] as String?;

      final pdf = await PdfExporter.generatePurchaseOrderPdf(
        orderId: order['id'],
        orderData: order,
        supplierData: supplierData.data() ?? {},
        companyData: companyData.data() ?? {},
        itemData: {
          'items': order['items'],
        },
        base64Logo: base64Logo,
        isArabic: _isArabic,
      );

      final bytes = await pdf.save();

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..download = 'order_${order['poNumber'] ?? order['id']}.pdf'
          ..style.display = 'none';

        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getTemporaryDirectory();
        final file =
            File('${dir.path}/order_${order['poNumber'] ?? order['id']}.pdf');
        await file.writeAsBytes(bytes);
        await Printing.sharePdf(
          bytes: bytes,
          filename: 'order_${order['poNumber'] ?? order['id']}.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'export_error'.tr()}: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      safeDebugPrint('PDF Export Error: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _confirmDeleteOrder(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_delete'.tr()),
        content: Text('delete_order_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              safeDebugPrint(
                  '🧪 Trying to delete order with ID: ${order['id']}');

              _deleteOrder(order);
            },
            child:
                Text('delete'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteOrder(Map<String, dynamic> order) async {
    try {
      await FirebaseFirestore.instance
          .collection('purchase_orders')
          .doc(order['id'])
          .delete();
      safeDebugPrint('🧪 Trying to delete order with ID: ${order['id']}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('order_deleted'.tr())),
        );
        _loadAllOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('delete_error'.tr())),
        );
      }
    }
  }

  /*  Future<void> _updateOrderStatus(
    String orderId,
    String companyId,
    String newStatus,
    List<dynamic> items,
    String factoryId,
    Map<String, dynamic> order,
  ) async {
    Map<String, dynamic>? deliveryMeta;
    if (newStatus == 'completed') {
      deliveryMeta = await _showDeliveryNoteDialog();
      if (deliveryMeta == null) return;

      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(order['companyId'])
          .get();
      final supplierDoc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(order['supplierId'])
          .get();
      final companyData = companyDoc.data() ?? {};
      final supplierData = supplierDoc.data() ?? {};
      final base64Logo = companyData['logoBase64'] as String?;
if (!mounted) return;
      // ===== بناء الترجمة =====
      final translations = {
        'deliveryNoteTitle': context.tr('delivery_note_title'),
        'dataTitle': context.tr('data_title'),
        'deliveryNumberLabel': context.tr('delivery_number_label'),
        'dateLabel': context.tr('date_label'),
        'poLabel': context.tr('po_label'),
        'methodLabel': context.tr('method_label'),
        'methodValue': context.tr('method_value'),
        'purposeLabel': context.tr('purpose_label'),
        'purposeDefault': context.tr('purpose_default'),
        'partiesTitle': context.tr('parties_title'),
        'senderLabel': context.tr('sender_label'),
        'receiverLabel': context.tr('receiver_label'),
        'itemsTitle': context.tr('items_title'),
        'serialLabel': context.tr('serial_label'),
        'itemNameLabel': context.tr('item_name_label'),
        'unitLabel': context.tr('unit_label'),
        'qtyLabel': context.tr('qty_label'),
        'notesLabel': context.tr('notes_label'),
        'summaryTitle': context.tr('summary_title'),
        'totalItemsLabel': context.tr('total_items_label'),
        'totalQtyLabel': context.tr('total_qty_label'),
        'unitSuffix': context.tr('unit_suffix'),
        'notesSectionTitle': context.tr('notes_section_title'),
        'note1': context.tr('note1'),
        'note2': context.tr('note2'),
        'note3': context.tr('note3'),
        'acknowledgmentTitle': context.tr('acknowledgment_title'),
        'acknowledgmentText': context.tr('acknowledgment_text'),
        'signaturesTitle': context.tr('signatures_title'),
        'storekeeper': context.tr('storekeeper'),
        'nameLabel': context.tr('name_label'),
        'signatureLabel': context.tr('signature_label'),
        'dateLabel2': context.tr('date_label2'),
        'delegate': context.tr('delegate'),
        'vehicleLabel': context.tr('vehicle_label'),
        'receiverOfficial': context.tr('receiver_official'),
        'stampLabel': context.tr('stamp_label'),
        'footerText': context.tr('footer_text'),
        'logoPlaceholder': context.tr('logo_placeholder'),
      };

      await DeliveryNotePdf.generateAndShare(
        order: order,
        companyData: companyData,
        supplierData: supplierData,
        deliveryMeta: deliveryMeta,
        base64Logo: base64Logo,
        isArabic: _isArabic,
        translations: translations,
      );
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final orderRef =
          FirebaseFirestore.instance.collection('purchase_orders').doc(orderId);
      await orderRef.update({
        'status': newStatus,
        'isDelivered': newStatus == 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (newStatus == 'completed') {
        await _firestoreService.processStockDelivery(
          companyId: companyId,
          factoryId: factoryId,
          orderId: orderId,
          userId: user.uid,
          items: items,
        );
      }

      await _refreshAfterUpdate();
    } catch (e) {
      safeDebugPrint('Error updating status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('update_error'.tr())),
        );
      }
    }
  }
 */

/*   Future<void> _updateOrderStatus(
    String orderId,
    String companyId,
    String newStatus,
    List<dynamic> items,
    String factoryId,
    Map<String, dynamic> order,
  ) async {
    // ════════════════════════════════════════════
    // 0. التحقق من وجود مستلم (مصنع أو مورد)
    // ════════════════════════════════════════════
    if (newStatus == 'completed') {
      final hasFactory =
          (order['factoryId'] != null && order['factoryId'].isNotEmpty);
      final hasSupplier =
          (order['supplierId'] != null && order['supplierId'].isNotEmpty);

      if (!hasFactory && !hasSupplier) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('no_receiver_defined'.tr()),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final deliveryMeta = await _showDeliveryNoteDialog();
      if (deliveryMeta == null) return;

      // جلب بيانات الشركة (المرسل)
      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(order['companyId'])
          .get();
      final companyData = companyDoc.data() ?? {};
      final base64Logo = companyData['logoBase64'] as String?;

      // ════════════════════════════════════════════
      // 1. تحديد المستلم (المصنع أولاً)
      // ════════════════════════════════════════════
      Map<String, dynamic> receiverData = {};

      if (hasFactory) {
        // ── المصنع هو المستلم الأساسي ──
        try {
          final factoryDoc = await FirebaseFirestore.instance
              .collection('factories')
              .doc(order['factoryId'])
              .get();
          if (factoryDoc.exists) {
            receiverData = factoryDoc.data() ?? {};
          } else {
            // المصنع غير موجود في Firestore – استخدم اسمًا افتراضيًا
            receiverData = {
              'nameAr': '                 ',
              'nameEn': '                 ',
            };
          }
        } catch (e) {
          // خطأ في الصلاحيات أو الشبكة – استخدم اسمًا افتراضيًا
          safeDebugPrint('⚠️ Could not fetch factory, using default: $e');
          receiverData = {
            'nameAr': '                 ',
            'nameEn': '                 ',
          };
        }
      } else if (hasSupplier) {
        // ── في حال عدم وجود مصنع، استخدم المورد ──
        try {
          final supplierDoc = await FirebaseFirestore.instance
              .collection('vendors')
              .doc(order['supplierId'])
              .get();
          if (supplierDoc.exists) {
            receiverData = supplierDoc.data() ?? {};
          } else {
            receiverData = {
              'nameAr': 'مورد غير معروف',
              'nameEn': 'Unknown Supplier',
            };
          }
        } catch (e) {
          safeDebugPrint('⚠️ Could not fetch supplier: $e');
          receiverData = {
            'nameAr': 'مورد غير معروف',
            'nameEn': 'Unknown Supplier',
          };
        }
      }

      // ── تأكد من وجود بيانات للمستلم ──
      if (receiverData.isEmpty) {
        receiverData = {
          'nameAr': 'جهة مستلمة غير محددة',
          'nameEn': 'Unknown Receiver',
        };
      }

      if (!mounted) return;

      // ════════════════════════════════════════════
      // 2. بناء الترجمة (كما هي موجودة)
      // ════════════════════════════════════════════
      final translations = {
        'deliveryNoteTitle': context.tr('delivery_note_title'),
        'deliveryNumberLabel': context.tr('delivery_number_label'),
        'dateLabel': context.tr('date_label'),
        'poLabel': context.tr('po_label'),
        'methodLabel': context.tr('method_label'),
        'methodValue': context.tr('method_value'),
        'purposeLabel': context.tr('purpose_label'),
        'purposeDefault': context.tr('purpose_default'),
        'senderLabel': context.tr('sender_label'),
        'receiverLabel': context.tr('receiver_label'),
        'serialLabel': context.tr('serial_label'),
        'itemNameLabel': context.tr('item_name_label'),
        'unitLabel': context.tr('unit_label'),
        'qtyLabel': context.tr('qty_label'),
        'notesLabel': context.tr('notes_label'),
        'notesSectionTitle': context.tr('notes_section_title'),
        'totalItemsLabel': context.tr('total_items_label'),
        'totalQtyLabel': context.tr('total_qty_label'),
        'unitSuffix': context.tr('unit_suffix'),
        'note1': context.tr('note1'),
        'note2': context.tr('note2'),
        'note3': context.tr('note3'),
        'acknowledgmentTitle': context.tr('acknowledgment_title'),
        'acknowledgmentText': context.tr('acknowledgment_text'),
        'storekeeper': context.tr('storekeeper'),
        'nameLabel': context.tr('name_label'),
        'signatureLabel': context.tr('signature_label'),
        'dateLabel2': context.tr('date_label2'),
        'delegate': context.tr('delegate'),
        'vehicleLabel': context.tr('vehicle_label'),
        'receiverOfficial': context.tr('receiver_official'),
        'stampLabel': context.tr('stamp_label'),
        'footerText': context.tr('footer_text'),
        'logoPlaceholder': context.tr('logo_placeholder'),
      };

      // ════════════════════════════════════════════
      // 3. توليد ومشاركة PDF مع بيانات المستلم الصحيحة
      // ════════════════════════════════════════════
      await DeliveryNotePdf.generateAndShare(
        order: order,
        companyData: companyData,
        receiverData:
            receiverData, // ✅ الآن يحمل اسم المصنع (أو المورد في حال عدم وجود مصنع)
        deliveryMeta: deliveryMeta,
        base64Logo: base64Logo,
        isArabic: _isArabic,
        translations: translations,
      );
    }

    // ════════════════════════════════════════════
    // 4. تحديث الحالة والمخزون (نفس الكود القديم)
    // ════════════════════════════════════════════
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final orderRef =
          FirebaseFirestore.instance.collection('purchase_orders').doc(orderId);
      await orderRef.update({
        'status': newStatus,
        'isDelivered': newStatus == 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (newStatus == 'completed') {
        await _firestoreService.processStockDelivery(
          companyId: companyId,
          factoryId: factoryId,
          orderId: orderId,
          userId: user.uid,
          items: items,
        );
      }

      await _refreshAfterUpdate();
    } catch (e) {
      safeDebugPrint('Error updating status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('update_error'.tr())),
        );
      }
    }
  }
 */
Future<bool?> _showPrintChoiceDialog() {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('print_choice_title'.tr()),
      content: Text('print_choice_content'.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false), // false = أمر الشراء
          child: Text('print_choice_po'.tr()),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true), // true = إذن التسليم
          child: Text('print_choice_delivery'.tr()),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx), // إلغاء
          child: Text('cancel'.tr()),
        ),
      ],
    ),
  );
}

Future<void> _updateOrderStatus(
  String orderId,
  String companyId,
  String newStatus,
  List<dynamic> items,
  String factoryId,
  Map<String, dynamic> order,
) async {
  // ════════════════════════════════════════════
  // 1. إذا كان الطلب مكتملاً (تسليم)
  // ════════════════════════════════════════════
  if (newStatus == 'completed') {
    final hasFactory =
        (order['factoryId'] != null && order['factoryId'].isNotEmpty);
    final hasSupplier =
        (order['supplierId'] != null && order['supplierId'].isNotEmpty);

    if (!hasFactory && !hasSupplier) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('no_receiver_defined'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ✅ عرض حوار اختيار المستند (PO أو Delivery Note)
    final printChoice = await _showPrintChoiceDialog();
    if (printChoice == null) return; // المستخدم ألغى العملية

    if (printChoice == false) {
      // ── اختار طباعة أمر الشراء ──
      await _exportOrder(order);
      // نستمر لتحديث الحالة والمخزون (بدون توليد إذن تسليم)
    } else {
      // ── اختار طباعة إذن التسليم ──
      final deliveryMeta = await _showDeliveryNoteDialog();
      if (deliveryMeta == null) return;

      // ════════════════════════════════════════════
      // 2. استخراج بيانات الشركة (المرسل) من الطلب أولاً
      // ════════════════════════════════════════════
      Map<String, dynamic> companyData = {};

      final companyNameAr = order['companyNameAr'] as String?;
      final companyNameEn = order['companyNameEn'] as String?;
      final base64Logo = order['logoBase64'] as String?;

      if (companyNameAr != null && companyNameEn != null) {
        // ✅ بيانات الشركة موجودة محلياً
        companyData = {
          'nameAr': companyNameAr,
          'nameEn': companyNameEn,
          'logoBase64': base64Logo,
        };
      } else {
        // ❌ للطلبات القديمة (مرة واحدة)
        final companyDoc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(order['companyId'])
            .get();
        companyData = companyDoc.data() ?? {};
      }

      // ════════════════════════════════════════════
      // 3. استخراج بيانات المستلم (المصنع أو المورد) من الطلب
      // ════════════════════════════════════════════
      Map<String, dynamic> receiverData = {};

      if (hasFactory) {
        final factoryNameAr = order['factoryNameAr'] as String?;
        final factoryNameEn = order['factoryNameEn'] as String?;

        if (factoryNameAr != null && factoryNameEn != null) {
          receiverData = {
            'nameAr': factoryNameAr,
            'nameEn': factoryNameEn,
          };
        } else {
          try {
            final factoryDoc = await FirebaseFirestore.instance
                .collection('factories')
                .doc(order['factoryId'])
                .get();
            receiverData = factoryDoc.exists ? factoryDoc.data() ?? {} : {
              'nameAr': 'مصنع غير معروف',
              'nameEn': 'Unknown Factory',
            };
          } catch (e) {
            safeDebugPrint('⚠️ Could not fetch factory: $e');
            receiverData = {
              'nameAr': 'مصنع غير معروف',
              'nameEn': 'Unknown Factory',
            };
          }
        }
      } else if (hasSupplier) {
        final supplierNameAr = order['supplierNameAr'] as String? ??
            order['supplierName'] as String?;
        final supplierNameEn = order['supplierNameEn'] as String? ??
            order['supplierName'] as String?;

        if (supplierNameAr != null && supplierNameEn != null) {
          receiverData = {
            'nameAr': supplierNameAr,
            'nameEn': supplierNameEn,
          };
        } else {
          try {
            final supplierDoc = await FirebaseFirestore.instance
                .collection('vendors')
                .doc(order['supplierId'])
                .get();
            receiverData = supplierDoc.data() ?? {};
          } catch (e) {
            receiverData = {
              'nameAr': 'مورد غير معروف',
              'nameEn': 'Unknown Supplier',
            };
          }
        }
      }

      if (receiverData.isEmpty) {
        receiverData = {
          'nameAr': 'جهة مستلمة غير محددة',
          'nameEn': 'Unknown Receiver',
        };
      }

      if (!mounted) return;

      // ════════════════════════════════════════════
      // 4. بناء الترجمة
      // ════════════════════════════════════════════
      final translations = {
        'deliveryNoteTitle': context.tr('delivery_note_title'),
        'deliveryNumberLabel': context.tr('delivery_number_label'),
        'dateLabel': context.tr('date_label'),
        'poLabel': context.tr('po_label'),
        'methodLabel': context.tr('method_label'),
        'methodValue': context.tr('method_value'),
        'purposeLabel': context.tr('purpose_label'),
        'purposeDefault': context.tr('purpose_default'),
        'senderLabel': context.tr('sender_label'),
        'receiverLabel': context.tr('receiver_label'),
        'serialLabel': context.tr('serial_label'),
        'itemNameLabel': context.tr('item_name_label'),
        'unitLabel': context.tr('unit_label'),
        'qtyLabel': context.tr('qty_label'),
        'notesLabel': context.tr('notes_label'),
        'notesSectionTitle': context.tr('notes_section_title'),
        'totalItemsLabel': context.tr('total_items_label'),
        'totalQtyLabel': context.tr('total_qty_label'),
        'unitSuffix': context.tr('unit_suffix'),
        'note1': context.tr('note1'),
        'note2': context.tr('note2'),
        'note3': context.tr('note3'),
        'acknowledgmentTitle': context.tr('acknowledgment_title'),
        'acknowledgmentText': context.tr('acknowledgment_text'),
        'storekeeper': context.tr('storekeeper'),
        'nameLabel': context.tr('name_label'),
        'signatureLabel': context.tr('signature_label'),
        'dateLabel2': context.tr('date_label2'),
        'delegate': context.tr('delegate'),
        'vehicleLabel': context.tr('vehicle_label'),
        'receiverOfficial': context.tr('receiver_official'),
        'stampLabel': context.tr('stamp_label'),
        'footerText': context.tr('footer_text'),
        'logoPlaceholder': context.tr('logo_placeholder'),
      };

      // ════════════════════════════════════════════
      // 5. توليد ومشاركة PDF (إذن التسليم)
      // ════════════════════════════════════════════
      await DeliveryNotePdf.generateAndShare(
        order: order,
        companyData: companyData,
        receiverData: receiverData,
        deliveryMeta: deliveryMeta,
        base64Logo: base64Logo,
        isArabic: _isArabic,
        translations: translations,
      );
    }
  }

  // ════════════════════════════════════════════
  // 6. تحديث حالة الطلب والمخزون (يحدث دائماً)
  // ════════════════════════════════════════════
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final orderRef =
        FirebaseFirestore.instance.collection('purchase_orders').doc(orderId);
    await orderRef.update({
      'status': newStatus,
      'isDelivered': newStatus == 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (newStatus == 'completed') {
      await _firestoreService.processStockDelivery(
        companyId: companyId,
        factoryId: factoryId,
        orderId: orderId,
        userId: user.uid,
        items: items,
      );
    }

    await _refreshAfterUpdate();
  } catch (e) {
    safeDebugPrint('Error updating status: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('update_error'.tr())),
      );
    }
  }
}

/*   Future<void> _updateOrderStatus(
    String orderId,
    String companyId,
    String newStatus,
    List<dynamic> items,
    String factoryId,
    Map<String, dynamic> order,
  ) async {
    // ════════════════════════════════════════════
    // 1. إذا كان الطلب مكتملاً (تسليم) نقوم بإنشاء إذن التسليم
    // ════════════════════════════════════════════
    if (newStatus == 'completed') {
      final hasFactory =
          (order['factoryId'] != null && order['factoryId'].isNotEmpty);
      final hasSupplier =
          (order['supplierId'] != null && order['supplierId'].isNotEmpty);

      if (!hasFactory && !hasSupplier) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('no_receiver_defined'.tr()),
              backgroundColor: Colors.red),
        );
        return;
      }

      final deliveryMeta = await _showDeliveryNoteDialog();
      if (deliveryMeta == null) return;

      // ════════════════════════════════════════════
      // 2. استخراج بيانات الشركة (المرسل) من الطلب أولاً
      //    (بدون طلب Firestore إن كانت موجودة)
      // ════════════════════════════════════════════
      Map<String, dynamic> companyData = {};

      // نستخدم الحقول المخزنة مسبقاً في الطلب
      final companyNameAr = order['companyNameAr'] as String?;
      final companyNameEn = order['companyNameEn'] as String?;
      final base64Logo = order['logoBase64'] as String?;

      if (companyNameAr != null && companyNameEn != null) {
        // ✅ بيانات الشركة موجودة محلياً → نستخدمها فوراً
        companyData = {
          'nameAr': companyNameAr,
          'nameEn': companyNameEn,
          'logoBase64': base64Logo,
        };
      } else {
        // ❌ للطلبات القديمة التي ليس فيها هذه الحقول → نجلب من Firestore (مرة واحدة)
        final companyDoc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(order['companyId'])
            .get();
        companyData = companyDoc.data() ?? {};
      }

      // ════════════════════════════════════════════
      // 3. استخراج بيانات المستلم (المصنع أو المورد) من الطلب
      // ════════════════════════════════════════════
      Map<String, dynamic> receiverData = {};

      if (hasFactory) {
        // ── المستلم هو المصنع ──
        final factoryNameAr = order['factoryNameAr'] as String?;
        final factoryNameEn = order['factoryNameEn'] as String?;

        if (factoryNameAr != null && factoryNameEn != null) {
          // ✅ بيانات المصنع موجودة محلياً
          receiverData = {
            'nameAr': factoryNameAr,
            'nameEn': factoryNameEn,
          };
        } else {
          // ❌ للطلبات القديمة (نادر) → نجلب من Firestore
          try {
            final factoryDoc = await FirebaseFirestore.instance
                .collection('factories')
                .doc(order['factoryId'])
                .get();
            if (factoryDoc.exists) {
              receiverData = factoryDoc.data() ?? {};
            } else {
              receiverData = {
                'nameAr': 'مصنع غير معروف',
                'nameEn': 'Unknown Factory',
              };
            }
          } catch (e) {
            safeDebugPrint('⚠️ Could not fetch factory: $e');
            receiverData = {
              'nameAr': 'مصنع غير معروف',
              'nameEn': 'Unknown Factory',
            };
          }
        }
      } else if (hasSupplier) {
        // ── المستلم هو المورد (في حال لم يكن هناك مصنع) ──
        final supplierNameAr = order['supplierNameAr'] as String? ??
            order['supplierName'] as String?;
        final supplierNameEn = order['supplierNameEn'] as String? ??
            order['supplierName'] as String?;

        if (supplierNameAr != null && supplierNameEn != null) {
          receiverData = {
            'nameAr': supplierNameAr,
            'nameEn': supplierNameEn,
          };
        } else {
          // للطلبات القديمة أو الاحتياط
          try {
            final supplierDoc = await FirebaseFirestore.instance
                .collection('vendors')
                .doc(order['supplierId'])
                .get();
            receiverData = supplierDoc.data() ?? {};
          } catch (e) {
            receiverData = {
              'nameAr': 'مورد غير معروف',
              'nameEn': 'Unknown Supplier',
            };
          }
        }
      }

      // تأكد من وجود بيانات المستلم
      if (receiverData.isEmpty) {
        receiverData = {
          'nameAr': 'جهة مستلمة غير محددة',
          'nameEn': 'Unknown Receiver',
        };
      }

      if (!mounted) return;

      // ════════════════════════════════════════════
      // 4. بناء الترجمة (نفس الكود السابق)
      // ════════════════════════════════════════════
      final translations = {
        'deliveryNoteTitle': context.tr('delivery_note_title'),
        'deliveryNumberLabel': context.tr('delivery_number_label'),
        'dateLabel': context.tr('date_label'),
        'poLabel': context.tr('po_label'),
        'methodLabel': context.tr('method_label'),
        'methodValue': context.tr('method_value'),
        'purposeLabel': context.tr('purpose_label'),
        'purposeDefault': context.tr('purpose_default'),
        'senderLabel': context.tr('sender_label'),
        'receiverLabel': context.tr('receiver_label'),
        'serialLabel': context.tr('serial_label'),
        'itemNameLabel': context.tr('item_name_label'),
        'unitLabel': context.tr('unit_label'),
        'qtyLabel': context.tr('qty_label'),
        'notesLabel': context.tr('notes_label'),
        'notesSectionTitle': context.tr('notes_section_title'),
        'totalItemsLabel': context.tr('total_items_label'),
        'totalQtyLabel': context.tr('total_qty_label'),
        'unitSuffix': context.tr('unit_suffix'),
        'note1': context.tr('note1'),
        'note2': context.tr('note2'),
        'note3': context.tr('note3'),
        'acknowledgmentTitle': context.tr('acknowledgment_title'),
        'acknowledgmentText': context.tr('acknowledgment_text'),
        'storekeeper': context.tr('storekeeper'),
        'nameLabel': context.tr('name_label'),
        'signatureLabel': context.tr('signature_label'),
        'dateLabel2': context.tr('date_label2'),
        'delegate': context.tr('delegate'),
        'vehicleLabel': context.tr('vehicle_label'),
        'receiverOfficial': context.tr('receiver_official'),
        'stampLabel': context.tr('stamp_label'),
        'footerText': context.tr('footer_text'),
        'logoPlaceholder': context.tr('logo_placeholder'),
      };

      // ════════════════════════════════════════════
      // 5. توليد ومشاركة PDF (سريع جداً الآن)
      // ════════════════════════════════════════════
      await DeliveryNotePdf.generateAndShare(
        order: order,
        companyData: companyData,
        receiverData: receiverData,
        deliveryMeta: deliveryMeta,
        base64Logo: base64Logo,
        isArabic: _isArabic,
        translations: translations,
      );
    }

    // ════════════════════════════════════════════
    // 6. تحديث حالة الطلب والمخزون (نفس الكود القديم)
    // ════════════════════════════════════════════
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final orderRef =
          FirebaseFirestore.instance.collection('purchase_orders').doc(orderId);
      await orderRef.update({
        'status': newStatus,
        'isDelivered': newStatus == 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (newStatus == 'completed') {
        await _firestoreService.processStockDelivery(
          companyId: companyId,
          factoryId: factoryId,
          orderId: orderId,
          userId: user.uid,
          items: items,
        );
      }

      await _refreshAfterUpdate();
    } catch (e) {
      safeDebugPrint('Error updating status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('update_error'.tr())),
        );
      }
    }
  }
 */
  Widget _buildOrderCard(Map<String, dynamic> order) {
    final netPayable = NumberFormat.currency(
      symbol: '',
      decimalDigits: 2,
    ).format(order['netPayable'] ?? 0);

    DateTime orderDate;
    try {
      if (order['orderDate'] is Timestamp) {
        orderDate = (order['orderDate'] as Timestamp).toDate();
      } else if (order['orderDate'] is int) {
        orderDate = DateTime.fromMillisecondsSinceEpoch(order['orderDate']);
      } else {
        orderDate = DateTime.now();
      }
    } catch (e) {
      orderDate = DateTime.now();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getStatusColor(order['status']).withAlpha(76),
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          '/purchase/${order['id']}',
          extra: order,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order['poNumber'] ?? '${order['id']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order['status']),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (order['status'] ?? 'pending').toString().toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (_userCompaniesCount > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.business, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order['companyName'] ?? '',
                          style: TextStyle(color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order['supplierName'] ?? '',
                        style: TextStyle(color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16, thickness: 1),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateFormat('yyyy-MM-dd').format(orderDate),
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '$netPayable ${'currency'.tr()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              if (order['status'] == 'pending')
                SwitchListTile(
                  title: Text('delivered'.tr()),
                  value: order['status'] == 'completed',
                  onChanged: (val) async {
                    if (val) {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('confirm_delivery'.tr()),
                          content: Text('confirm_mark_delivered'.tr()),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('cancel'.tr()),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text('confirm'.tr()),
                            ),
                          ],
                        ),
                      );

                      if (confirmed != true) return;
                    }

                    await _updateOrderStatus(
                      order['id'],
                      order['companyId'],
                      val ? 'completed' : 'pending',
                      order['items'],
                      order['factoryId'],
                      order,
                    );

                    if (mounted) {
                      await _loadAllOrders();
                    }
                  },
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (order['status'] == 'pending')
                    IconButton(
                      icon:
                          const Icon(Icons.edit, size: 20, color: Colors.blue),
                      tooltip: 'edit'.tr(),
                      onPressed: () => _editOrder(order),
                    ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf,
                        size: 20, color: Colors.green),
                    tooltip: 'export_pdf'.tr(),
                    onPressed: () => _exportOrder(order),
                  ),
                  if (order['status'] == 'pending')
                    IconButton(
                      icon:
                          const Icon(Icons.delete, size: 20, color: Colors.red),
                      tooltip: 'delete'.tr(),
                      onPressed: () => _confirmDeleteOrder(order),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return AppScaffold(
        title: 'purchase_orders'.tr(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    safeDebugPrint('User companies count: $_userCompaniesCount');

    return Directionality(
      textDirection: Directionality.of(context),
      child: AppScaffold(
        title: 'purchase_orders'.tr(),
        actions: [
          HoverAddButton(
            onPressed: () async {
              final result = await context.push('/add-purchase-order');
              if (result == true && mounted) await _loadAllOrders();
              _filterOrders(searchQuery);
            },
            tooltip: 'add_purchase_order'.tr(),
            iconColor: Colors.white,
            iconSize: 28,
          ),
        ],
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'search'.tr(),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: 'search_hint'.tr(),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_userCompaniesCount > 1)
                    IconButton(
                      icon: const Icon(Icons.business),
                      tooltip: 'multiple_companies'.tr(),
                      onPressed: _showCompanySelector,
                    ),
                  IconButton(
                    icon: const Icon(Icons.sort),
                    onPressed: _showSortOptions,
                    tooltip: 'sort_options'.tr(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredOrders.isEmpty
                      ? Center(child: Text('no_match_search'.tr()))
                      : RefreshIndicator(
                          onRefresh: _loadAllOrders,
                          child: ListView.builder(
                            itemCount: _filteredOrders.length,
                            itemBuilder: (ctx, index) {
                              final order = _filteredOrders[index];
                              return _buildOrderCard(order);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
 */

/* 
// purchase_orders_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:puresip_purchasing/services/firestore_service.dart';
import 'package:puresip_purchasing/utils/pdf_exporter.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:puresip_purchasing/widgets/hover_add_button.dart';
import 'package:universal_html/html.dart' as html;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/utils/delivery_note_pdf.dart';

class PurchaseOrdersPage extends StatefulWidget {
  const PurchaseOrdersPage({super.key});

  @override
  State<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> {
  String searchQuery = '';
  bool isLoading = true;
  String? userName;
  final List<Map<String, dynamic>> _allOrders = [];
  final List<Map<String, dynamic>> _filteredOrders = [];
  bool _isSearching = false;
  int _userCompaniesCount = 1;
  String _currentSortOption = 'dateDesc';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _userCompanies = [];
  String? _selectedCompanyId;
  final FirestoreService _firestoreService = FirestoreService();

  late bool _isArabic;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isDataLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isDataLoaded) {
      _isDataLoaded = true;
      setState(() {
        _isArabic = context.locale.languageCode == 'ar';
      });
      safeDebugPrint("Current language is Arabic? $_isArabic");
      _initData();
    }
  }

  Future<void> _initData() async {
    await loadUserInfo();
    await _loadUserCompaniesCount();
    await _loadAllOrders();
    await _loadUserCompanies();
  }

  Future<void> loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final email = user.email ?? '';
      final name = user.displayName ?? '';
      setState(() {
        userName = name.isNotEmpty ? name : email.split('@')[0];
      });
    }
  }

  // ── كاش في الذاكرة لأسماء الشركات والموردين ──
  final Map<String, String> _companyNameCache = {};
  final Map<String, String> _supplierNameCache = {};

  Future<void> _loadUserCompaniesCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final cachedCount = prefs.getInt('userCompaniesCount');
    if (cachedCount != null) {
      setState(() => _userCompaniesCount = cachedCount);
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = userDoc.data() ?? {};
    final companyIds = List<String>.from(data['companyIds'] ?? []);

    await prefs.setInt('userCompaniesCount', companyIds.length);
    setState(() => _userCompaniesCount = companyIds.length);

    await _loadUserCompaniesFromIds(companyIds);
  }

  Future<void> _loadUserCompanies() async {
    if (_userCompanies.isNotEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final companyIds = List<String>.from(userDoc.data()?['companyIds'] ?? []);
    await _loadUserCompaniesFromIds(companyIds);
  }

  Future<void> _loadUserCompaniesFromIds(List<String> companyIds) async {
    if (companyIds.isEmpty) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('companies')
        .where(FieldPath.documentId, whereIn: companyIds)
        .get();

    _userCompanies = snapshot.docs.map((doc) {
      final name = _isArabic
          ? doc.data()['nameAr'] ?? doc.id
          : doc.data()['nameEn'] ?? doc.id;
      _companyNameCache[doc.id] = name;
      return {'id': doc.id, 'name': name};
    }).toList();
  }

  Future<void> _loadAllOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (mounted) setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cachedOrders');
      final cacheTime = prefs.getInt('cachedOrdersTime') ?? 0;
      final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTime;

      if (cachedJson != null && cacheAge < 300000) {
        final List decoded = json.decode(cachedJson);
        _allOrders
          ..clear()
          ..addAll(decoded.cast<Map<String, dynamic>>());
        _filterOrders(searchQuery);
        if (mounted) setState(() => isLoading = false);
        _fetchOrdersFromFirestore(user.uid, prefs, background: true);
        return;
      }

      await _fetchOrdersFromFirestore(user.uid, prefs, background: false);
    } catch (e) {
      safeDebugPrint('Error loading orders: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchOrdersFromFirestore(String userId, SharedPreferences prefs,
      {required bool background}) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('purchase_orders')
          .where('userId', isEqualTo: userId)
          .orderBy('orderDate', descending: true)
          .get();

      final companyIds = <String>{};
      final supplierIds = <String>{};
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        if (data['companyId'] != null) companyIds.add(data['companyId']);
        if (data['supplierId'] != null) supplierIds.add(data['supplierId']);
      }

      final missingCompanies =
          companyIds.where((id) => !_companyNameCache.containsKey(id)).toList();
      final missingSuppliers = supplierIds
          .where((id) => !_supplierNameCache.containsKey(id))
          .toList();

      await Future.wait([
        if (missingCompanies.isNotEmpty)
          FirebaseFirestore.instance
              .collection('companies')
              .where(FieldPath.documentId, whereIn: missingCompanies)
              .get()
              .then((snap) {
            for (final doc in snap.docs) {
              _companyNameCache[doc.id] = _isArabic
                  ? doc.data()['nameAr'] ?? doc.id
                  : doc.data()['nameEn'] ?? doc.id;
            }
          }),
        if (missingSuppliers.isNotEmpty)
          FirebaseFirestore.instance
              .collection('vendors')
              .where(FieldPath.documentId, whereIn: missingSuppliers)
              .get()
              .then((snap) {
            for (final doc in snap.docs) {
              _supplierNameCache[doc.id] = _isArabic
                  ? doc.data()['nameAr'] ?? doc.id
                  : doc.data()['nameEn'] ?? doc.id;
            }
          }),
      ]);

      final orders = querySnapshot.docs.map((doc) {
        final data = doc.data();

        final serializable = data.map((key, value) {
          if (value is Timestamp) {
            return MapEntry(key, value.toDate().toIso8601String());
          }
          return MapEntry(key, value);
        });

        return {
          ...serializable,
          'id': doc.id,
          'companyName': _companyNameCache[data['companyId']] ?? '',
          'supplierName': _supplierNameCache[data['supplierId']] ?? '',
        };
      }).toList();

      try {
        await prefs.setString('cachedOrders', json.encode(orders));
        await prefs.setInt(
            'cachedOrdersTime', DateTime.now().millisecondsSinceEpoch);
      } catch (e) {
        safeDebugPrint('Cache save error: $e');
      }

      if (mounted) {
        _allOrders
          ..clear()
          ..addAll(orders);
        _filterOrders(searchQuery);
        setState(() => isLoading = false);
      }
    } catch (e) {
      safeDebugPrint('Firestore fetch error: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ─── حوار إدخال بيانات إذن التسليم ────────────────────────────
  Future<Map<String, dynamic>?> _showDeliveryNoteDialog() async {
    final controller = TextEditingController(
      text: 'DN-${DateFormat('yyyyMMdd').format(DateTime.now())}-01',
    );
    final dateController = TextEditingController(
      text: DateFormat('dd-MM-yyyy').format(DateTime.now()),
    );
    final notesController = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('delivery_note_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: controller,
                decoration: InputDecoration(labelText: 'delivery_number'.tr())),
            TextField(
                controller: dateController,
                decoration: InputDecoration(labelText: 'delivery_date'.tr())),
            TextField(
                controller: notesController,
                decoration: InputDecoration(labelText: 'notes'.tr()),
                maxLines: 2),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text('cancel'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(ctx, {
              'deliveryNumber': controller.text,
              'deliveryDate': dateController.text,
              'notes': notesController.text,
            }),
            child: Text('print'.tr()),
          ),
        ],
      ),
    );
  }

  // ─── حوار اختيار الطباعة عند تغيير الحالة ──────────────────
  Future<bool?> _showPrintChoiceDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('print_choice_title'.tr()),
        content: Text('print_choice_content'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), // false = أمر الشراء
            child: Text('print_choice_po'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), // true = إذن التسليم
            child: Text('print_choice_delivery'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx), // إلغاء
            child: Text('cancel'.tr()),
          ),
        ],
      ),
    );
  }

  // ─── حوار اختيار الطباعة عند النقر على زر PDF لطلب مكتمل ──
  Future<bool?> _showPrintChoiceDialogForExport() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('print_choice_title'.tr()),
        content: Text('print_choice_content_export'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), // false = أمر الشراء
            child: Text('print_choice_po'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), // true = إذن التسليم
            child: Text('print_choice_delivery'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx), // إلغاء
            child: Text('cancel'.tr()),
          ),
        ],
      ),
    );
  }

  // ─── دالة مشاركة PDF (للويب والهواتف) ──────────────────────
  Future<void> _sharePdf(Uint8List bytes, String fileName) async {
    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..download = fileName
        ..style.display = 'none';
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    }
  }

  // ─── طباعة أمر الشراء (PO) ──────────────────────────────────
  Future<void> _exportPurchaseOrder(Map<String, dynamic> order) async {
    // إذا كانت بيانات الشركة والمورد موجودة في order، استخدمها، وإلا اجلب من Firestore
    Map<String, dynamic> companyData;
    Map<String, dynamic> supplierData;
    String? base64Logo;

    final hasCompanyData = order['companyNameAr'] != null && order['companyNameEn'] != null;
    final hasSupplierData = order['supplierNameAr'] != null && order['supplierNameEn'] != null;

    if (hasCompanyData && hasSupplierData) {
      // استخدام البيانات المخزنة مسبقاً
      companyData = {
        'nameAr': order['companyNameAr'],
        'nameEn': order['companyNameEn'],
        'logoBase64': order['logoBase64'],
      };
      supplierData = {
        'nameAr': order['supplierNameAr'],
        'nameEn': order['supplierNameEn'],
      };
      base64Logo = order['logoBase64'];
    } else {
      // الطلبات القديمة – نلجأ لجلب من Firestore
      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(order['companyId'])
          .get();
      final supplierDoc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(order['supplierId'])
          .get();
      companyData = companyDoc.data() ?? {};
      supplierData = supplierDoc.data() ?? {};
      base64Logo = companyData['logoBase64'] as String?;
    }

    final pdf = await PdfExporter.generatePurchaseOrderPdf(
      orderId: order['id'],
      orderData: order,
      supplierData: supplierData,
      companyData: companyData,
      itemData: {'items': order['items'] ?? []},
      base64Logo: base64Logo,
      isArabic: _isArabic,
    );

    final bytes = await pdf.save();
    await _sharePdf(bytes, 'order_${order['poNumber'] ?? order['id']}.pdf');
  }

  // ─── طباعة إذن التسليم (Delivery Note) من بيانات الطلب ──
  Future<void> _printDeliveryNoteFromOrder(Map<String, dynamic> order) async {
    try {
      // 1. بيانات الشركة (المرسل)
      final companyData = {
        'nameAr': order['companyNameAr'] ?? order['companyName'] ?? '',
        'nameEn': order['companyNameEn'] ?? order['companyName'] ?? '',
        'logoBase64': order['logoBase64'],
      };

      // 2. بيانات المستلم (المصنع أو المورد)
      final hasFactory = order['factoryId'] != null && order['factoryId'].isNotEmpty;
      final hasSupplier = order['supplierId'] != null && order['supplierId'].isNotEmpty;

      Map<String, dynamic> receiverData = {};
      if (hasFactory) {
        receiverData = {
          'nameAr': order['factoryNameAr'] ?? 'مصنع غير معروف',
          'nameEn': order['factoryNameEn'] ?? 'Unknown Factory',
        };
      } else if (hasSupplier) {
        receiverData = {
          'nameAr': order['supplierNameAr'] ?? order['supplierName'] ?? 'مورد غير معروف',
          'nameEn': order['supplierNameEn'] ?? order['supplierName'] ?? 'Unknown Supplier',
        };
      } else {
        receiverData = {
          'nameAr': 'جهة مستلمة غير محددة',
          'nameEn': 'Unknown Receiver',
        };
      }

      // 3. بيانات الإذن (توليد تلقائي)
      final deliveryMeta = {
        'deliveryNumber': 'DN-${DateFormat('yyyyMMdd').format(DateTime.now())}-${order['poNumber']?.substring(order['poNumber'].length - 3) ?? '01'}',
        'deliveryDate': DateFormat('dd-MM-yyyy').format(DateTime.now()),
        'notes': '',
      };

      // 4. الترجمة
      final translations = {
        'deliveryNoteTitle': tr('delivery_note_title'),
        'deliveryNumberLabel': tr('delivery_number_label'),
        'dateLabel': tr('date_label'),
        'poLabel': tr('po_label'),
        'methodLabel': tr('method_label'),
        'methodValue': tr('method_value'),
        'purposeLabel': tr('purpose_label'),
        'purposeDefault': tr('purpose_default'),
        'senderLabel': tr('sender_label'),
        'receiverLabel': tr('receiver_label'),
        'serialLabel': tr('serial_label'),
        'itemNameLabel': tr('item_name_label'),
        'unitLabel': tr('unit_label'),
        'qtyLabel': tr('qty_label'),
        'notesLabel': tr('notes_label'),
        'notesSectionTitle': tr('notes_section_title'),
        'totalItemsLabel': tr('total_items_label'),
        'totalQtyLabel': tr('total_qty_label'),
        'unitSuffix': tr('unit_suffix'),
        'note1': tr('note1'),
        'note2': tr('note2'),
        'note3': tr('note3'),
        'acknowledgmentTitle': tr('acknowledgment_title'),
        'acknowledgmentText': tr('acknowledgment_text'),
        'storekeeper': tr('storekeeper'),
        'nameLabel': tr('name_label'),
        'signatureLabel': tr('signature_label'),
        'dateLabel2': tr('date_label2'),
        'delegate': tr('delegate'),
        'vehicleLabel': tr('vehicle_label'),
        'receiverOfficial': tr('receiver_official'),
        'stampLabel': tr('stamp_label'),
        'footerText': tr('footer_text'),
      };

      // 5. توليد ومشاركة PDF
      await DeliveryNotePdf.generateAndShare(
        order: order,
        companyData: companyData,
        receiverData: receiverData,
        deliveryMeta: deliveryMeta,
        base64Logo: order['logoBase64'],
        isArabic: _isArabic,
        translations: translations,
      );
    } catch (e) {
      safeDebugPrint('Error printing delivery note: $e');
      rethrow;
    }
  }

  // ─── وظيفة التصدير الرئيسية (التي يستدعيها زر PDF) ──────────
  Future<void> _exportOrder(Map<String, dynamic> order) async {
    setState(() => _isSearching = true);
    try {
      final status = order['status'] ?? 'pending';

      // إذا كانت الحالة "completed"، اعرض حوار اختيار المستند
      if (status == 'completed') {
        final choice = await _showPrintChoiceDialogForExport();
        if (choice == null) return; // إلغاء

        if (choice == false) {
          // طباعة أمر الشراء
          await _exportPurchaseOrder(order);
        } else {
          // طباعة إذن التسليم
          await _printDeliveryNoteFromOrder(order);
        }
      } else {
        // pending: طباعة أمر الشراء مباشرة
        await _exportPurchaseOrder(order);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'export_error'.tr()}: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      safeDebugPrint('PDF Export Error: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ─── دوال أخرى (تحديث، حذف، إلخ) ──────────────────────────

  Future<void> _refreshAfterUpdate() async {
    if (mounted) {
      setState(() => isLoading = true);
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadAllOrders();
    }
  }

  void _sortOrders() {
    _allOrders.sort((a, b) {
      try {
        Timestamp aDate;
        Timestamp bDate;

        if (a['orderDate'] is Timestamp) {
          aDate = a['orderDate'] as Timestamp;
        } else if (a['orderDate'] is int) {
          aDate = Timestamp.fromMillisecondsSinceEpoch(a['orderDate']);
        } else {
          aDate = Timestamp.now();
        }

        if (b['orderDate'] is Timestamp) {
          bDate = b['orderDate'] as Timestamp;
        } else if (b['orderDate'] is int) {
          bDate = Timestamp.fromMillisecondsSinceEpoch(b['orderDate']);
        } else {
          bDate = Timestamp.now();
        }

        switch (_currentSortOption) {
          case 'dateDesc':
            return bDate.compareTo(aDate);
          case 'dateAsc':
            return aDate.compareTo(bDate);
          case 'amountDesc':
            return (b['totalAmountAfterTax'] as num)
                .compareTo(a['totalAmountAfterTax'] as num);
          case 'amountAsc':
            return (a['totalAmountAfterTax'] as num)
                .compareTo(b['totalAmountAfterTax'] as num);
          default:
            return 0;
        }
      } catch (e) {
        safeDebugPrint('Error sorting orders: $e');
        return 0;
      }
    });
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = _searchController.text.toLowerCase();
      _filterOrders(searchQuery);
    });
  }

  void _filterOrders(String query) {
    _filteredOrders.clear();
    _filteredOrders.addAll(_allOrders.where((order) {
      final matchesQuery = [
        (order['poNumber'] ?? '').toString().toLowerCase(),
        (order['supplierName'] ?? '').toString().toLowerCase(),
        (order['companyName'] ?? '').toString().toLowerCase(),
        (order['status'] ?? '').toString().toLowerCase(),
      ].any((field) => field.contains(query.toLowerCase()));

      final matchesCompany = _selectedCompanyId == null ||
          order['companyId'] == _selectedCompanyId;

      return matchesQuery && matchesCompany;
    }));
  }

  void _showCompanySelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: Text('show_all'.tr()),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedCompanyId = null;
                  _filterOrders(searchQuery);
                });
              },
            ),
            ..._userCompanies.map((company) => ListTile(
                  leading: const Icon(Icons.business),
                  title: Text(company['name']),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedCompanyId = company['id'];
                      _filterOrders(searchQuery);
                    });
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('sort_by_date_desc'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentSortOption = 'dateDesc';
                    _sortOrders();
                    _filterOrders(searchQuery);
                  });
                },
              ),
              ListTile(
                title: Text('sort_by_date_asc'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentSortOption = 'dateAsc';
                    _sortOrders();
                    _filterOrders(searchQuery);
                  });
                },
              ),
              ListTile(
                title: Text('sort_by_amount_desc'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentSortOption = 'amountDesc';
                    _sortOrders();
                    _filterOrders(searchQuery);
                  });
                },
              ),
              ListTile(
                title: Text('sort_by_amount_asc'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentSortOption = 'amountAsc';
                    _sortOrders();
                    _filterOrders(searchQuery);
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _editOrder(Map<String, dynamic> order) async {
    safeDebugPrint('✏️ Editing order: ${order['poNumber']}');

    final result = await context.push(
      '/purchase/${order['id']}',
      extra: order,
    );

    safeDebugPrint('🔍 Result from edit page: $result');

    if (result == true && mounted) {
      safeDebugPrint('🔄 Order was updated, refreshing list...');
      setState(() => isLoading = true);
      await _loadAllOrders();
      _filterOrders(searchQuery);
      setState(() => isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('order_updated_successfully'.tr()),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      safeDebugPrint('ℹ️ Order was not updated or result is false');
    }
  }

  void _confirmDeleteOrder(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_delete'.tr()),
        content: Text('delete_order_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              safeDebugPrint(
                  '🧪 Trying to delete order with ID: ${order['id']}');

              _deleteOrder(order);
            },
            child:
                Text('delete'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteOrder(Map<String, dynamic> order) async {
    try {
      await FirebaseFirestore.instance
          .collection('purchase_orders')
          .doc(order['id'])
          .delete();
      safeDebugPrint('🧪 Trying to delete order with ID: ${order['id']}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('order_deleted'.tr())),
        );
        _loadAllOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('delete_error'.tr())),
        );
      }
    }
  }

  // ─── تحديث حالة الطلب (مع حوار الاختيار) ────────────────────
  Future<void> _updateOrderStatus(
    String orderId,
    String companyId,
    String newStatus,
    List<dynamic> items,
    String factoryId,
    Map<String, dynamic> order,
  ) async {
    // ════════════════════════════════════════════
    // 1. إذا كان الطلب مكتملاً (تسليم)
    // ════════════════════════════════════════════
    if (newStatus == 'completed') {
      final hasFactory =
          (order['factoryId'] != null && order['factoryId'].isNotEmpty);
      final hasSupplier =
          (order['supplierId'] != null && order['supplierId'].isNotEmpty);

      if (!hasFactory && !hasSupplier) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('no_receiver_defined'.tr()),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // ✅ عرض حوار اختيار المستند (PO أو Delivery Note)
      final printChoice = await _showPrintChoiceDialog();
      if (printChoice == null) return; // المستخدم ألغى العملية

      if (printChoice == false) {
        // ── اختار طباعة أمر الشراء ──
        await _exportPurchaseOrder(order);
        // نستمر لتحديث الحالة والمخزون (بدون توليد إذن تسليم)
      } else {
        // ── اختار طباعة إذن التسليم ──
        final deliveryMeta = await _showDeliveryNoteDialog();
        if (deliveryMeta == null) return;

        // ════════════════════════════════════════════
        // 2. استخراج بيانات الشركة (المرسل) من الطلب أولاً
        // ════════════════════════════════════════════
        Map<String, dynamic> companyData = {};

        final companyNameAr = order['companyNameAr'] as String?;
        final companyNameEn = order['companyNameEn'] as String?;
        final base64Logo = order['logoBase64'] as String?;

        if (companyNameAr != null && companyNameEn != null) {
          // ✅ بيانات الشركة موجودة محلياً
          companyData = {
            'nameAr': companyNameAr,
            'nameEn': companyNameEn,
            'logoBase64': base64Logo,
          };
        } else {
          // ❌ للطلبات القديمة (مرة واحدة)
          final companyDoc = await FirebaseFirestore.instance
              .collection('companies')
              .doc(order['companyId'])
              .get();
          companyData = companyDoc.data() ?? {};
        }

        // ════════════════════════════════════════════
        // 3. استخراج بيانات المستلم (المصنع أو المورد) من الطلب
        // ════════════════════════════════════════════
        Map<String, dynamic> receiverData = {};

        if (hasFactory) {
          final factoryNameAr = order['factoryNameAr'] as String?;
          final factoryNameEn = order['factoryNameEn'] as String?;

          if (factoryNameAr != null && factoryNameEn != null) {
            receiverData = {
              'nameAr': factoryNameAr,
              'nameEn': factoryNameEn,
            };
          } else {
            try {
              final factoryDoc = await FirebaseFirestore.instance
                  .collection('factories')
                  .doc(order['factoryId'])
                  .get();
              receiverData = factoryDoc.exists ? factoryDoc.data() ?? {} : {
                'nameAr': 'مصنع غير معروف',
                'nameEn': 'Unknown Factory',
              };
            } catch (e) {
              safeDebugPrint('⚠️ Could not fetch factory: $e');
              receiverData = {
                'nameAr': 'مصنع غير معروف',
                'nameEn': 'Unknown Factory',
              };
            }
          }
        } else if (hasSupplier) {
          final supplierNameAr = order['supplierNameAr'] as String? ??
              order['supplierName'] as String?;
          final supplierNameEn = order['supplierNameEn'] as String? ??
              order['supplierName'] as String?;

          if (supplierNameAr != null && supplierNameEn != null) {
            receiverData = {
              'nameAr': supplierNameAr,
              'nameEn': supplierNameEn,
            };
          } else {
            try {
              final supplierDoc = await FirebaseFirestore.instance
                  .collection('vendors')
                  .doc(order['supplierId'])
                  .get();
              receiverData = supplierDoc.data() ?? {};
            } catch (e) {
              receiverData = {
                'nameAr': 'مورد غير معروف',
                'nameEn': 'Unknown Supplier',
              };
            }
          }
        }

        if (receiverData.isEmpty) {
          receiverData = {
            'nameAr': 'جهة مستلمة غير محددة',
            'nameEn': 'Unknown Receiver',
          };
        }

        if (!mounted) return;

        // ════════════════════════════════════════════
        // 4. بناء الترجمة
        // ════════════════════════════════════════════
        final translations = {
          'deliveryNoteTitle': tr('delivery_note_title'),
          'deliveryNumberLabel': tr('delivery_number_label'),
          'dateLabel': tr('date_label'),
          'poLabel': tr('po_label'),
          'methodLabel': tr('method_label'),
          'methodValue': tr('method_value'),
          'purposeLabel': tr('purpose_label'),
          'purposeDefault': tr('purpose_default'),
          'senderLabel': tr('sender_label'),
          'receiverLabel': tr('receiver_label'),
          'serialLabel': tr('serial_label'),
          'itemNameLabel': tr('item_name_label'),
          'unitLabel': tr('unit_label'),
          'qtyLabel': tr('qty_label'),
          'notesLabel': tr('notes_label'),
          'notesSectionTitle': tr('notes_section_title'),
          'totalItemsLabel': tr('total_items_label'),
          'totalQtyLabel': tr('total_qty_label'),
          'unitSuffix': tr('unit_suffix'),
          'note1': tr('note1'),
          'note2': tr('note2'),
          'note3': tr('note3'),
          'acknowledgmentTitle': tr('acknowledgment_title'),
          'acknowledgmentText': tr('acknowledgment_text'),
          'storekeeper': tr('storekeeper'),
          'nameLabel': tr('name_label'),
          'signatureLabel': tr('signature_label'),
          'dateLabel2': tr('date_label2'),
          'delegate': tr('delegate'),
          'vehicleLabel': tr('vehicle_label'),
          'receiverOfficial': tr('receiver_official'),
          'stampLabel': tr('stamp_label'),
          'footerText': tr('footer_text'),
          'logoPlaceholder': tr('logo_placeholder'),
        };

        // ════════════════════════════════════════════
        // 5. توليد ومشاركة PDF (إذن التسليم)
        // ════════════════════════════════════════════
        await DeliveryNotePdf.generateAndShare(
          order: order,
          companyData: companyData,
          receiverData: receiverData,
          deliveryMeta: deliveryMeta,
          base64Logo: base64Logo,
          isArabic: _isArabic,
          translations: translations,
        );
      }
    }

    // ════════════════════════════════════════════
    // 6. تحديث حالة الطلب والمخزون (يحدث دائماً)
    // ════════════════════════════════════════════
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final orderRef =
          FirebaseFirestore.instance.collection('purchase_orders').doc(orderId);
      await orderRef.update({
        'status': newStatus,
        'isDelivered': newStatus == 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (newStatus == 'completed') {
        await _firestoreService.processStockDelivery(
          companyId: companyId,
          factoryId: factoryId,
          orderId: orderId,
          userId: user.uid,
          items: items,
        );
      }

      await _refreshAfterUpdate();
    } catch (e) {
      safeDebugPrint('Error updating status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('update_error'.tr())),
        );
      }
    }
  }

  // ─── بناء بطاقة الطلب ──────────────────────────────────────
  Widget _buildOrderCard(Map<String, dynamic> order) {
    final netPayable = NumberFormat.currency(
      symbol: '',
      decimalDigits: 2,
    ).format(order['netPayable'] ?? 0);

    DateTime orderDate;
    try {
      if (order['orderDate'] is Timestamp) {
        orderDate = (order['orderDate'] as Timestamp).toDate();
      } else if (order['orderDate'] is int) {
        orderDate = DateTime.fromMillisecondsSinceEpoch(order['orderDate']);
      } else {
        orderDate = DateTime.now();
      }
    } catch (e) {
      orderDate = DateTime.now();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getStatusColor(order['status']).withAlpha(76),
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          '/purchase/${order['id']}',
          extra: order,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order['poNumber'] ?? '${order['id']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order['status']),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (order['status'] ?? 'pending').toString().toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (_userCompaniesCount > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.business, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order['companyName'] ?? '',
                          style: TextStyle(color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order['supplierName'] ?? '',
                        style: TextStyle(color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16, thickness: 1),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateFormat('yyyy-MM-dd').format(orderDate),
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '$netPayable ${'currency'.tr()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              if (order['status'] == 'pending')
                SwitchListTile(
                  title: Text('delivered'.tr()),
                  value: order['status'] == 'completed',
                  onChanged: (val) async {
                    if (val) {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('confirm_delivery'.tr()),
                          content: Text('confirm_mark_delivered'.tr()),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('cancel'.tr()),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text('confirm'.tr()),
                            ),
                          ],
                        ),
                      );

                      if (confirmed != true) return;
                    }

                    await _updateOrderStatus(
                      order['id'],
                      order['companyId'],
                      val ? 'completed' : 'pending',
                      order['items'],
                      order['factoryId'],
                      order,
                    );

                    if (mounted) {
                      await _loadAllOrders();
                    }
                  },
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (order['status'] == 'pending')
                    IconButton(
                      icon:
                          const Icon(Icons.edit, size: 20, color: Colors.blue),
                      tooltip: 'edit'.tr(),
                      onPressed: () => _editOrder(order),
                    ),
                  // ✅ زر PDF المعدل
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf,
                        size: 20, color: Colors.green),
                    tooltip: 'export_pdf'.tr(),
                    onPressed: () => _exportOrder(order),
                  ),
                  if (order['status'] == 'pending')
                    IconButton(
                      icon:
                          const Icon(Icons.delete, size: 20, color: Colors.red),
                      tooltip: 'delete'.tr(),
                      onPressed: () => _confirmDeleteOrder(order),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── بناء الصفحة الرئيسية ──────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return AppScaffold(
        title: 'purchase_orders'.tr(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    safeDebugPrint('User companies count: $_userCompaniesCount');

    return Directionality(
      textDirection: Directionality.of(context),
      child: AppScaffold(
        title: 'purchase_orders'.tr(),
        actions: [
          HoverAddButton(
            onPressed: () async {
              final result = await context.push('/add-purchase-order');
              if (result == true && mounted) await _loadAllOrders();
              _filterOrders(searchQuery);
            },
            tooltip: 'add_purchase_order'.tr(),
            iconColor: Colors.white,
            iconSize: 28,
          ),
        ],
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'search'.tr(),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: 'search_hint'.tr(),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_userCompaniesCount > 1)
                    IconButton(
                      icon: const Icon(Icons.business),
                      tooltip: 'multiple_companies'.tr(),
                      onPressed: _showCompanySelector,
                    ),
                  IconButton(
                    icon: const Icon(Icons.sort),
                    onPressed: _showSortOptions,
                    tooltip: 'sort_options'.tr(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredOrders.isEmpty
                      ? Center(child: Text('no_match_search'.tr()))
                      : RefreshIndicator(
                          onRefresh: _loadAllOrders,
                          child: ListView.builder(
                            itemCount: _filteredOrders.length,
                            itemBuilder: (ctx, index) {
                              final order = _filteredOrders[index];
                              return _buildOrderCard(order);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
} */
// purchase_orders_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:puresip_purchasing/services/firestore_service.dart';
import 'package:puresip_purchasing/utils/pdf_exporter.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:puresip_purchasing/widgets/hover_add_button.dart';
import 'package:universal_html/html.dart' as html;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/utils/delivery_note_pdf.dart';
import 'package:puresip_purchasing/models/stock_receipt.dart';
import 'package:puresip_purchasing/services/accounting_service.dart';
import 'package:puresip_purchasing/widgets/receiving_dialog.dart';

class PurchaseOrdersPage extends StatefulWidget {
  const PurchaseOrdersPage({super.key});

  @override
  State<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> {
  // ─── المتغيرات الأساسية ──────────────────────────────────────
  String searchQuery = '';
  bool isLoading = true;
  String? userName;
  final List<Map<String, dynamic>> _allOrders = [];
  final List<Map<String, dynamic>> _filteredOrders = [];
  bool _isSearching = false;
  int _userCompaniesCount = 1;
  String _currentSortOption = 'dateDesc';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _userCompanies = [];
  String? _selectedCompanyId;
  final FirestoreService _firestoreService = FirestoreService();
  late final languageCode = context.locale.languageCode;
  late bool _isArabic;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _getCurrentUserId();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _getCurrentUserId() {
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    safeDebugPrint('👤 Current user ID: $_currentUserId');
  }

  bool _isDataLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isDataLoaded) {
      _isDataLoaded = true;
      setState(() {
        _isArabic = context.locale.languageCode == 'ar';
      });
      safeDebugPrint("Current language is Arabic? $_isArabic");
      _initData();
    }
  }

  // ─── تحميل البيانات ─────────────────────────────────────────
  Future<void> _initData() async {
    await loadUserInfo();
    await _loadUserCompaniesCount();
    await _loadAllOrders();
    await _loadUserCompanies();
  }

  Future<void> loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final email = user.email ?? '';
      final name = user.displayName ?? '';
      setState(() {
        userName = name.isNotEmpty ? name : email.split('@')[0];
        _currentUserId = user.uid;
      });
    }
  }

  // ─── كاش الشركات والموردين ──────────────────────────────────
  final Map<String, String> _companyNameCache = {};
  final Map<String, String> _supplierNameCache = {};

  Future<void> _loadUserCompaniesCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final cachedCount = prefs.getInt('userCompaniesCount');
    if (cachedCount != null) {
      setState(() => _userCompaniesCount = cachedCount);
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = userDoc.data() ?? {};
    final companyIds = List<String>.from(data['companyIds'] ?? []);

    await prefs.setInt('userCompaniesCount', companyIds.length);
    setState(() => _userCompaniesCount = companyIds.length);

    await _loadUserCompaniesFromIds(companyIds);
  }

  Future<void> _loadUserCompanies() async {
    if (_userCompanies.isNotEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final companyIds = List<String>.from(userDoc.data()?['companyIds'] ?? []);
    await _loadUserCompaniesFromIds(companyIds);
  }

  Future<void> _loadUserCompaniesFromIds(List<String> companyIds) async {
    if (companyIds.isEmpty) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('companies')
        .where(FieldPath.documentId, whereIn: companyIds)
        .get();

    _userCompanies = snapshot.docs.map((doc) {
      final name = _isArabic
          ? doc.data()['nameAr'] ?? doc.id
          : doc.data()['nameEn'] ?? doc.id;
      _companyNameCache[doc.id] = name;
      return {'id': doc.id, 'name': name};
    }).toList();
  }

  Future<void> _loadAllOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (mounted) setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cachedOrders');
      final cacheTime = prefs.getInt('cachedOrdersTime') ?? 0;
      final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTime;

      if (cachedJson != null && cacheAge < 300000) {
        final List decoded = json.decode(cachedJson);
        // ✅ تصفية الطلبات: فقط الخاصة بالمستخدم الحالي
        final userOrders = decoded
            .cast<Map<String, dynamic>>()
            .where((order) => order['userId'] == user.uid)
            .toList();
        _allOrders
          ..clear()
          ..addAll(userOrders);
        _filterOrders(searchQuery);
        if (mounted) setState(() => isLoading = false);
        _fetchOrdersFromFirestore(user.uid, prefs, background: true);
        return;
      }

      await _fetchOrdersFromFirestore(user.uid, prefs, background: false);
    } catch (e) {
      safeDebugPrint('Error loading orders: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchOrdersFromFirestore(String userId, SharedPreferences prefs,
      {required bool background}) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('purchase_orders')
          .where('userId', isEqualTo: userId)
          .orderBy('orderDate', descending: true)
          .get();

      final companyIds = <String>{};
      final supplierIds = <String>{};
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        if (data['companyId'] != null) companyIds.add(data['companyId']);
        if (data['supplierId'] != null) supplierIds.add(data['supplierId']);
      }

      final missingCompanies =
          companyIds.where((id) => !_companyNameCache.containsKey(id)).toList();
      final missingSuppliers = supplierIds
          .where((id) => !_supplierNameCache.containsKey(id))
          .toList();

      await Future.wait([
        if (missingCompanies.isNotEmpty)
          FirebaseFirestore.instance
              .collection('companies')
              .where(FieldPath.documentId, whereIn: missingCompanies)
              .get()
              .then((snap) {
            for (final doc in snap.docs) {
              _companyNameCache[doc.id] = _isArabic
                  ? doc.data()['nameAr'] ?? doc.id
                  : doc.data()['nameEn'] ?? doc.id;
            }
          }),
        if (missingSuppliers.isNotEmpty)
          FirebaseFirestore.instance
              .collection('vendors')
              .where(FieldPath.documentId, whereIn: missingSuppliers)
              .get()
              .then((snap) {
            for (final doc in snap.docs) {
              _supplierNameCache[doc.id] = _isArabic
                  ? doc.data()['nameAr'] ?? doc.id
                  : doc.data()['nameEn'] ?? doc.id;
            }
          }),
      ]);

      final orders = querySnapshot.docs.map((doc) {
        final data = doc.data();

        final serializable = data.map((key, value) {
          if (value is Timestamp) {
            return MapEntry(key, value.toDate().toIso8601String());
          }
          return MapEntry(key, value);
        });

        return {
          ...serializable,
          'id': doc.id,
          'companyName': _companyNameCache[data['companyId']] ?? '',
          'supplierName': _supplierNameCache[data['supplierId']] ?? '',
        };
      }).toList();

      try {
        await prefs.setString('cachedOrders', json.encode(orders));
        await prefs.setInt(
            'cachedOrdersTime', DateTime.now().millisecondsSinceEpoch);
      } catch (e) {
        safeDebugPrint('Cache save error: $e');
      }

      if (mounted) {
        _allOrders
          ..clear()
          ..addAll(orders);
        _filterOrders(searchQuery);
        setState(() => isLoading = false);
      }
    } catch (e) {
      safeDebugPrint('Firestore fetch error: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ─── دوال مساعدة ────────────────────────────────────────────
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ─── حوار إدخال بيانات إذن التسليم ──────────────────────────
  Future<Map<String, dynamic>?> _showDeliveryNoteDialog() async {
    final controller = TextEditingController(
      text: 'DN-${DateFormat('yyyyMMdd').format(DateTime.now())}-01',
    );
    final dateController = TextEditingController(
      text: DateFormat('dd-MM-yyyy').format(DateTime.now()),
    );
    final notesController = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('delivery_note_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: controller,
                decoration: InputDecoration(labelText: 'delivery_number'.tr())),
            TextField(
                controller: dateController,
                decoration: InputDecoration(labelText: 'delivery_date'.tr())),
            TextField(
                controller: notesController,
                decoration: InputDecoration(labelText: 'notes'.tr()),
                maxLines: 2),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text('cancel'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(ctx, {
              'deliveryNumber': controller.text,
              'deliveryDate': dateController.text,
              'notes': notesController.text,
            }),
            child: Text('print'.tr()),
          ),
        ],
      ),
    );
  }

  // ─── حوار اختيار الطباعة عند تغيير الحالة ──────────────────
  Future<bool?> _showPrintChoiceDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('print_choice_title'.tr()),
        content: Text('print_choice_content'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), // false = أمر الشراء
            child: Text('print_choice_po'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), // true = إذن التسليم
            child: Text('print_choice_delivery'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx), // إلغاء
            child: Text('cancel'.tr()),
          ),
        ],
      ),
    );
  }

  // ─── حوار اختيار الطباعة عند النقر على زر PDF لطلب مكتمل ──
  Future<bool?> _showPrintChoiceDialogForExport() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('print_choice_title'.tr()),
        content: Text('print_choice_content_export'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), // false = أمر الشراء
            child: Text('print_choice_po'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), // true = إذن التسليم
            child: Text('print_choice_delivery'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx), // إلغاء
            child: Text('cancel'.tr()),
          ),
        ],
      ),
    );
  }

  // ─── حوار تعديل الكميات ──────────────────────────────────────
  Future<Map<String, dynamic>?> _showReceivingDialog(
    Map<String, dynamic> order,
  ) async {
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);
    if (items.isEmpty) return null;

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ReceivingDialog(
        items: items,
        orderNumber: order['poNumber'] ?? order['id'],
      ),
    );
  }

  // ─── دالة مشاركة PDF ────────────────────────────────────────
  Future<void> _sharePdf(Uint8List bytes, String fileName) async {
    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..download = fileName
        ..style.display = 'none';
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    }
  }

  // ─── طباعة أمر الشراء ────────────────────────────────────────
  Future<void> _exportPurchaseOrder(Map<String, dynamic> order) async {
    Map<String, dynamic> companyData;
    Map<String, dynamic> supplierData;
    String? base64Logo;

    final hasCompanyData =
        order['companyNameAr'] != null && order['companyNameEn'] != null;
    final hasSupplierData =
        order['supplierNameAr'] != null && order['supplierNameEn'] != null;

    if (hasCompanyData && hasSupplierData) {
      companyData = {
        'nameAr': order['companyNameAr'],
        'nameEn': order['companyNameEn'],
        'logoBase64': order['logoBase64'],
      };
      supplierData = {
        'nameAr': order['supplierNameAr'],
        'nameEn': order['supplierNameEn'],
      };
      base64Logo = order['logoBase64'];
    } else {
      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(order['companyId'])
          .get();
      final supplierDoc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(order['supplierId'])
          .get();
      companyData = companyDoc.data() ?? {};
      supplierData = supplierDoc.data() ?? {};
      base64Logo = companyData['logoBase64'] as String?;
    }

    final pdf = await PdfExporter.generatePurchaseOrderPdf(
      orderId: order['id'],
      orderData: order,
      supplierData: supplierData,
      companyData: companyData,
      itemData: {'items': order['items'] ?? []},
      base64Logo: base64Logo,
      isArabic: _isArabic,
    );

    final bytes = await pdf.save();
    await _sharePdf(bytes, 'order_${order['poNumber'] ?? order['id']}.pdf');
  }

  // ─── طباعة إذن التسليم ──────────────────────────────────────
  Future<void> _printDeliveryNoteFromOrder(Map<String, dynamic> order) async {
    try {
      final companyData = {
        'nameAr': order['companyNameAr'] ?? order['companyName'] ?? '',
        'nameEn': order['companyNameEn'] ?? order['companyName'] ?? '',
        'logoBase64': order['logoBase64'],
      };

      final hasFactory =
          order['factoryId'] != null && order['factoryId'].isNotEmpty;
      final hasSupplier =
          order['supplierId'] != null && order['supplierId'].isNotEmpty;

      Map<String, dynamic> receiverData = {};
      if (hasFactory) {
        receiverData = {
          'nameAr': order['factoryNameAr'] ?? 'مصنع غير معروف'.tr(),
          'nameEn': order['factoryNameEn'] ?? 'Unknown Factory'.tr(),
        };
      } else if (hasSupplier) {
        receiverData = {
          'nameAr': order['supplierNameAr'] ??
              order['supplierName'] ??
              'مورد غير معروف'.tr(),
          'nameEn': order['supplierNameEn'] ??
              order['supplierName'] ??
              'Unknown Supplier'.tr(),
        };
      } else {
        receiverData = {
          'nameAr': 'جهة مستلمة غير محددة'.tr(),
          'nameEn': 'Unknown Receiver'.tr(),
        };
      }

      final deliveryMeta = {
        'deliveryNumber':
            'DN-${DateFormat('yyyyMMdd').format(DateTime.now())}-${order['poNumber']?.substring(order['poNumber'].length - 3) ?? '01'}',
        'deliveryDate': DateFormat('dd-MM-yyyy').format(DateTime.now()),
        'notes': '',
      };

      final translations = {
        'deliveryNoteTitle': tr('delivery_note_title'),
        'deliveryNumberLabel': tr('delivery_number_label'),
        'dateLabel': tr('date_label'),
        'poLabel': tr('po_label'),
        'methodLabel': tr('method_label'),
        'methodValue': tr('method_value'),
        'purposeLabel': tr('purpose_label'),
        'purposeDefault': tr('purpose_default'),
        'senderLabel': tr('sender_label'),
        'receiverLabel': tr('receiver_label'),
        'serialLabel': tr('serial_label'),
        'itemNameLabel': tr('item_name_label'),
        'unitLabel': tr('unit_label'),
        'qtyLabel': tr('qty_label'),
        'notesLabel': tr('notes_label'),
        'notesSectionTitle': tr('notes_section_title'),
        'totalItemsLabel': tr('total_items_label'),
        'totalQtyLabel': tr('total_qty_label'),
        'unitSuffix': tr('unit_suffix'),
        'note1': tr('note1'),
        'note2': tr('note2'),
        'note3': tr('note3'),
        'acknowledgmentTitle': tr('acknowledgment_title'),
        'acknowledgmentText': tr('acknowledgment_text'),
        'storekeeper': tr('storekeeper'),
        'nameLabel': tr('name_label'),
        'signatureLabel': tr('signature_label'),
        'dateLabel2': tr('date_label2'),
        'delegate': tr('delegate'),
        'vehicleLabel': tr('vehicle_label'),
        'receiverOfficial': tr('receiver_official'),
        'stampLabel': tr('stamp_label'),
        'footerText': tr('footer_text'),
      };

      await DeliveryNotePdf.generateAndShare(
        order: order,
        companyData: companyData,
        receiverData: receiverData,
        deliveryMeta: deliveryMeta,
        base64Logo: order['logoBase64'],
        isArabic: _isArabic,
        translations: translations,
      );
    } catch (e) {
      safeDebugPrint('Error printing delivery note: $e');
      rethrow;
    }
  }

  // ─── وظيفة التصدير الرئيسية (زر PDF) ──────────────────────
  Future<void> _exportOrder(Map<String, dynamic> order) async {
    setState(() => _isSearching = true);
    try {
      final status = order['status'] ?? 'pending';

      if (status == 'completed') {
        final choice = await _showPrintChoiceDialogForExport();
        if (choice == null) return;

        if (choice == false) {
          await _exportPurchaseOrder(order);
        } else {
          await _printDeliveryNoteFromOrder(order);
        }
      } else {
        await _exportPurchaseOrder(order);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'export_error'.tr()}: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      safeDebugPrint('PDF Export Error: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ─── دوال أخرى (تحديث، حذف، إلخ) ──────────────────────────
  Future<void> _refreshAfterUpdate() async {
    if (mounted) {
      setState(() => isLoading = true);
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadAllOrders();
    }
  }

  void _sortOrders() {
    _allOrders.sort((a, b) {
      try {
        Timestamp aDate;
        Timestamp bDate;

        if (a['orderDate'] is Timestamp) {
          aDate = a['orderDate'] as Timestamp;
        } else if (a['orderDate'] is int) {
          aDate = Timestamp.fromMillisecondsSinceEpoch(a['orderDate']);
        } else {
          aDate = Timestamp.now();
        }

        if (b['orderDate'] is Timestamp) {
          bDate = b['orderDate'] as Timestamp;
        } else if (b['orderDate'] is int) {
          bDate = Timestamp.fromMillisecondsSinceEpoch(b['orderDate']);
        } else {
          bDate = Timestamp.now();
        }

        switch (_currentSortOption) {
          case 'dateDesc':
            return bDate.compareTo(aDate);
          case 'dateAsc':
            return aDate.compareTo(bDate);
          case 'amountDesc':
            return (b['totalAmountAfterTax'] as num)
                .compareTo(a['totalAmountAfterTax'] as num);
          case 'amountAsc':
            return (a['totalAmountAfterTax'] as num)
                .compareTo(b['totalAmountAfterTax'] as num);
          default:
            return 0;
        }
      } catch (e) {
        safeDebugPrint('Error sorting orders: $e');
        return 0;
      }
    });
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = _searchController.text.toLowerCase();
      _filterOrders(searchQuery);
    });
  }

  void _filterOrders(String query) {
    _filteredOrders.clear();
    _filteredOrders.addAll(_allOrders.where((order) {
      final matchesQuery = [
        (order['poNumber'] ?? '').toString().toLowerCase(),
        (order['supplierName'] ?? '').toString().toLowerCase(),
        (order['companyName'] ?? '').toString().toLowerCase(),
        (order['status'] ?? '').toString().toLowerCase(),
      ].any((field) => field.contains(query.toLowerCase()));

      final matchesCompany = _selectedCompanyId == null ||
          order['companyId'] == _selectedCompanyId;

      return matchesQuery && matchesCompany;
    }));
  }

  void _showCompanySelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: Text('show_all'.tr()),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedCompanyId = null;
                  _filterOrders(searchQuery);
                });
              },
            ),
            ..._userCompanies.map((company) => ListTile(
                  leading: const Icon(Icons.business),
                  title: Text(company['name']),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedCompanyId = company['id'];
                      _filterOrders(searchQuery);
                    });
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('sort_by_date_desc'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentSortOption = 'dateDesc';
                    _sortOrders();
                    _filterOrders(searchQuery);
                  });
                },
              ),
              ListTile(
                title: Text('sort_by_date_asc'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentSortOption = 'dateAsc';
                    _sortOrders();
                    _filterOrders(searchQuery);
                  });
                },
              ),
              ListTile(
                title: Text('sort_by_amount_desc'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentSortOption = 'amountDesc';
                    _sortOrders();
                    _filterOrders(searchQuery);
                  });
                },
              ),
              ListTile(
                title: Text('sort_by_amount_asc'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentSortOption = 'amountAsc';
                    _sortOrders();
                    _filterOrders(searchQuery);
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _editOrder(Map<String, dynamic> order) async {
    safeDebugPrint('✏️ Editing order: ${order['poNumber']}');

    final result = await context.push(
      '/purchase/${order['id']}',
      extra: order,
    );

    safeDebugPrint('🔍 Result from edit page: $result');

    if (result == true && mounted) {
      safeDebugPrint('🔄 Order was updated, refreshing list...');
      setState(() => isLoading = true);
      await _loadAllOrders();
      _filterOrders(searchQuery);
      setState(() => isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('order_updated_successfully'.tr()),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      safeDebugPrint('ℹ️ Order was not updated or result is false');
    }
  }

  void _confirmDeleteOrder(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_delete'.tr()),
        content: Text('delete_order_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              safeDebugPrint(
                  '🧪 Trying to delete order with ID: ${order['id']}');

              _deleteOrder(order);
            },
            child:
                Text('delete'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteOrder(Map<String, dynamic> order) async {
    try {
      await FirebaseFirestore.instance
          .collection('purchase_orders')
          .doc(order['id'])
          .delete();
      safeDebugPrint('🧪 Trying to delete order with ID: ${order['id']}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('order_deleted'.tr())),
        );
        _loadAllOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('delete_error'.tr())),
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════
  // ✅ الدالة الرئيسية لتحديث الحالة (مع تحقق صارم)
  // ══════════════════════════════════════════════════════════════
  Future<void> _updateOrderStatus(
    String orderId,
    String companyId,
    String newStatus,
    List<dynamic> items,
    String factoryId,
    Map<String, dynamic> order,
  ) async {
    // ── التحقق من المستخدم ──
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      safeDebugPrint('❌ No user logged in.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('يرجى تسجيل الدخول'), backgroundColor: Colors.red),
      );
      return;
    }

    safeDebugPrint('🔍 _updateOrderStatus called by user: ${user.uid}');
    safeDebugPrint('📦 Order userId: ${order['userId']}');
    safeDebugPrint('📦 Order companyId: ${order['companyId']}');

    // ═══════════════════════════════════════════════════════════
    // 🔒 ✅ التحقق الصارم: المستخدم يجب أن يملك هذا الطلب
    // ═══════════════════════════════════════════════════════════
    if (order['userId'] != user.uid) {
      safeDebugPrint('⛔ SECURITY: User does NOT own this order!');
      safeDebugPrint('  👤 User: ${user.uid}');
      safeDebugPrint('  📦 Order owner: ${order['userId']}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⛔ لا يمكنك إكمال هذا الطلب لأنه ليس ملكك.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // ═══════════════════════════════════════════════════════════
    // ✅ تحقق إضافي: المستخدم يجب أن يملك الشركة
    // ═══════════════════════════════════════════════════════════
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final userCompanies =
        List<String>.from(userDoc.data()?['companyIds'] ?? []);
    if (!userCompanies.contains(order['companyId'])) {
      safeDebugPrint('⛔ SECURITY: User does NOT own the order company!');
      safeDebugPrint('  🏢 User companies: $userCompanies');
      safeDebugPrint('  📦 Order company: ${order['companyId']}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⛔ لا يمكنك إكمال هذا الطلب لأنك لا تملك الشركة.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // تعريف المتغيرات
    List<Map<String, dynamic>>? receivedItems;
    double? totalReceivedAmount;

    if (newStatus == 'completed') {
      final hasFactory =
          (order['factoryId'] != null && order['factoryId'].isNotEmpty);
      final hasSupplier =
          (order['supplierId'] != null && order['supplierId'].isNotEmpty);

      if (!hasFactory && !hasSupplier) {
        safeDebugPrint('⛔ No receiver defined (factory or supplier).');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('no_receiver_defined'.tr()),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // ✅ عرض حوار اختيار المستند
      final printChoice = await _showPrintChoiceDialog();
      if (printChoice == null) {
        safeDebugPrint('ℹ️ User cancelled print choice.');
        return;
      }

      // ✅ عرض حوار تعديل الكميات
      final receivingResult = await _showReceivingDialog(order);
      if (receivingResult == null) {
        safeDebugPrint('ℹ️ User cancelled receiving dialog.');
        return;
      }

      receivedItems = List<Map<String, dynamic>>.from(receivingResult['items']);
      totalReceivedAmount = receivingResult['totalAmount'] as double;

      safeDebugPrint('📊 Received items count: ${receivedItems.length}');
      safeDebugPrint('💰 Total received amount: $totalReceivedAmount');

      // ═══════════════════════════════════════════════════════════
      // 📦 تحديث المخزون
      // ═══════════════════════════════════════════════════════════
      try {
        // ✅ تأكد من أن الدالة موجودة في FirestoreService
        // إذا لم تكن موجودة، استخدم الكود الاحتياطي
        await _firestoreService.processStockDeliveryWithActual(
          companyId: companyId,
          factoryId: factoryId,
          orderId: orderId,
          userId: user.uid,
          items: receivedItems,
        );
        safeDebugPrint('✅ Stock updated successfully.');
      } catch (e, stackTrace) {
        safeDebugPrint('❌ Error updating stock: $e');
        safeDebugPrint('📚 Stack trace: $stackTrace');

        // ⚠️ محاولة احتياطية: استخدام الدالة القديمة
        try {
          safeDebugPrint('🔄 Retrying with processStockDelivery...');
          await _firestoreService.processStockDelivery(
            companyId: companyId,
            factoryId: factoryId,
            orderId: orderId,
            userId: user.uid,
            items: receivedItems
                .map((i) => {
                      ...i,
                      'quantity': i['receivedQuantity'],
                    })
                .toList(),
          );
          safeDebugPrint('✅ Stock updated using fallback method.');
        } catch (e2) {
          safeDebugPrint('❌ Fallback also failed: $e2');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('فشل تحديث المخزون: ${e.toString().substring(0, 100)}'),
              backgroundColor: Colors.red,
            ),
          );
          return; // الخروج دون تحديث الحالة
        }
      }
// ── تعريف receiptId خارج try ──
      String receiptId = '';

// ── إنشاء سند الاستلام ──
      try {
        receiptId = 'SR-${DateTime.now().millisecondsSinceEpoch}';

        final receipt = StockReceipt(
          id: receiptId,
          companyId: companyId,
          purchaseOrderId: orderId,
          factoryId: factoryId,
          supplierId: order['supplierId'] ?? '',
          receivedDate: DateTime.now(),
          items: receivedItems
              .map((i) => StockReceiptItem(
                    itemId: i['itemId'] ?? '',
                    orderedQuantity:
                        (i['orderedQuantity'] as num?)?.toDouble() ?? 0,
                    receivedQuantity:
                        (i['receivedQuantity'] as num?)?.toDouble() ?? 0,
                    unitPrice: (i['unitPrice'] as num?)?.toDouble() ?? 0,
                    totalAmount: (i['totalAmount'] as num?)?.toDouble() ?? 0,
                  ))
              .toList(),
          totalReceivedAmount: totalReceivedAmount,
          createdAt: DateTime.now(),
          createdBy: user.uid,
          notes: 'تم الاستلام من أمر توريد ${order['poNumber']}',
        );

        await FirebaseFirestore.instance
            .collection('stock_receipts')
            .doc(receiptId)
            .set(receipt.toMap());
        safeDebugPrint('✅ Stock receipt created: $receiptId');
      } catch (e) {
        safeDebugPrint('⚠️ Error creating stock receipt (non-fatal): $e');
        // استمر رغم الخطأ لأن المخزون تم تحديثه بالفعل
      }

// ── إنشاء القيد المحاسبي (يستخدم receiptId) ──
/*       try {
        final accountingService = AccountingService();

        final inventoryAccount = await accountingService.getAccountByCode(
          companyId: companyId,
          code: '1100',
        );
        if (inventoryAccount == null) {
          safeDebugPrint(
              '⚠️ Inventory account not found, creating default accounts...');
          await accountingService.createDefaultAccounts(
            companyId: companyId,
            userId: user.uid,
            languageCode: languageCode,
          );
        }

        // استخدم receiptId هنا (سيكون فارغاً إذا فشل إنشاء السند، لكن نستمر)
        final journalEntryId =
            await accountingService.createPurchaseReceiptJournalEntry(
          companyId: companyId,
          supplierId: order['supplierId'] ?? '',
          receiptId: receiptId.isNotEmpty
              ? receiptId
              : 'SR-${DateTime.now().millisecondsSinceEpoch}',
          purchaseOrderId: orderId,
          totalAmount: totalReceivedAmount,
          userId: user.uid,
          entryDate: DateTime.now(),
          languageCode: languageCode,
        );

        if (receiptId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('stock_receipts')
              .doc(receiptId)
              .update({'journalEntryId': journalEntryId});
        }

        safeDebugPrint('✅ Journal entry created: $journalEntryId');
      } catch (e) {
        safeDebugPrint('⚠️ Error creating journal entry (non-fatal): $e');
      }

      // ── إنشاء القيد المحاسبي ──
      try {
        final accountingService = AccountingService();

        final inventoryAccount = await accountingService.getAccountByCode(
          companyId: companyId,
          code: '1100',
        );
        if (inventoryAccount == null) {
          safeDebugPrint(
              '⚠️ Inventory account not found, creating default accounts...');
          await accountingService.createDefaultAccounts(
            companyId: companyId,
            userId: user.uid,
            languageCode: languageCode,
          );
        }

        final journalEntryId =
            await accountingService.createPurchaseReceiptJournalEntry(
          companyId: companyId,
          supplierId: order['supplierId'] ?? '',
          receiptId: receiptId,
          purchaseOrderId: orderId,
          totalAmount: totalReceivedAmount,
          userId: user.uid,
          entryDate: DateTime.now(),
          languageCode: languageCode,
        );

        await FirebaseFirestore.instance
            .collection('stock_receipts')
            .doc(receiptId)
            .update({'journalEntryId': journalEntryId});

        safeDebugPrint('✅ Journal entry created: $journalEntryId');
      } catch (e) {
        safeDebugPrint('⚠️ Error creating journal entry (non-fatal): $e');
      } */
// ── إنشاء القيد المحاسبي ──
try {
  final accountingService = AccountingService();
  final inventoryAccount = await accountingService.getAccountByCode(
    companyId: companyId,
    code: '1100',
  );
  if (inventoryAccount == null) {
    await accountingService.createDefaultAccounts(
      companyId: companyId,
      userId: user.uid,
    //  languageCode: languageCode,
    );
  }

  final journalEntryId = await accountingService.createPurchaseReceiptJournalEntry(
    companyId: companyId,
    supplierId: order['supplierId'] ?? '',
    receiptId: receiptId,
    purchaseOrderId: orderId,
    totalAmount: totalReceivedAmount,
    userId: user.uid,
    entryDate: DateTime.now(),
   // languageCode: languageCode,
  );

  await FirebaseFirestore.instance
      .collection('stock_receipts')
      .doc(receiptId)
      .update({'journalEntryId': journalEntryId});

  safeDebugPrint('✅ Journal entry created: $journalEntryId');
} catch (e) {
  safeDebugPrint('⚠️ Error creating journal entry (non-fatal): $e');
}
      // ── طباعة المستند المطلوب ──
      if (printChoice == false) {
        await _exportPurchaseOrder(order);
      } else {
        final deliveryMeta = await _showDeliveryNoteDialog();
        if (deliveryMeta != null) {
          final updatedOrder = Map<String, dynamic>.from(order);
          updatedOrder['items'] = receivedItems.map((i) {
            return {
              ...i,
              'quantity': i['receivedQuantity'],
            };
          }).toList();

          await _printDeliveryNoteFromOrder(updatedOrder);
        }
      }
    }

    // ── تحديث حالة الطلب في Firestore ──
    try {
      final orderRef =
          FirebaseFirestore.instance.collection('purchase_orders').doc(orderId);

      final updateData = {
        'status': newStatus,
        'isDelivered': newStatus == 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (receivedItems != null && totalReceivedAmount != null) {
        updateData['actualReceivedItems'] = receivedItems;
        updateData['totalReceivedAmount'] = totalReceivedAmount;
      }

      await orderRef.update(updateData);
      safeDebugPrint('✅ Order status updated to $newStatus');

      // ── تحديث الكاش المحلي ──
      await _updateLocalCache(orderId, updateData);

      await _refreshAfterUpdate();
    } catch (e, stackTrace) {
      safeDebugPrint('❌ Error updating order status: $e');
      safeDebugPrint('📚 Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('update_error'.tr())),
        );
      }
    }
  }

  // ─── تحديث الكاش المحلي ──────────────────────────────────────
  Future<void> _updateLocalCache(
      String orderId, Map<String, dynamic> updateData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cachedOrders');
      if (cachedJson == null) {
        safeDebugPrint('ℹ️ No cache to update');
        return;
      }

      final List<dynamic> decoded = json.decode(cachedJson);
      final List<Map<String, dynamic>> orders =
          decoded.cast<Map<String, dynamic>>();

      for (int i = 0; i < orders.length; i++) {
        if (orders[i]['id'] == orderId) {
          // تحديث الحقول المطلوبة فقط
          orders[i]['status'] = updateData['status'];
          orders[i]['isDelivered'] = updateData['isDelivered'];
          if (updateData.containsKey('actualReceivedItems')) {
            orders[i]['actualReceivedItems'] =
                updateData['actualReceivedItems'];
          }
          if (updateData.containsKey('totalReceivedAmount')) {
            orders[i]['totalReceivedAmount'] =
                updateData['totalReceivedAmount'];
          }
          break;
        }
      }

      await prefs.setString('cachedOrders', json.encode(orders));
      safeDebugPrint('✅ Local cache updated for order $orderId');
    } catch (e) {
      safeDebugPrint('⚠️ Error updating local cache: $e');
    }
  }

  // ─── بناء بطاقة الطلب ──────────────────────────────────────
  Widget _buildOrderCard(Map<String, dynamic> order) {
    final netPayable = NumberFormat.currency(
      symbol: '',
      decimalDigits: 2,
    ).format(order['netPayable'] ?? 0);

    DateTime orderDate;
    try {
      if (order['orderDate'] is Timestamp) {
        orderDate = (order['orderDate'] as Timestamp).toDate();
      } else if (order['orderDate'] is int) {
        orderDate = DateTime.fromMillisecondsSinceEpoch(order['orderDate']);
      } else {
        orderDate = DateTime.now();
      }
    } catch (e) {
      orderDate = DateTime.now();
    }

    final isOwnOrder = order['userId'] == _currentUserId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getStatusColor(order['status']).withAlpha(76),
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          '/purchase/${order['id']}',
          extra: order,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order['poNumber'] ?? '${order['id']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order['status']),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (order['status'] ?? 'pending').toString().toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (_userCompaniesCount > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.business, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order['companyName'] ?? '',
                          style: TextStyle(color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order['supplierName'] ?? '',
                        style: TextStyle(color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16, thickness: 1),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateFormat('yyyy-MM-dd').format(orderDate),
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '$netPayable ${'currency'.tr()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              if (order['status'] == 'pending' && isOwnOrder)
                SwitchListTile(
                  title: Text('delivered'.tr()),
                  value: order['status'] == 'completed',
                  onChanged: (val) async {
                    if (val) {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('confirm_delivery'.tr()),
                          content: Text('confirm_mark_delivered'.tr()),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('cancel'.tr()),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text('confirm'.tr()),
                            ),
                          ],
                        ),
                      );

                      if (confirmed != true) return;
                    }

                    await _updateOrderStatus(
                      order['id'],
                      order['companyId'],
                      val ? 'completed' : 'pending',
                      order['items'],
                      order['factoryId'],
                      order,
                    );

                    if (mounted) {
                      await _loadAllOrders();
                    }
                  },
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (order['status'] == 'pending' && isOwnOrder)
                    IconButton(
                      icon:
                          const Icon(Icons.edit, size: 20, color: Colors.blue),
                      tooltip: 'edit'.tr(),
                      onPressed: () => _editOrder(order),
                    ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf,
                        size: 20, color: Colors.green),
                    tooltip: 'export_pdf'.tr(),
                    onPressed: () => _exportOrder(order),
                  ),
                  if (order['status'] == 'pending' && isOwnOrder)
                    IconButton(
                      icon:
                          const Icon(Icons.delete, size: 20, color: Colors.red),
                      tooltip: 'delete'.tr(),
                      onPressed: () => _confirmDeleteOrder(order),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── بناء الصفحة الرئيسية ──────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return AppScaffold(
        title: 'purchase_orders'.tr(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    safeDebugPrint('User companies count: $_userCompaniesCount');

    return Directionality(
      textDirection: Directionality.of(context),
      child: AppScaffold(
        title: 'purchase_orders'.tr(),
        actions: [
          HoverAddButton(
            onPressed: () async {
              final result = await context.push('/add-purchase-order');
              if (result == true && mounted) await _loadAllOrders();
              _filterOrders(searchQuery);
            },
            tooltip: 'add_purchase_order'.tr(),
            iconColor: Colors.white,
            iconSize: 28,
          ),
        ],
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'search'.tr(),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: 'search_hint'.tr(),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_userCompaniesCount > 1)
                    IconButton(
                      icon: const Icon(Icons.business),
                      tooltip: 'multiple_companies'.tr(),
                      onPressed: _showCompanySelector,
                    ),
                  IconButton(
                    icon: const Icon(Icons.sort),
                    onPressed: _showSortOptions,
                    tooltip: 'sort_options'.tr(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredOrders.isEmpty
                      ? Center(child: Text('no_match_search'.tr()))
                      : RefreshIndicator(
                          onRefresh: _loadAllOrders,
                          child: ListView.builder(
                            itemCount: _filteredOrders.length,
                            itemBuilder: (ctx, index) {
                              final order = _filteredOrders[index];
                              return _buildOrderCard(order);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
