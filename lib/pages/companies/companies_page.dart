
// companies_page.dart - بدون Hive
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/app_scaffold.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class CompaniesPage extends StatefulWidget {
  const CompaniesPage({super.key});

  @override
  State<CompaniesPage> createState() => _CompaniesPageState();
}

class _CompaniesPageState extends State<CompaniesPage> {
  String searchQuery = '';
  List<String> userCompanyIds = [];
  List<Map<String, dynamic>> _companies = [];
  bool _isInitialLoading = true;
  bool _isDataLoading = false;
  String? userName;

  // ✅ مفاتيح التخزين المؤقت
  static const String _keyCompaniesCache = 'companies_cache';
  static const String _keyUserCompanyIds = 'user_company_ids_cache';
  static const String _keyLastUpdate = 'companies_last_update';
  static const String _keyUserName = 'user_name';
  static const String _keyUserData = 'user_data';

  // متغيرات لإدارة الكاش
  DateTime? _lastCacheUpdate;
  static const Duration _cacheDuration = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    safeDebugPrint('🚀 CompaniesPage initState called');
    _initializeFromCacheFirst();

    // Fail-safe timer لمنع التحميل اللانهائي
    Timer(const Duration(seconds: 3), () {
      if (mounted && _isInitialLoading) {
        setState(() {
          _isInitialLoading = false;
        });
        safeDebugPrint('⏰ FAIL-SAFE TIMER: _isInitialLoading forced to false');
      }
    });
  }

  // ======================== التهيئة من SharedPreferences أولاً ========================

  Future<void> _initializeFromCacheFirst() async {
    safeDebugPrint('📦 Loading companies from cache first...');

    try {
      await _loadUserData(); // ✅ أضف هذا السطر
      await _loadUserInfoFromCache();
      await _loadCompaniesFromCache();

      safeDebugPrint('✅ Cache initialization completed');
    } catch (e) {
      safeDebugPrint('❌ Error in initial cache load: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
        safeDebugPrint('✅ FINALLY: _isInitialLoading set to false');
      }
    }

    // بدء التحديث الخلفي فقط إذا كانت البيانات قديمة أو غير موجودة
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startBackgroundUpdatesIfNeeded();
      });
    }
  }

  Future<void> _loadUserInfoFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // جلب اسم المستخدم من SharedPreferences
      final cachedUserName = prefs.getString(_keyUserName);
      if (cachedUserName != null && cachedUserName.isNotEmpty) {
        setState(() {
          userName = cachedUserName;
        });
        safeDebugPrint('📝 User name loaded from cache: $userName');
        return;
      }

      // إذا لم يكن موجوداً، حاول استخراجه من بيانات المستخدم المشفرة
      final prefsOnly = await SharedPreferences.getInstance();
      final userDataString = prefsOnly.getString(_keyUserData);

      if (userDataString != null) {
        final Map<String, dynamic> userData = json.decode(userDataString);
        final email = userData['email'] ?? '';
        final name = userData['displayName'] ?? '';
        final extractedName = name.isNotEmpty ? name : email.split('@')[0];

        setState(() {
          userName = extractedName;
        });

        // حفظ اسم المستخدم بشكل منفصل للاستخدام السريع
        await prefs.setString(_keyUserName, extractedName);
        safeDebugPrint('📝 User name extracted and cached: $userName');
      }
    } catch (e) {
      safeDebugPrint('❌ Error loading user info from cache: $e');
    }
  }

// companies_page.dart - تعديل دالة _loadCompaniesFromCache

  Future<void> _loadCompaniesFromCache() async {
    try {
      safeDebugPrint('🔍 Loading companies from SharedPreferences...');

      final prefs = await SharedPreferences.getInstance();

      final lastUpdateMillis = prefs.getInt(_keyLastUpdate);
      if (lastUpdateMillis != null) {
        _lastCacheUpdate =
            DateTime.fromMillisecondsSinceEpoch(lastUpdateMillis);
      }

      final companiesJson = prefs.getString(_keyCompaniesCache);
      final companyIdsJson = prefs.getString(_keyUserCompanyIds);

      if (companiesJson != null && companyIdsJson != null) {
        final List<dynamic> decodedCompanies = json.decode(companiesJson);

        final List<Map<String, dynamic>> convertedCompanies = [];
        for (var company in decodedCompanies) {
          if (company is Map) {
            final Map<String, dynamic> convertedCompany = {};
            company.forEach((key, value) {
              // ✅ إذا كانت القيمة String وتبدو مثل Timestamp, يمكن تحويلها أو تركها
              convertedCompany[key.toString()] = value;
            });
            convertedCompanies.add(convertedCompany);
          }
        }

        if (mounted) {
          setState(() {
            _companies = convertedCompanies;
            userCompanyIds = (json.decode(companyIdsJson) as List)
                .map((id) => id.toString())
                .toList()
                .cast<String>();
          });
        }
        safeDebugPrint('✅ Companies loaded from cache: ${_companies.length}');
        return;
      }

      safeDebugPrint(
          '🔄 No companies found in cache, will fetch from Firestore');
      _lastCacheUpdate = null;
    } catch (e) {
      safeDebugPrint('❌ Error loading from cache: $e');
      _lastCacheUpdate = null;
    }
  }
  // ======================== منطق التحديث الذكي ========================

  bool _shouldFetchFreshData() {
    if (_companies.isEmpty) {
      safeDebugPrint('📦 No companies in cache, need to fetch');
      return true;
    }
    if (_lastCacheUpdate == null) {
      safeDebugPrint('📦 No last update time, need to fetch');
      return true;
    }
    final age = DateTime.now().difference(_lastCacheUpdate!);
    if (age > _cacheDuration) {
      safeDebugPrint(
          '📦 Cache expired (${age.inMinutes} min > ${_cacheDuration.inMinutes} min), need to fetch');
      return true;
    }
    safeDebugPrint(
        '✅ Cache is fresh (${age.inMinutes} min old), skipping fetch');
    return false;
  }

  void _startBackgroundUpdatesIfNeeded() {
    if (_shouldFetchFreshData()) {
      safeDebugPrint('🔄 Fetching fresh companies from Firestore...');
      _fetchCompaniesFromFirestore();
    } else {
      safeDebugPrint(
          '✅ Cached companies data is fresh, skipping Firestore fetch');
    }
  }

  // ======================== جلب البيانات من Firestore ========================

  Future<void> _fetchCompaniesFromFirestore() async {
    // أولاً: التأكد من وجود companyIds
    if (userCompanyIds.isEmpty) {
      safeDebugPrint('🔄 No company IDs in state, checking user data...');
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString(_keyUserData);

      if (userDataString != null) {
        final Map<String, dynamic> userData = json.decode(userDataString);
        if (userData['companyIds'] is List) {
          setState(() {
            userCompanyIds = (userData['companyIds'] as List).cast<String>();
          });
          safeDebugPrint('🔄 Got company IDs from user data: $userCompanyIds');
        }
      }
    }

    if (userCompanyIds.isEmpty) {
      safeDebugPrint('🔄 No company IDs to load from Firestore');
      return;
    }

    if (mounted) setState(() => _isDataLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('companies')
          .where(FieldPath.documentId, whereIn: userCompanyIds)
          .get();

      final companies = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      safeDebugPrint('✅ Firestore returned ${companies.length} companies');

      // حفظ في SharedPreferences
      await _saveCompaniesToCache(companies, userCompanyIds);

      if (mounted) {
        setState(() {
          _companies = companies.cast<Map<String, dynamic>>();
          _lastCacheUpdate = DateTime.now();
        });
        safeDebugPrint('✅ State updated with ${_companies.length} companies');
      }
    } catch (e) {
      safeDebugPrint('❌ Error loading companies from Firestore: $e');
    } finally {
      if (mounted) setState(() => _isDataLoading = false);
    }
  }

// companies_page.dart - تعديل دالة _saveCompaniesToCache

  Future<void> _saveCompaniesToCache(
      List<Map<String, dynamic>> companies, List<String> companyIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ تحويل Timestamp إلى String قبل التخزين
      final List<Map<String, dynamic>> convertedCompanies = [];
      for (var company in companies) {
        final Map<String, dynamic> converted = {};
        company.forEach((key, value) {
          if (value is Timestamp) {
            converted[key] = value
                .toDate()
                .toIso8601String(); // ✅ تحويل Timestamp إلى String
          } else {
            converted[key] = value;
          }
        });
        convertedCompanies.add(converted);
      }

      // حفظ الشركات المحولة
      await prefs.setString(
          _keyCompaniesCache, json.encode(convertedCompanies));

      // حفظ معرفات الشركات
      await prefs.setString(_keyUserCompanyIds, json.encode(companyIds));

      // حفظ وقت آخر تحديث
      await prefs.setInt(_keyLastUpdate, DateTime.now().millisecondsSinceEpoch);

      safeDebugPrint(
          '💾 Companies saved to SharedPreferences cache (${convertedCompanies.length} companies)');
    } catch (e) {
      safeDebugPrint('❌ Cache save error: $e');
    }
  }

  // ======================== عمليات إضافية ========================

  Future<void> _refreshData() async {
    if (mounted) setState(() => _isDataLoading = true);
    try {
      // إعادة جلب companyIds من SharedPreferences أولاً
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString(_keyUserData);

      if (userDataString != null) {
        final Map<String, dynamic> userData = json.decode(userDataString);
        if (userData['companyIds'] is List) {
          setState(() {
            userCompanyIds = (userData['companyIds'] as List).cast<String>();
          });
        }
      }
      // جلب جديد من Firestore وتحديث الكاش
      await _fetchCompaniesFromFirestore();
    } catch (e) {
      safeDebugPrint('❌ Error refreshing data: $e');
    } finally {
      if (mounted) setState(() => _isDataLoading = false);
    }
  }

  Future<void> _confirmDeleteCompany(
      String companyId, Map<String, dynamic> companyData) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('confirm_delete_title')),
        content: Text(tr('confirm_delete_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                Text(tr('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // حذف من Firestore
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .delete();

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'companyIds': FieldValue.arrayRemove([companyId]),
          });
        }

        // تحديث الكاش
        await _removeCompanyFromCache(companyId);

        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(tr('company_deleted'))));
          await _refreshData(); // تحديث القائمة
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${tr('delete_error')}: $e')),
          );
        }
      }
    }
  }

  Future<void> _removeCompanyFromCache(String companyId) async {
    setState(() {
      _companies.removeWhere((company) => company['id'] == companyId);
      userCompanyIds.remove(companyId);
    });
    await _saveCompaniesToCache(_companies, userCompanyIds);
  }

  Future<void> _editCompany(String companyId) async {
    final result = await context.push('/edit-company/$companyId');
    if (result == true) {
      // ✅ إعادة تحميل البيانات من الكاش مباشرة
      await _loadCompaniesFromCache();
      await _refreshData(); // تجلب من Firestore وتحدث الكاش

      // ✅ تحديث وقت آخر تحميل لجعل الكاش حديثاً
      setState(() {
        _lastCacheUpdate = DateTime.now();
      });
      if (mounted) setState(() {});
    }
  }

  // ======================== البحث والتصفية ========================

  List<Map<String, dynamic>> get _filteredCompanies {
    if (searchQuery.isEmpty) return _companies;
    return _companies.where((company) {
      final nameAr = (company['nameAr'] ?? '').toString().toLowerCase();
      final nameEn = (company['nameEn'] ?? '').toString().toLowerCase();
      return nameAr.contains(searchQuery) || nameEn.contains(searchQuery);
    }).toList();
  }

  // ======================== UI ========================

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return AppScaffold(
      title: tr('company_list'),
      userName: userName,
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: tr('search'),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (value) =>
                      setState(() => searchQuery = value.toLowerCase()),
                ),
              ),
              Expanded(child: _buildCompaniesList()),
            ],
          ),
          if (_isDataLoading) _buildDataLoadingOverlay(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final Map<String, dynamic>? result =
              await context.push('/add-company');

          if (result != null && result['success'] == true) {
            // ✅ إعادة تحميل البيانات من الكاش بعد الإضافة
            await _loadCompaniesFromCache();
            if (mounted) setState(() {});
          }
        },
        tooltip: tr('add_company'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCompaniesList() {
    if (_companies.isEmpty && userCompanyIds.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tr('no_companies_found')),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _refreshData, child: Text(tr('retry'))),
          ],
        ),
      );
    }

    if (userCompanyIds.isEmpty) {
      return Center(child: Text(tr('no_companies_linked')));
    }

    final filtered = _filteredCompanies;
    if (filtered.isEmpty) {
      return Center(child: Text(tr('no_match_search')));
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (context, index) => _buildCompanyCard(filtered[index]),
      ),
    );
  }

/*   Widget _buildCompanyCard(Map<String, dynamic> company) {
    Uint8List? imageBytes;
    try {
      if (company['logoBase64'] != null && company['logoBase64'].toString().isNotEmpty) {
        imageBytes = base64Decode(company['logoBase64']);
      }
    } catch (e) {
      safeDebugPrint('❌ Error decoding logo: $e');
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 2,
      child: ListTile(
        leading: SizedBox(
          width: 60,
          height: 60,
          child: imageBytes != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(imageBytes, fit: BoxFit.contain),
                )
              : const Icon(Icons.business, size: 40),
        ),
        title: Text(
          '${company['nameAr'] ?? ''} - ${company['nameEn'] ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (company['address'] != null && company['address'].toString().isNotEmpty)
              Text('📍 ${company['address']}'),
            if (company['managerName'] != null && company['managerName'].toString().isNotEmpty)
              Text('👤 ${company['managerName']}'),
            if (company['managerPhone'] != null && company['managerPhone'].toString().isNotEmpty)
              Text('📞 ${company['managerPhone']}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              tooltip: tr('edit'),
              onPressed: () => _editCompany(company['id']),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: tr('delete'),
              onPressed: () => _confirmDeleteCompany(company['id'], company),
            ),
          ],
        ),
      ),
    );
  }
 */

  // companies_page.dart - تعديل دالة _buildCompanyCard

  Widget _buildCompanyCard(Map<String, dynamic> company) {
    Uint8List? imageBytes;
    try {
      if (company['logoBase64'] != null &&
          company['logoBase64'].toString().isNotEmpty) {
        imageBytes = base64Decode(company['logoBase64']);
      }
    } catch (e) {
      safeDebugPrint('❌ Error decoding logo: $e');
    }

    // ✅ الحصول على اسم الشركة باللغة المناسبة
    final isArabic = context.locale.languageCode == 'ar';
    final companyName = isArabic
        ? (company['nameAr'] ?? company['nameEn'] ?? 'Unnamed')
        : (company['nameEn'] ?? company['nameAr'] ?? 'Unnamed');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 2,
      child: ListTile(
        leading: SizedBox(
          width: 60,
          height: 60,
          child: imageBytes != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(imageBytes, fit: BoxFit.contain),
                )
              : const Icon(Icons.business, size: 40),
        ),
        title: Text(
          companyName, // ✅ عرض اسم الشركة بدلاً من address
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (company['address'] != null &&
                company['address'].toString().isNotEmpty)
              Text('📍 ${company['address']}'),
            if (company['managerName'] != null &&
                company['managerName'].toString().isNotEmpty)
              Text('👤 ${company['managerName']}'),
            if (company['managerPhone'] != null &&
                company['managerPhone'].toString().isNotEmpty)
              Text('📞 ${company['managerPhone']}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              tooltip: tr('edit'),
              onPressed: () => _editCompany(company['id']),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: tr('delete'),
              onPressed: () => _confirmDeleteCompany(company['id'], company),
            ),
          ],
        ),
      ),
    );
  }

// companies_page.dart - أضف هذه الدالة

/*   Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // جلب بيانات المستخدم من Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        final companyIds = List<String>.from(data['companyIds'] ?? []);

        setState(() {
          userCompanyIds = companyIds;
        });

        safeDebugPrint('✅ Loaded ${companyIds.length} company IDs for user');
      }
    } catch (e) {
      safeDebugPrint('Error loading user data: $e');
    }
  }
 */
  
  Future<void> _loadUserData() async {
  try {
    // ✅ اقرأ من الكاش أولاً
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString(_keyUserData);

    if (userDataString != null) {
      final userData = json.decode(userDataString) as Map<String, dynamic>;
      if (userData['companyIds'] is List) {
        setState(() {
          userCompanyIds = List<String>.from(userData['companyIds']);
        });
        safeDebugPrint('✅ Company IDs from cache: $userCompanyIds');
        return; // ✅ لا تكمل لـ Firestore
      }
    }

    // ── Firestore فقط لو الكاش فارغ ──
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      final data = userDoc.data()!;
      final companyIds = List<String>.from(data['companyIds'] ?? []);
      setState(() => userCompanyIds = companyIds);

      // ✅ حفظ في الكاش للمرة الجاية
      final existing = json.decode(userDataString ?? '{}') as Map<String, dynamic>;
      existing['companyIds'] = companyIds;
      await prefs.setString(_keyUserData, json.encode(existing));

      safeDebugPrint('✅ Company IDs from Firestore: $companyIds');
    }
  } catch (e) {
    safeDebugPrint('Error loading user data: $e');
  }
}
  
  Widget _buildDataLoadingOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(12),
        color: Colors.blue.withAlpha(25),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Text(tr('updating_data'),
                style: const TextStyle(
                    fontSize: 14,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
